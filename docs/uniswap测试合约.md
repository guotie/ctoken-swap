# uniswap 测试合约

## 地址

### 测试 swap 1

* factory 地址: 0xa61cF1DC3a9D4AE282D7ca60b24B26fd36B7FbeA
* router 地址: 0x7cE170c33c1D68F564301Fb122946464E9480864


### 测试 swap 2

* factory 地址: 0x062594B0489F1371F2B5fCde89377A45a0d82308
* router 地址: 0xadbc10AD6647b9AFc3510B190876cE5a7e1AfFdA

## API

接口基本上与 ebank 的router接口一样，只不过没有 `Underlying` 接口


## HT 提供流动性
```
    function addLiquidityETH(
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


## 移除token和token的交易对流动性，得到token
```
    function removeLiquidity(
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
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountToken, uint amountETH) {
```


### 兑换 exact token -> token

```
    // 兑换 token/token。输入确定，输出不低于 amountOutMin
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
```

### 兑换 exact token -> eth

```
    // 兑换 token/eth。输入token确定，输出不低于 amountOutMin
    function swapExactTokensForETHUnderlying(
          uint amountIn,
          uint amountOutMin,
          address[] calldata path,
          address to,
          uint deadline)
        external
        returns (uint[] memory amounts);
```

### 兑换 exact eth -> token

```
    function swapExactETHForTokens(
          uint amountOutMin,
          address[] calldata path,
          address to,
          uint deadline)
      external
      payable
      returns (uint[] memory amounts);
```
