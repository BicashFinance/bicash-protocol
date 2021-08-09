// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IMinter.sol";

// MasterChef is the master of Reward. He can make Reward and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once REWARD is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract ShareMasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 lastActionTime;
        //
        // We do some fancy math here. Basically, any point in time, the amount of REWARDs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accRewardPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. REWARDs to distribute per block.
        uint256 lastRewardTimestamp; // Last block number that REWARDs distribution occurs.
        uint256 accRewardPerShare; // Accumulated REWARDs per share, times 1e12. See below.
        uint256 totalAmount;
        uint256 lockPeriod;
    }
    // The REWARD TOKEN!
    address public reward;
    uint256 public rewardRate;
    uint256 public starttime;
    uint256 public endtime;

    // Dev address.
    address public devaddr;
    // Dev balance
    uint256 public devBal;

    uint256 public constant DEV_FUND_RATE = 10;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        address _reward,
        uint256 _starttime
    ) public {
        reward = _reward;
        starttime = _starttime;
        endtime = block.timestamp.add(730 days);
        devaddr = msg.sender;
    }

    function setStartTime(uint256 _time) external onlyOwner {
        require(starttime > block.timestamp, "start yet");
        starttime = _time;
    }

    function setRewardRate(uint256 _rate) external onlyOwner {
        massUpdatePools();
        rewardRate = _rate;
    }

    function setEndtime(uint256 _time) external onlyOwner {
        require(_time > starttime && _time > block.timestamp, "invalid");
        endtime = _time;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint256 _lockPeriod,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTimestamp: block.timestamp,
                accRewardPerShare: 0,
                totalAmount: 0,
                lockPeriod: _lockPeriod
            })
        );
    }

    // Update the given pool's REWARD allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint256 _lockPeriod,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].lockPeriod = _lockPeriod;
        poolInfo[_pid].allocPoint = _allocPoint;
    }


    // Return reward multiplier over the given _from to _to timestamp.
    function getRewardRate(uint256 _from, uint256 _to)
        public
        view
        returns (uint256) 
    {
        if (_to <= starttime || _from >= endtime) {
            return 0;
        }
        uint256 fromTs = _from > starttime ? _from : starttime;
        uint256 toTs = _to > endtime ? endtime : _to;
        return rewardRate.mul(toTs.sub(fromTs)).div(1 days);
    }

    // View function to see pending REWARDs on frontend.
    function pendingReward(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.totalAmount;
        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 rewardReward =
                getRewardRate(pool.lastRewardTimestamp, block.timestamp).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accRewardPerShare = accRewardPerShare.add(
                rewardReward.mul(uint256(100).sub(DEV_FUND_RATE)).div(100).mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = pool.totalAmount;
        if (lpSupply == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 rewardReward =
                getRewardRate(pool.lastRewardTimestamp, block.timestamp).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
        
        if (rewardReward > 0) {
            IMinter(reward).mint(address(this), rewardReward);
        }
        devBal = devBal.add(rewardReward.mul(DEV_FUND_RATE).div(100));
        pool.accRewardPerShare = pool.accRewardPerShare.add(
            rewardReward.mul(uint256(100).sub(DEV_FUND_RATE)).div(100).mul(1e12).div(lpSupply)
        );
        
        pool.lastRewardTimestamp = block.timestamp;
    }

    // Deposit Staking tokens.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        
        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            IERC20(reward).safeTransfer(msg.sender, pending);
        }
        
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        pool.totalAmount = pool.totalAmount.add(_amount);

        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        user.lastActionTime = block.timestamp;
        
        emit Deposit(msg.sender, _pid, _amount);
    }


    function withdrawAll(uint256 _pid) public {
        withdraw(_pid, userInfo[_pid][msg.sender].amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        if (_amount > 0) {
            require(user.lastActionTime.add(pool.lockPeriod) <= block.timestamp, "lock");
        }

        updatePool(_pid);
        
        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            IERC20(reward).safeTransfer(msg.sender, pending);
        }

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        user.lastActionTime = block.timestamp;

        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        pool.totalAmount = pool.totalAmount.sub(_amount);
        emit Withdraw(msg.sender, _pid, user.amount);
    }

    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (user.amount > 0) {
            require(user.lastActionTime.add(pool.lockPeriod) <= block.timestamp, "lock");
        }

        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        pool.totalAmount = pool.totalAmount.sub(user.amount);

        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // dev
    function dev(address _dev) public {
        require(msg.sender == devaddr || msg.sender == owner(), "dev: wut?");
        devaddr = _dev;
    }

    // dev claim reward
    function devClaim(address _to, uint256 _amount) public {
        require(msg.sender == devaddr, "dev: wut?");
        devBal = devBal.sub(_amount);
        IERC20(reward).safeTransfer(_to, _amount);
    }

}
