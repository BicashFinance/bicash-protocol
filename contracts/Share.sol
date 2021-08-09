pragma solidity ^0.6.0;

import './owner/Operator.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

contract Share is ERC20Burnable, Operator {

    mapping(address => uint256) public minterBalances;
    uint256 public totalMinterBalance;

    event SetMinter(address indexed minter, uint256 balance);

    constructor(string memory symbol_) public ERC20(symbol_, symbol_) {
        // Mints 1 ONSis Share to contract creator for initial Uniswap oracle deployment.
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
   
}
