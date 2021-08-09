pragma solidity ^0.6.0;

import './token/ScaleERC20.sol';
import './owner/Operator.sol';

contract Cash is ScaleERC20, Operator {

    address public scaleOperator;

    mapping(address => uint256) public minterBalances;
    uint256 public totalMinterBalance;

    event SetMinter(address indexed minter, uint256 balance);

    /**
     * @notice Constructs the Basis Cash ERC-20 contract.
     */
    constructor(string memory symbol_) public ScaleERC20(symbol_, symbol_) {
        // Mints 1 Basis Cash to contract creator for initial Uniswap oracle deployment.
        // Will be burned after oracle deployment
        _mint(msg.sender, 1 * 10**18);
    }

    function setMinter(address _minter, uint256 _bal) public onlyOwner {
        totalMinterBalance = totalMinterBalance.sub(minterBalances[_minter]).add(_bal);
        minterBalances[_minter] = _bal;
        emit SetMinter(_minter, _bal);
    }

    function emergencyClearMinter(address _minter) public onlyOperator {
        totalMinterBalance = totalMinterBalance.sub(minterBalances[_minter]);
        emit SetMinter(_minter, 0);
    }

    function mint(address to, uint256 amount) public {
        require(minterBalances[msg.sender] >= amount, "no balance");
        minterBalances[msg.sender] = minterBalances[msg.sender].sub(amount);
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function setScaleOperator(address op) public onlyOwner {
        scaleOperator = op;
    }

    function setScale(uint256 _scale) public {
        require(msg.sender == scaleOperator, "on scale operator");
        scale = _scale;
    }

}
