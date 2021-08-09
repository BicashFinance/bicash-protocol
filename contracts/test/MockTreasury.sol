pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";


import '../interfaces/IBoardroom.sol';
import '../interfaces/IMinter.sol';




contract MockTreasury {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    address public cash;
    address public cashCore;
    address public fund;
    address public shareBoardroom;

    constructor(address _cash, address _fund, address _board) public {
        cash = _cash;
        cashCore = _cash;
        fund = _fund;
        shareBoardroom = _board;
    }
    

    function allocateSeigniorage(uint256 _all)
        external
    {
        
        uint256 seigniorage = _all;
        uint256 fundAllocationRate = 2;
        
        IMinter(cashCore).mint(address(this), seigniorage);

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

    event BoardroomFunded(uint256 timestamp, uint256 seigniorage);


}