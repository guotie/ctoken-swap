# eToken

当用户把 Token 存入借贷池中时, 系统会给用户发放一定数量的 eToken, 用户凭 eToken 赎回 Token.

## 对应关系

可以通过合约来查询 token 对应的 eToken 地址，以及 eToken 对应的 token 地址。

* 合约名称：LErc20DelegatorFactory
* 合约地址：
* 合约方法：

```
    //根据 'token' 获得 'cToken'
    function getCTokenAddressPure(address token) external returns (address cToken)
```

```

     //根据 'cToken' 获得 'token'
    function getTokenAddress(address cToken) external view returns (address)

```


注意：
1. token 地址为0时，对应的 eToken 地址是 LHT 地址；
2. 当 eToken 地址为 LHT 地址时，对应的 token 地址是 0；

## 兑换关系

eToken = Token / exchangeRate

exchangeRate 可以理解为利率，随着时间的推移，会不断增长，因此，用户在存入 Token 时, 得到了
```
Token / rate1
```
数量的 eToken.


当用户赎回时, 此时 exchangeRate 增加到 `rate2`, 用户可以赎回的 token 数量为：
```
eToken * rate2
```

由于 `rate2 > rate1`, 因此，用户赎回的 token 比存入时多出一部分，这部分就是用户的存款利息。

