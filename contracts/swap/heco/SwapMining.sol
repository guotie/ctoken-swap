// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "../interface/IERC20.sol";
import "../library/SafeMath.sol";

import "../interface/IDeBankFactory.sol";
import "../interface/IDeBankPair.sol";

import "../interface/IEbe.sol";

interface IOracle {
    function update(address tokenA, address tokenB) external;

    function consult(address tokenIn, uint amountIn, address tokenOut) external view returns (uint amountOut);
}

contract SwapMining is Ownable {
    using SafeMath for uint256;
    // using EnumerableSet for EnumerableSet.AddressSet;
    // EnumerableSet.AddressSet private _whitelist;

    // EBE tokens created per block
    uint256 public ebePerBlock;
    // The block number when EBE mining starts.
    uint256 public startBlock;
    // How many blocks are halved
    uint256 public halvingPeriod = 5256000;
    // Total allocation points
    uint256 public totalAllocPoint = 0;
    // uint256 allocEbeAmount; // How many EBEs = ebe.balanceOf(address(this))
    // uint256 lastRewardBlock;// Last transaction block
    // IOracle public oracle;
    // router address
    address public router;
    // factory address
    // IDeBankFactory public factory;
    // ebe token address
    IEbe public ebe;
    // Calculate price based on HUSD
    // address public targetToken;
    // pair corresponding pid
    // mapping(address => uint256) public pairOfPid;

    constructor(
        IEbe _ebe,
        // IDeBankFactory _factory,
        // IOracle _oracle,
        address _router,
        // address _targetToken,
        uint256 _ebePerBlock,
        uint256 _startBlock
    ) public {
        ebe = _ebe;
        // factory = _factory;
        // oracle = _oracle;
        router = _router;
        // targetToken = _targetToken;
        ebePerBlock = _ebePerBlock;
        startBlock = _startBlock;
    }

    struct UserInfo {
        uint256 quantity;       // How many LP tokens the user has provided
        uint256 blockNumber;    // Last transaction block
    }

    struct PoolInfo {
        // address pair;           // Trading pairs that can be mined
        uint256 quantity;       // Current amount of LPs
        uint256 totalQuantity;  // All quantity
        // uint256 allocPoint;     // How many allocation points assigned to this pool
        uint256 allocEbeAmount; // How many EBEs
        uint256 lastRewardBlock;// Last transaction block
    }

    PoolInfo public pool;
    // mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => UserInfo) public userInfo;


    // function poolLength() public view returns (uint256) {
    //     return poolInfo.length;
    // }


    // function addPair(uint256 _allocPoint, address _pair, bool _withUpdate) public onlyOwner {
    //     require(_pair != address(0), "_pair is the zero address");
    //     if (_withUpdate) {
    //         massMintPools();
    //     }
    //     uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
    //     totalAllocPoint = totalAllocPoint.add(_allocPoint);
    //     poolInfo.push(PoolInfo({
    //     pair : _pair,
    //     quantity : 0,
    //     totalQuantity : 0,
    //     allocPoint : _allocPoint,
    //     allocEbeAmount : 0,
    //     lastRewardBlock : lastRewardBlock
    //     }));
    //     pairOfPid[_pair] = poolLength() - 1;
    // }

    // Update the allocPoint of the pool
    // function setPair(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
    //     if (_withUpdate) {
    //         massMintPools();
    //     }
    //     totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
    //     poolInfo[_pid].allocPoint = _allocPoint;
    // }

    // Set the number of ebe produced by each block
    function setEbePerBlock(uint256 _newPerBlock) public onlyOwner {
        // massMintPools();
        mint();
        ebePerBlock = _newPerBlock;
    }

    // Only tokens in the whitelist can be mined EBE
    // function addWhitelist(address _addToken) public onlyOwner returns (bool) {
    //     require(_addToken != address(0), "SwapMining: token is the zero address");
    //     return EnumerableSet.add(_whitelist, _addToken);
    // }

    // function delWhitelist(address _delToken) public onlyOwner returns (bool) {
    //     require(_delToken != address(0), "SwapMining: token is the zero address");
    //     return EnumerableSet.remove(_whitelist, _delToken);
    // }

    // function getWhitelistLength() public view returns (uint256) {
    //     return EnumerableSet.length(_whitelist);
    // }

    // function isWhitelist(address _token) public view returns (bool) {
    //     return EnumerableSet.contains(_whitelist, _token);
    // }

    // function getWhitelist(uint256 _index) public view returns (address){
    //     require(_index <= getWhitelistLength() - 1, "SwapMining: index out of bounds");
    //     return EnumerableSet.get(_whitelist, _index);
    // }

    function setHalvingPeriod(uint256 _block) public onlyOwner {
        halvingPeriod = _block;
    }

    function setRouter(address newRouter) public onlyOwner {
        require(newRouter != address(0), "SwapMining: new router is the zero address");
        router = newRouter;
    }

    // function setOracle(IOracle _oracle) public onlyOwner {
    //     require(address(_oracle) != address(0), "SwapMining: new oracle is the zero address");
    //     oracle = _oracle;
    // }

    // At what phase
    function phase(uint256 blockNumber) public view returns (uint256) {
        if (halvingPeriod == 0) {
            return 0;
        }
        if (blockNumber > startBlock) {
            return (blockNumber.sub(startBlock).sub(1)).div(halvingPeriod);
        }
        return 0;
    }

    function phase() public view returns (uint256) {
        return phase(block.number);
    }

    function reward(uint256 blockNumber) public view returns (uint256) {
        uint256 _phase = phase(blockNumber);
        return ebePerBlock.div(2 ** _phase);
    }

    function reward() public view returns (uint256) {
        return reward(block.number);
    }

    // Rewards for the current block
    function getEbeReward(uint256 _lastRewardBlock) public view returns (uint256) {
        require(_lastRewardBlock <= block.number, "SwapMining: must little than the current block number");
        uint256 blockReward = 0;
        uint256 n = phase(_lastRewardBlock);
        uint256 m = phase(block.number);
        // If it crosses the cycle
        while (n < m) {
            n++;
            // Get the last block of the previous cycle
            uint256 r = n.mul(halvingPeriod).add(startBlock);
            // Get rewards from previous periods
            blockReward = blockReward.add((r.sub(_lastRewardBlock)).mul(reward(r)));
            _lastRewardBlock = r;
        }
        blockReward = blockReward.add((block.number.sub(_lastRewardBlock)).mul(reward(block.number)));
        return blockReward;
    }

    // Update all pools Called when updating allocPoint and setting new blocks
    // function massMintPools() public {
    //     uint256 length = poolInfo.length;
    //     for (uint256 pid = 0; pid < length; ++pid) {
    //         mint(pid);
    //     }
    // }
    function mint() public returns (bool) {
        // PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return false;
        }
        uint256 blockReward = getEbeReward(pool.lastRewardBlock);
        if (blockReward <= 0) {
            return false;
        }
        // Calculate the rewards obtained by the pool based on the allocPoint
        // uint256 ebeReward = blockReward.mul(pool.allocPoint).div(totalAllocPoint);
        ebe.mint(address(this), blockReward);
        // Increase the number of tokens in the current pool
        // allocEbeAmount = allocEbeAmount.add(blockReward);
        pool.lastRewardBlock = block.number;
        return true;
    }

    // function mint(uint256 _pid) public returns (bool) {
    //     PoolInfo storage pool = poolInfo[_pid];
    //     if (block.number <= pool.lastRewardBlock) {
    //         return false;
    //     }
    //     uint256 blockReward = getEbeReward(pool.lastRewardBlock);
    //     if (blockReward <= 0) {
    //         return false;
    //     }
    //     // Calculate the rewards obtained by the pool based on the allocPoint
    //     uint256 ebeReward = blockReward.mul(pool.allocPoint).div(totalAllocPoint);
    //     ebe.mint(address(this), ebeReward);
    //     // Increase the number of tokens in the current pool
    //     pool.allocEbeAmount = pool.allocEbeAmount.add(ebeReward);
    //     pool.lastRewardBlock = block.number;
    //     return true;
    // }

    // swapMining only router
    function swap(address account, address input, address output, uint256 fee) public onlyRouter returns (bool) {
        require(account != address(0), "SwapMining: taker swap account is the zero address");
        input;
        output;
        // require(input != address(0), "SwapMining: taker swap input is the zero address");
        // require(output != address(0), "SwapMining: taker swap output is the zero address");

        // if (poolLength() <= 0) {
        //     return false;
        // }

        // if (!isWhitelist(input) || !isWhitelist(output)) {
        //     return false;
        // }

        // address pair = IDeBankFactory(factory).pairFor(input, output);

        // PoolInfo storage pool = poolInfo[pairOfPid[pair]];
        // // If it does not exist or the allocPoint is 0 then return
        // if (pool.pair != pair || pool.allocPoint <= 0) {
        //     return false;
        // }

        uint256 quantity = fee; //getQuantity(output, fee, targetToken);
        if (quantity <= 0) {
            return false;
        }

        mint();

        pool.quantity = pool.quantity.add(quantity);
        pool.totalQuantity = pool.totalQuantity.add(quantity);
        UserInfo storage user = userInfo[account];
        user.quantity = user.quantity.add(quantity);
        user.blockNumber = block.number;
        return true;
    }

    // The user withdraws all the transaction rewards of the pool
    function takerWithdraw() public {
        uint256 userSub;
        // uint256 length = poolInfo.length;
        // for (uint256 pid = 0; pid < length; ++pid) {
            // PoolInfo storage pool = poolInfo[pid];
            UserInfo storage user = userInfo[msg.sender];
            if (user.quantity > 0) {
                mint();
                // The reward held by the user in this pool
                uint256 userReward = pool.allocEbeAmount.mul(user.quantity).div(pool.quantity);
                pool.quantity = pool.quantity.sub(user.quantity);
                pool.allocEbeAmount = pool.allocEbeAmount.sub(userReward);
                user.quantity = 0;
                user.blockNumber = block.number;
                userSub = userSub.add(userReward);
            }
        // }
        if (userSub <= 0) {
            return;
        }
        ebe.transfer(msg.sender, userSub);
    }

    // Get rewards from users in the current pool
    function getUserReward() public view returns (uint256, uint256){
        // require(_pid <= poolInfo.length - 1, "SwapMining: Not find this pool");
        uint256 userSub;
        // PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[msg.sender];
        if (user.quantity > 0) {
            uint256 blockReward = getEbeReward(pool.lastRewardBlock);
            uint256 ebeReward = blockReward; // .mul(pool.allocPoint).div(totalAllocPoint);
            userSub = userSub.add((pool.allocEbeAmount.add(ebeReward)).mul(user.quantity).div(pool.quantity));
        }
        //Ebe available to users, User transaction amount
        return (userSub, user.quantity);
    }

    // Get details of the pool
    // function getPoolInfo(uint256 _pid) public view returns (address, address, uint256, uint256, uint256, uint256){
    //     require(_pid <= poolInfo.length - 1, "SwapMining: Not find this pool");
    //     PoolInfo memory pool = poolInfo[_pid];
    //     address token0 = IDeBankPair(pool.pair).token0();
    //     address token1 = IDeBankPair(pool.pair).token1();
    //     uint256 ebeAmount = pool.allocEbeAmount;
    //     uint256 blockReward = getEbeReward(pool.lastRewardBlock);
    //     uint256 ebeReward = blockReward.mul(pool.allocPoint).div(totalAllocPoint);
    //     ebeAmount = ebeAmount.add(ebeReward);
    //     //token0,token1,Pool remaining reward,Total /Current transaction volume of the pool
    //     return (token0, token1, ebeAmount, pool.totalQuantity, pool.quantity, pool.allocPoint);
    // }

    modifier onlyRouter() {
        require(msg.sender == router, "SwapMining: caller is not the router");
        _;
    }

    // function getQuantity(address outputToken, uint256 outputAmount, address anchorToken) public view returns (uint256) {
    //     uint256 quantity = 0;
    //     if (outputToken == anchorToken) {
    //         quantity = outputAmount;
    //     } else if (IDeBankFactory(factory).getPair(outputToken, anchorToken) != address(0)) {
    //         quantity = IOracle(oracle).consult(outputToken, outputAmount, anchorToken);
    //     } else {
    //         uint256 length = getWhitelistLength();
    //         for (uint256 index = 0; index < length; index++) {
    //             address intermediate = getWhitelist(index);
    //             if (IDeBankFactory(factory).getPair(outputToken, intermediate) != address(0) &&
    //                  IDeBankFactory(factory).getPair(intermediate, anchorToken) != address(0)) {
    //                 uint256 interQuantity = IOracle(oracle).consult(outputToken, outputAmount, intermediate);
    //                 quantity = IOracle(oracle).consult(intermediate, interQuantity, anchorToken);
    //                 break;
    //             }
    //         }
    //     }
    //     return quantity;
    // }

}
