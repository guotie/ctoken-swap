# 兑换

# Router合约

合约地址：
* HECO测试链: 0x0826d36cecA6240B6A894796C3c3F90030CE6fB8
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
* HECO测试链: 0xA099bddBe031190272B612DA039113e8B6Cc5d4C
* HECO主链:

挂单定义:

```
    struct TokenAmount {
        address srcToken;
        address destToken;
        uint amountIn;           // 初始挂单数量
        uint fulfiled;         // 部分成交时 剩余待成交金额
        uint guaranteeAmountOut;       // 最低兑换后要求得到的数量
        // uint guaranteeAmountOutLeft;   // 兑换一部分后, 剩下的需要兑换得到的数量
    }

    struct OrderItem {
      uint orderId;
      uint pairAddrIdx;        // pairIdx | addrIdx
      address owner;           // 订单属主
      address to;              // 兑换得到的token发送地址 未使用
      uint pair;               // hash(srcToken, destToken)
      uint timestamp;          // 过期时间 | 挂单时间 
      uint flag;
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
        uint expiredAt,          // 订单过期时间, 0 为不过期
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

maker 的挂单被吃后, maker 得到的 token 保存在合约中, maker 需要手动提取

```
function withdraw(address token, uint amt) external
```

