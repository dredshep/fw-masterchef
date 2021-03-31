// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./FSXU.sol";
import "./WHIRL.sol";

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// MasterChef is the master of Egg. He can make Egg and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once EGG is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract FWMasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of EGGs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accTokenPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accTokenPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        IERC20 rewardToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. EGGs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that EGGs distribution occurs.
        uint256 accTokenPerShare;   // Accumulated EGGs per share, times 1e12. See below.
    }

    // The EGG TOKEN!
    FSXU public fsxu;
    // The EGG TOKEN!
    WF public whirl;
    // FSXU tokens created per block.
    uint256 public fsxuPerBlock;
    // WF tokens created per block.
    uint256 public whirlPerBlock;
    // Bonus muliplier for early egg makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Deposit Fee address
    address public feeAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when EGG mining starts.
    uint256 public startBlock;

    //The Fsxu and Whirl account address
    address  public fsxuAndWhirlAddr;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event UpdateFsxuPerBlock(uint256 fsxuPerBlock);
    event UpdateWhirlPerBlock(uint256 whirlPerBlock);

    constructor(
        FSXU _fsxu,
        WF _whirl,
        uint256 _fsxuPerBlock,
        uint256 _whirlPerBlock,
        uint256 _startBlock,
        address _fsxuAndWhirlAddr
    ) public {
        require(address(_fsxu) != address(0), "Constructor: fsxu cannot be zero address");
        require(address(_whirl) != address(0), "Constructor: whirl cannot be zero address");
        require(_fsxuPerBlock != 0, "Constructor: fsxu reward per block cannot be zero");
        require(_whirlPerBlock != 0, "Constructor: whirl reward per block cannot be zero");
        require(_fsxuAndWhirlAddr != address(0), "Constructor: fsxu adn whirl address cannot be zero");
        fsxu = _fsxu;
        whirl = _whirl;
        fsxuPerBlock = _fsxuPerBlock;
        whirlPerBlock = _whirlPerBlock;
        startBlock = _startBlock;
        fsxuAndWhirlAddr = _fsxuAndWhirlAddr;
    }
    
    /// @notice Update the FSXU token reward per block
    function updateFsxuPerBlock(uint256 _fsxuPerBlock) public onlyOwner{
        require(_fsxuPerBlock != 0, "updateFsxuPerBlock: fsxu reward per block cannot be zero");
        fsxuPerBlock = _fsxuPerBlock;
        //emit when fsxuPerBlock changed
        emit UpdateFsxuPerBlock(fsxuPerBlock);
    }

    /// @notice Update the WHIRL token reward per block
    function updateWhirlPerBlock(uint256 _whirlPerBlock) public onlyOwner{
        require(_whirlPerBlock != 0, "updateWhirlPerBlock: whirl reward per block cannot be zero");
        whirlPerBlock = _whirlPerBlock;
        //emit when whirlPerBlock changed
        emit UpdateWhirlPerBlock(whirlPerBlock);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, IERC20 _rewardToken, bool _withUpdate) public onlyOwner {
        // require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            rewardToken: _rewardToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accTokenPerShare: 0
        }));
    }

    // Update the given pool's token allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        // require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending EGGs on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward;
            if(address(pool.rewardToken) == address(fsxu))
            {
                tokenReward = multiplier.mul(fsxuPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
                accTokenPerShare = accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
            }
            else
            {
                tokenReward = multiplier.mul(whirlPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
                accTokenPerShare = accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
            }
        }
        return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward;
        if(address(pool.rewardToken) == address(fsxu))
        {
            tokenReward = multiplier.mul(fsxuPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            pool.accTokenPerShare = pool.accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        else
        {
            tokenReward = multiplier.mul(whirlPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            pool.accTokenPerShare = pool.accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for EGG allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                if(address(pool.rewardToken) == address(fsxu))
                    safeFsxuTransfer(msg.sender, pending);
                else
                    safeWhirlTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            if(address(pool.rewardToken) == address(fsxu))
                safeFsxuTransfer(msg.sender, pending);
            else
                safeWhirlTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }


    /**@dev
        set Governance token user wallet address
     */
    function setFsxuAndWhirlAddr(address _newAddr) public onlyOwner{
        require(address(_newAddr) != address(0), "setFsxuAndWhirlAddr: address cannot be zero address");
        fsxuAndWhirlAddr = _newAddr;
    }

    // Safe FSXU transfer function, just in case if rounding error causes pool to not have enough EGGs.
    function safeFsxuTransfer(address _to, uint256 _amount) internal {
        uint256 fsxuBal = fsxu.balanceOf(fsxuAndWhirlAddr);
        if (_amount > fsxuBal) {
            fsxu.transferFrom(fsxuAndWhirlAddr, _to, fsxuBal);
        } else {
            fsxu.transferFrom(fsxuAndWhirlAddr, _to, _amount);
        }
    }

    // Safe WF transfer function, just in case if rounding error causes pool to not have enough EGGs.
    function safeWhirlTransfer(address _to, uint256 _amount) internal {
        uint256 whirlBal = whirl.balanceOf(fsxuAndWhirlAddr);
        if (_amount > whirlBal) {
            whirl.transferFrom(fsxuAndWhirlAddr, _to, whirlBal);
        } else {
            whirl.transferFrom(fsxuAndWhirlAddr, _to, _amount);
        }
    }

    //Pancake has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    // function updateEmissionRate(uint256 _eggPerBlock) public onlyOwner {
    //     massUpdatePools();
    //     eggPerBlock = _eggPerBlock;
    // }
}
