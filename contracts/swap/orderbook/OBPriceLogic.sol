// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./ICToken.sol";
import "./SafeMath.sol";
import "./DataTypes.sol";

// 根据compound 最新的 exchange rate 换算 挂单时的价格, 根据 taker 的吃单量换算挂单者
// 1. tokenIn 和 tokenOut都是 etoken: 不需要换算
// 2. tokenIn tokenOut 都是 token: 
library OBPriceLogic {
    using SafeMath for uint;
    using SafeMath for uint256;

    // struct OBPrice {
    //     address src;
    //     address srcEToken;
    //     address dst;
    //     address dstEToken;
    //     uint256 amtIn;
    //     uint256 eAmtIn;
    //     uint256 amtOut;
    //     uint256 eAmtOut;
    //     // uint256 feeTaker;
    //     // uint256 feeMaker;
    // }

    // uint256 constant public DENOMINATOR = 10000;

    function getCurrentExchangeRate(ICToken ctoken) public view returns (uint256) {
        uint rate = ctoken.exchangeRateStored();
        uint supplyRate = ctoken.supplyRatePerBlock();
        uint lastBlock = ctoken.accrualBlockNumber();
        uint blocks = block.number.sub(lastBlock);
        uint inc = rate.mul(supplyRate).mul(blocks);
        return rate.add(inc);
    }

    /// @dev 根据价格计算 amtToTaken 对应的 amtOut
    /// @param data OBPrice to calcutation
    /// @param amtToTaken amount to taken, in etoken
    /// @return maker 得到的币数量; 单位 etoken 
    function convertBuyAmountByETokenIn(DataTypes.TokenAmount memory data, uint amtToTaken) public view returns (uint) {
        address src = data.srcToken;
        address srcEToken = data.srcEToken;
        address dst = data.destToken;
        address dstEToken = data.destEToken;
        // uint256 feeTaker = DENOMINATOR - data.feeTaker;
        // uint256 feeMaker = DENOMINATOR - data.feeMaker;

        if (src == srcEToken && dst == dstEToken) {
            // 挂单就是以 etoken 来挂的
            return amtToTaken.mul(data.guaranteeAmountOut).div(data.amountIn);
            // return amtToSent;
        }

        // 由于目前 create order已经限制了必须同时为 token 或者 etoken
        require(src != srcEToken && dst != dstEToken, "invalid orderbook tokens");
        
        // price = amtOut/amtIn = eAmtOut*rateOut/(eAmtIn*rateIn)
        // eprice = (price*rateIn)/rateOut = (amtOut*rateIn)/(amtIn*rateOut)
        uint256 rateIn = getCurrentExchangeRate(ICToken(srcEToken));
        uint256 rateOut = getCurrentExchangeRate(ICToken(dstEToken));

        // 吃单者需要转入的币的数量
        return amtToTaken.mul(rateIn).mul(data.guaranteeAmountOut).div(data.amountIn).div(rateOut);
        // return (amtToSendByEToken, amtToTaken);
    }


}