# 兑换

# Router合约

合约地址：
* ~~HECO测试链: 0x0826d36cecA6240B6A894796C3c3F90030CE6fB8~~
* ~~HECO测试链: 0x84F9a10758631C392847a5cc93Bd622AF44a7454~~
* ~~HECO测试链: 0xb18911609A5b9C7abDc7DBdA585Ae83F01ced0C5~~
* 见 <<地址列表.md>>
* HECO主链:


与 pancake 的提供流动性类似，但是需求区分 token 和 ctoken(存入借贷池后，借贷合约发的代币)

例如两个币对, tokenA 和 tokenB, 存入借贷合约后，分别得到 ctokenA 和 ctokenB. 在 swap 合约中，tokenA/tokenB 的交易对和 ctokenA/ctokenB
是同一个交易对。

因此，关于流动性的方法需要区分token和ctoken。这里的命名规则是，如果是操作token的流动性，函数名以Underlying, 否则就是操作ctoken的方法。

## HT 提供流动性
```
    function addLiquidityETHUnderlying(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity)
```

## token 提供流动性

```-
    function addLiquidityUnderlying(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity)
```

## cToken 提供流动性
```
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity)
```

## 移除流动性，得到ctoken

```
    function removeLiquidity(
        address ctokenA,
        address ctokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountA, uint amountB)
```

## 移除token和token的交易对流动性，得到token
```
    function removeLiquidityUnderlying(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountA, uint amountB) 
```

## 移除token和ht的交易对流动性，得到token和ht

```
    function removeLiquidityETHUnderlying(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountToken, uint amountETH) {
```

## Pair 地址

注意： 参数tokenA tokenB 需要同时为 token，或者同时为 ctoken

```
function pairFor(address tokenA, address tokenB) public view returns (address pair)
```

## 查找、导入流动性

pair是ERC20合约，根据pair地址查询用户在这个balance即可。

# 交易、聚合交易

待完善。

# 限价单合约

合约地址: 
* ~~HECO测试链: 0xE1C3f710074A3697f7F44B62bDb8c4bb9e7b7973~~
* ~~HECO测试链: 0x4639F9a380D37E491a84D751F086a70FBC6D395E~~H
* 见 <<地址列表.md>>
* HECO主链:

主要流程：
1. maker 创建挂单，挂单合约将 maker 卖出的币转到合约中, 因此, 用户需要首先授权: srcToken 合约授权 Orderbook 合约
2. maker 取消订单, 挂单合约将已成交的 destToken 和未成交的 srcToken 全部转给 maker. (todo: 由于挂单会把 token 转换为 eToken, 页面需要判断是否有足够的cash转换)
3. 订单成交: taker 得到srcToken, 这部分直接到 taker 的账号；maker 得到的 destToken 暂存在合约中; (需要授权)
4. 提现: maker 把已成交的destToken提取到自己的账号。

挂单定义:

```
    struct TokenAmount {
        address srcToken;
        address destToken;
        address srcEToken;             // srcToken 对应的 eToken
        address destEToken;            // destToken 对应的 eToken
        uint amountIn;                 // 初始挂单数量
        uint amountInMint;             // 如果 srcToken 不是 eToken, mint 成为 etoken 的数量
        uint fulfiled;                 // 已经成交部分, 单位 etoken
        uint guaranteeAmountOut;       // 最低兑换后要求得到的数量
    }

    struct OrderItem {
      uint orderId;
      uint pairAddrIdx;        // pairIdx | addrIdx
      address owner;           // 订单属主. 如果是杠杆的订单, owner 为杠杆合约地址, to为用户真实地址
      address to;              // 兑换得到的token发送地址
      uint pair;               // hash(srcToken, destToken)
      uint timestamp;          // 挂单时间 
      uint flag;               // 已关闭的订单: 最后一位是1; 进行中的订单: 最后一位是0
      TokenAmount tokenAmt;
    }
```

## 挂单
创建订单, 创建前，需要用户approve; 创建订单成功时，会将用户的币转到合约中

```
    function createOrder(
            address srcToken,       // 用户卖出的币
            address destToken,      // 用户得到的币
            address to,             // 兑换得到的token发送地址 
            uint amountIn,          // 用户卖出币的数量
            uint guaranteeAmountOut,       // 用户预期得到的币的数量
            uint flag                // 暂未使用
        ) public payable whenOpen nonReentrant returns (uint)  // 返回order id, 可使用 order id来查询该订单
```

## 撤单
撤单成功后，用户未成交的币返还给用户

```
    function cancelOrder(uint orderId) public
```

## 查询订单
```
    function orders(uint orderId) returns OrderItem
```
## withdraw

maker 的挂单被吃后, maker 得到的 etoken 保存在合约中, maker 需要手动提取. withdraw 提取 etoken 到用户账号上

参数说明：
* etoken: 待提取的 `etoken` 地址
* amt: 提取数量, 单位是 `etoken`. 参数传 `0` 代表提取所有

```
function withdraw(address etoken, uint amt) external
```

## withdrawUnderlying

maker 的挂单被吃后, maker 得到的 etoken 保存在合约中, maker 需要手动提取. withdrawUnderlying 提取 token 到用户账号上, 页面需要判断是否有足够的 cash 可以提取。

参数说明：
* token: 待提取的 `token` 地址
* amt: 提取数量, 单位是 `etoken` (没写错, 是 `etoken` 的数量). 参数传 `0` 代表提取所有

```
function withdrawUnderlying(address token, uint amt) external
```

## fulfil 成交订单

