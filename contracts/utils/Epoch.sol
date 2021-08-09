pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

import '../owner/Operator.sol';

contract Epoch is Operator {
    using SafeMath for uint256;

    uint256 private period;
    uint256 private startTime;
    uint256 private epoch;

    uint256 public nextTime;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        uint256 _period,
        uint256 _startTime,
        uint256 _startEpoch
    ) public {
        period = _period;
        startTime = _startTime;
        epoch = _startEpoch;
    }

    /* ========== Modifier ========== */

    modifier checkStartTime {
        require(now >= startTime, 'Epoch: not started yet');

        _;
    }

    modifier checkEpoch {
        require(now >= nextEpochPoint(), 'Epoch: not allowed');

        _;

        epoch = epoch.add(1);
        nextTime = block.timestamp.add(period).div(period).mul(period);
        if (block.timestamp.add(period.div(2)) > nextTime) {
            nextTime = nextTime.add(period);
        }
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getCurrentEpoch() public view returns (uint256) {
        return epoch;
    }

    function getPeriod() public view returns (uint256) {
        return period;
    }

    function getStartTime() public view returns (uint256) {
        return startTime;
    }

    function nextEpochPoint() public view returns (uint256) {
        uint256 calcTime = startTime.add(epoch.mul(period));
        return nextTime > calcTime ? nextTime : calcTime;
    }

    /* ========== GOVERNANCE ========== */

    function setPeriod(uint256 _period) external onlyOperator {
        period = _period;
    }

    /* ========== DEPLOYEMENT ========= */
    function setStarttime(uint256 _starttime) public onlyOwner {
        require(startTime > now, "already start");
        require(_starttime > now, "invalid param");
        startTime = _starttime;
    }
}
