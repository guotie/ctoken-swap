# OrderBook 升级改动

## abi 需要更新

## 字段名称修改

Order.tokenAmt 字段修改如下：

```
amountIn            -->  amountOut
amountInMint        -->  amountOutMint
guaranteeAmountOut  -->  guaranteeAmountIn
```

## fulfilOrders 及计算 吃单者需要支付的 token 数量

删除最后一个参数 `data`， 目前函数原型:

```
    function fulfilOrders(
                uint[] memory orderIds,
                uint[] memory amtToTakens,
                address to,
                bool isToken,
                bool partialFill
              )
```

增加两个计算函数，用来计算 吃单者 需要支付多少 destToken 或 destEToken:

```
/// @dev 计算成交一个订单的给定amt, 需要支付的 destEToken destToken 数量
function calcTakerAmount(uint id, uint amtToTaken) public view returns (uint takerEAmt, uint takerAmt)
```

```
    /// @dev 计算成交这些订单需要支付的 destEToken destToken 数量
    function calcTakerAmounts(uint[] memory orderIds) public view returns (uint totalEAmt, uint totalAmt) {
```

这两个函数对于 destToken 是 HT 的订单尤其重要，因为如果 taker 支付的是token，用户授权合约，合约转入相应数量的 token, 完成成交；当需要吃单者支付 HT 时，需要在发交易时就已经支付完成，因此，需要提交计算吃单者需要支付的数量。由于 etoken/token 的兑换比例在不断增加，因此，最好在计算的结果后，乘以1.01, 合约会退回多余的 HT

这两个函数也可以用于界面上显示给用户，需要支付多少数量的 token

## createOrder

对前端影响不大

```
    function createOrder(
              address srcToken,
              address destToken,
              address to,            
              uint amountOut,             //  原来是amountIn, 现改为 amountOut
              uint guaranteeAmountIn,       // 
              uint flag
          )
```

