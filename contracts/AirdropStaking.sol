// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/SafeMath.sol";
import "./lib/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./lib/ReentrancyGuard.sol";
import "./lib/IERC1155.sol";
import "./MarsVault.sol";
//import "./lib/console.sol";

interface Vault{
    function safeRewardsTransfer(address _to, uint256 _amount) external;
}

contract AirdropStaking is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    struct UserInfo {
        uint256 unlockTimestamp;
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        uint256 lockUpTime;
        uint256 minDeposit;
        uint256 allocPoint;
        uint256 rewardsBalance;
        uint256 totalDeposited;
        uint256 lastRewardBlock;
        uint256 accRewardsPerShare;
    }

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    PoolInfo[11] public poolInfo;

    IERC1155 immutable public nft1155;
    IERC20 immutable public marsToken;
    uint256 constant totalAllocPoint=7_200_000;
    uint256 constant marsPerBlock40=277777777777777778;
    uint256 constant marsPerBlock60=416666666666666667;
    Vault public rewardsVault;
    uint256 public annualBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(address _nft1155,
                address _marsToken,
                uint256 _startBlock) public {
        nft1155=IERC1155(_nft1155);
        marsToken=IERC20(_marsToken);
        
        uint256 lastRewardBlock=block.number > _startBlock ? block.number : _startBlock;
        annualBlock=lastRewardBlock.add(10368000);//360×28800 ~1 year

        poolInfo[0]=PoolInfo(15 days, 500*1e18,600_000,600_000*1e18,0,lastRewardBlock,0);
        poolInfo[1]=PoolInfo(30 days, 1000*1e18,600_000,600_000*1e18,0,lastRewardBlock,0);
        poolInfo[2]=PoolInfo(45 days, 2000*1e18,600_000,600_000*1e18,0,lastRewardBlock,0);
        poolInfo[3]=PoolInfo(60 days, 4000*1e18,600_000,600_000*1e18,0,lastRewardBlock,0);
        poolInfo[4]=PoolInfo(75 days, 10000*1e18,990_000,990_000*1e18,0,lastRewardBlock,0);
        poolInfo[5]=PoolInfo(90 days,12500*1e18,1380_000,1380_000*1e18,0,lastRewardBlock,0);
        poolInfo[6]=PoolInfo(105 days,15000*1e18,990_000,990_000*1e18,0,lastRewardBlock,0);
        poolInfo[7]=PoolInfo(120 days,20000*1e18,132_000,132_000*1e18,0,lastRewardBlock,0);
        poolInfo[8]=PoolInfo(135 days,25000*1e18,108_000,108_000*1e18,0,lastRewardBlock,0);
        poolInfo[9]=PoolInfo(150 days,50000*1e18,300_000,300_000*1e18,0,lastRewardBlock,0);
        poolInfo[10]=PoolInfo(180 days,75000*1e18,900_000,900_000*1e18,0,lastRewardBlock,0);

        bytes memory bytecode = type(MarsVault).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(_marsToken));
        bytes32 salt = keccak256(abi.encodePacked(_nft1155, block.number));

        address rewardsVaultAddress;
        assembly {
            rewardsVaultAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(rewardsVaultAddress != address(0), "Create2: Failed on deploy");
        rewardsVault=Vault(rewardsVaultAddress);
        
    }

    function getMarsReward(uint256 _from, uint256 _to) internal view returns (uint256) {

        if(_to>annualBlock){
            if(_from<annualBlock){
                return annualBlock.sub(_from)
                        .mul(marsPerBlock40)
                        .add(
                            _to.sub(annualBlock)
                            .mul(marsPerBlock60)
                        );
            }
            return _to.sub(_from).mul(marsPerBlock60);
        }

        return _to.sub(_from).mul(marsPerBlock40);
    }

    function pendingRewards(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accRewardsPerShare = pool.accRewardsPerShare;
        
        if (block.number > pool.lastRewardBlock && pool.totalDeposited != 0) {
            uint256 marsReward = getMarsReward(pool.lastRewardBlock, block.number)
                                .mul(pool.allocPoint)
                                .div(totalAllocPoint);
            
            if(pool.rewardsBalance<marsReward){
                marsReward=pool.rewardsBalance;
            }
            accRewardsPerShare = accRewardsPerShare.add(
                                                        marsReward
                                                        .mul(1e18)
                                                        .div(pool.totalDeposited)
                                                    );
        }
        return user.amount.mul(accRewardsPerShare).div(1e18).sub(user.rewardDebt);
    }


    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.totalDeposited == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 marsReward = getMarsReward(pool.lastRewardBlock, block.number)
                            .mul(pool.allocPoint).mul(1e18)
                            .div(totalAllocPoint).div(1e18);

        if(pool.rewardsBalance<marsReward){
            marsReward=pool.rewardsBalance;
        }
        pool.rewardsBalance=pool.rewardsBalance.sub(marsReward);
        pool.accRewardsPerShare = pool.accRewardsPerShare
                                .add(marsReward
                                    .mul(1e18)
                                    .div(pool.totalDeposited)
                                );
        pool.lastRewardBlock = block.number;
    }


    function deposit(uint256 _pid, uint256 _amount) public {
        
        require(nft1155.balanceOf(msg.sender, _pid)>0,
        "you don't have NFT for this pool");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardsPerShare).div(1e18).sub(user.rewardDebt);
            if(pending > 0) {
                rewardsVault.safeRewardsTransfer(msg.sender, pending);
            }
            user.rewardDebt = user.amount.mul(pool.accRewardsPerShare).div(1e18);

        }else{
            require(_amount>=pool.minDeposit,"amount is too low");
            user.unlockTimestamp=block.timestamp.add(pool.lockUpTime);
        }

        if(_amount > 0) {
            marsToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            pool.totalDeposited=pool.totalDeposited.add(_amount);
            emit Deposit(msg.sender, _pid, _amount);
        }
   
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        require(user.unlockTimestamp<block.timestamp,"deposit still locked");
        uint256 depoBalance=user.amount.sub(_amount);
        require(depoBalance==0 || depoBalance>=pool.minDeposit,
        "deposit must be greater than the minimum or equal to 0");
        
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accRewardsPerShare).div(1e18).sub(user.rewardDebt);
        if(pending > 0) {
            rewardsVault.safeRewardsTransfer(msg.sender, pending);
            user.rewardDebt = user.amount.mul(pool.accRewardsPerShare).div(1e18);
        }

        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            marsToken.safeTransfer(address(msg.sender), _amount);
            emit Withdraw(msg.sender, _pid, _amount);
        }
    
    }

}
