pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import './interfaces/IOracle.sol';
import './interfaces/IBoardroom.sol';
import './interfaces/IBasisAsset.sol';
import './interfaces/ISimpleERCFund.sol';
import './interfaces/IMinter.sol';
import './interfaces/IUniswapV2Pair.sol';
import './lib/Babylonian.sol';
import './lib/FixedPoint.sol';
import './lib/Safe112.sol';
import './owner/Operator.sol';
import './utils/Epoch.sol';
import './utils/ContractGuard.sol';

/**
 * @title Basis Cash Treasury contract
 * @notice Monetary policy logic to adjust supplies of basis cash assets
 * @author Summer Smith & Rick Sanchez
 */
contract CashTreasury is ContractGuard, Epoch {
    using FixedPoint for *;
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using Safe112 for uint112;

    /* ========== STATE VARIABLES ========== */

    // ========== CORE
    address public fund;
    address public cash;
    address public share;
    address public dai;
    address public shareDaiLp;
    address public shareBoardroom;
    
    //address public bondOracle;
    //address public seigniorageOracle;
    address public oracle;

    // ========== PARAMS
    uint256 public cashPriceOne;
    uint256 public cashPriceCeiling;
    uint256 public cashPriceFloor;
    
    uint256 public fundAllocationRate = 2;  // %
    uint256 public maxInflationRate = 10;   // %
    uint256 public maxDeflationRate = 1;    // %
    
    
    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _cash,
        address _oracle,
        address _share,
        address _dai,
        address _shareDaiLp,
        address _shareBoardroom,
        address _fund,
        uint256 _startTime
    ) public Epoch(8 hours, _startTime, 0) {
        cash = _cash;
        oracle = _oracle;

        share = _share;
        dai = _dai;
        shareDaiLp = _shareDaiLp;
        shareBoardroom = _shareBoardroom;
        
        fund = _fund;

        cashPriceOne = 10**18;
        cashPriceCeiling = uint256(105).mul(cashPriceOne).div(10**2);
        cashPriceFloor = uint256(90).mul(cashPriceOne).div(10**2);
    }

    /* ========== VIEW FUNCTIONS ========== */

    // oracle
    function getOraclePrice() public view returns (uint256) {
        return _getCashPrice(oracle);
    }

    function _getCashPrice(address _oracle) internal view returns (uint256) {
        try IOracle(_oracle).consult(cash, 1e18) returns (uint256 price) {
            return price;
        } catch {
            revert('Treasury: failed to consult cash price from the oracle');
        }
    }

    function shareMktCap() public view returns (uint256) {
        uint256 sharePrice = IERC20(dai).balanceOf(shareDaiLp).mul(10**18)
                                .div(IERC20(share).balanceOf(shareDaiLp));
        uint256 shareAmount = IERC20(share).totalSupply().sub(
                                IERC20(share).balanceOf(address(1))
                            );
        return sharePrice.mul(shareAmount).div(10**18);
    }

    /* ========== GOVERNANCE ========== */
    
    function setFund(address newFund) public onlyOperator {
        fund = newFund;
    }

    function setFundAllocationRate(uint256 rate) public onlyOperator {
        fundAllocationRate = rate;
    }

    function setMaxInflationRate(uint256 rate) public onlyOperator {
        maxInflationRate = rate;
        emit MaxInflationRateChanged(msg.sender, rate);
    }

    function setMaxDeflationRate(uint256 rate) public onlyOperator {
        maxDeflationRate = rate;
    }

    function setCeilingFloor(uint256 _ceiling, uint256 _floor) public onlyOperator {
        require(_ceiling > cashPriceOne, "invalid ceiling");
        require(_floor < cashPriceOne, "invalid floor");
        cashPriceCeiling = _ceiling;
        cashPriceFloor = _floor;
    }

    function setOracle(address _oracle) public onlyOperator {
        oracle = _oracle;
    }

    function setBoardroom(address _boardroom) public onlyOperator {
        shareBoardroom = _boardroom;
    }

    
    /* ========== MUTABLE FUNCTIONS ========== */

    function _updateCashPrice() internal {
        try IOracle(oracle).update()  {} catch {}
    }

    function allocateSeigniorage()
        external
        onlyOneBlock
        checkStartTime
        checkEpoch
    {
        require(msg.sender == tx.origin, "onlyEOA");
        _updateCashPrice();
        uint256 cashPrice = _getCashPrice(oracle);
        // circulating supply
        uint256 cashSupply = IERC20(cash).totalSupply();

        
        if (cashPrice <= cashPriceCeiling) {

            if (cashPrice < cashPriceFloor) {
                // deflation
                uint256 scale = IBasisAsset(cash).scale();
                uint256 newScale = scale.mul(10**18).div(cashPrice);
                uint256 maxScale = scale.add(scale.mul(maxDeflationRate).div(100));
                if (newScale > maxScale) {
                    newScale = maxScale;
                }
                IBasisAsset(cash).setScale(newScale);
            }

            return; // just advance epoch instead revert
        }

        if (cashSupply > shareMktCap()) {
            return;
        }
        
        uint256 percentage = cashPrice.sub(cashPriceOne);
        uint256 seigniorage = cashSupply.mul(percentage).div(1e18);
        uint256 maxSeigniorage = cashSupply.mul(maxInflationRate).div(100);
        if (seigniorage > maxSeigniorage) {
            seigniorage = maxSeigniorage;
        }
        IMinter(cash).mint(address(this), seigniorage);

        // ======================== BIP-3
        uint256 fundReserve = seigniorage.mul(fundAllocationRate).div(100);
        if (fundReserve > 0) {
            IERC20(cash).safeTransfer(fund, fundReserve);
        }

        // boardroom
        uint256 shareBoardroomReserve = seigniorage.sub(fundReserve);
        if (shareBoardroomReserve > 0) {
            IERC20(cash).safeApprove(shareBoardroom, shareBoardroomReserve);
            IBoardroom(shareBoardroom).allocateSeigniorage(shareBoardroomReserve);
            emit BoardroomFunded(now, shareBoardroomReserve);
        }
    }

    // GOV
    event MaxInflationRateChanged(
        address indexed operator,
        uint256 newRate
    );

    // CORE
    event BoardroomFunded(uint256 timestamp, uint256 seigniorage);

}