```
    struct FulFilAmt {
      bool isToken;      // 是否是 token
      uint256 filled;    // 成交的 srcEToken
      uint256 takerAmt;  // taker 得到的 srcEToken = amtDest - fee
      uint256 takerAmtToken; // taker 得到的 srcToken = amtDestToken - fee
      uint256 makerAmt;      // maker 得到的 destEToken
      uint256 amtDest;       // taker 付出 srcEToken
      uint256 amtDestToken;  // taker 付出的 srcToken
    }

    /// @dev fulfilOrder orderbook order, etoken in and etoken out
    // order 成交, 收取成交后的币的手续费, 普通订单, maker 成交的币由合约代持; taker 的币发给用户, amtToTaken 是 src EToken 的数量
    /// @param orderId order id
    /// @param amtToTaken 成交多少量, 以 src etoken 为单位
    /// @param to 合约地址或者 msg.sender
    /// @param isToken 用户输入 token 且得到 token, 调用者须 approve 且确保 srcEToken 的 cash 足够兑付
    /// @param partialFill 是否允许部分成交(正好此时部分被其他人taken)
    /// @param data flashloan 合约执行代码
    /// @return fulFilAmt (taker买到的币数量, maker得到的dest etoken数量, taker付出的币数量)
    function fulfilOrder(
                uint orderId,        // 
                uint amtToTaken,
                address to,
                bool isToken,
                bool partialFill,
                bytes calldata data
              )
              external
              payable
              whenOpen
              nonReentrant
              returns (FulFilAmt memory fulFilAmt)
```

## 成交多个订单

```
    /// @dev fulfilOrders taker take multi orderbook order
    /// @param orderIds order id 数组
    /// @param amtToTakens 成交量数组, 以 src etoken 为单位.
    /// @param to 合约地址或者 msg.sender
    /// @param isToken 用户输入 token 且得到 token, 调用者须 approve 且确保 srcEToken 的 cash 足够兑付
    /// @param partialFill 是否允许部分成交(正好此时部分被其他人taken)
    /// @param data flashloan 合约执行代码
    function fulfilOrders(
                uint[] memory orderIds,
                uint[] memory amtToTakens,
                address to,
                bool isToken,
                bool partialFill,
                bytes calldata data
              )
              external
              payable
```

举例来说，你要吃掉3个order, order id 为 [1, 2, 3]：
a. order 1 的总数为 20000，fulfiled 为500, 剩余可成交为 20000 - 500 = 15000;
b. order 2 的总数为 10000，fulfiled 为0，剩余可成交为 10000；
c. order 3 的总数为 50000，fulfiled 为25000，剩余可成交为 25000；
则如果吃单要把以上订单全部吃掉，则 amtToTakens 参数应该是： [15000, 10000, 25000]；
如果吃掉仅吃部分数量，则数组中的数量根据吃单者的需求来相应的减少


页面UI逻辑：
1. 用户可以选择多个订单成交；
2. 用户只能选择与一个方向的订单成交；
2. 当用户选择一个订单时，从taker的买入方向来看，判断该订单的价格在用户所有已选择的订单中，是否最高价卖出，
   如果是，则允许用户修改订单数量；否则，显示该订单的最大买入数量；换句话说，如果用户选择多个订单，则只有
   一个订单可以修改数量。


# LP 挖矿

## 合约地址
* ebetoken: 0xfb1A388c9762f954Ff7D50f2B2327c2089305462

* hecopool: 0xeAdA2da088f2655fCf2A01b9B408AE9F9A5D3C66

## 矿池列表

```
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. EBEs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that EBEs distribution occurs.
        uint256 accEbePerShare; // Accumulated EBEs per share, times 1e12.
        uint256 accMultLpPerShare; //Accumulated multLp per share
        uint256 totalAmount;    // Total amount of current pool deposit.
    }

    PoolInfo[] public poolInfo;

```

可以通过数组 poolInfo 的长度来获取一共多少个矿池，然后根据 id 来获取矿池的信息

## 在矿池的存币挖矿的数量、待支付收益

```
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
        uint256 multLpRewardDebt; //multLp Reward debt.
    }
    
    // Info of each user that stakes LP tokens.
    // 第一个索引 uint256: 矿池id
    // 第二个索引 address: 用户地址
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
```


计算待支付收益：
```
// 第一个返回是 ebe 收益
// 第二个是用户质押的token数量
function pending(uint256 _pid, address _user) external view returns (uint256, uint256)
```

或者:

```
    // @param: hecopool hecopool 合约地址
    // @param: pid: 矿池id
    // @param: user: 用户地址
    const getUserPendReward = async (hecopool: string, pid: number, user: string) => {
        let pool = await hecopoolC.poolInfo(pid)
            , lpTokenC = getTokenContract(pool.lpToken, namedSigners[0])
            , lpSupply = await lpTokenC.balanceOf(hecopool)
        if (lpSupply.eq(0)) {
            return BigNumber.from(0)
        }

        let totalAllocPoint = await hecopoolC.totalAllocPoint()
            , blockReward = await hecopoolC.getEbeBlockReward(pool.lastRewardBlock)
            , ebeReward = blockReward.mul(pool.allocPoint).div(totalAllocPoint)
            , accEbePerShare = pool.accEbePerShare.add(ebeReward.mul(1e12).div(lpSupply))
            , userInfo = await hecopoolC.userInfo(pid, user)

        let pendingAmount = userInfo.amount.mul(accEbePerShare).div(1e12).sub(userInfo.rewardDebt);
        return pendingAmount
    }
```

## deposit 存币挖矿

```
function deposit(uint256 _pid, uint256 _amount) public
```

说明：
* _pid: 矿池的id
* _amount: 存币挖矿的数量

调用该函数之前，需要approve: 
```
IERC20(lpToken).approve(合约地址)
```

## 取回

```
function withdraw(uint256 _pid, uint256 _amount) public
```

说明：
* _pid: 矿池的id
* _amount: 存币挖矿的数量, amount 填0就是只取回收益

