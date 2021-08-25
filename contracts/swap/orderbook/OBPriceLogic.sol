// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
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

    function refreshTokenExchangeRate(ICToken ctoken) public returns (uint256) {
        return ctoken.exchangeRateCurrent();
    }

    /// @dev 根据价格计算 amtToTaken 对应的 amtOut. 如果挂单时 destToken 是 ctoken, 则直接计算比例; 否则, 需要将挂单设置的guaranteeAmountOut转换为 etoken 数量, 再计算
    /// @param data OBPrice to calcutation
    /// @param amtToTaken amount to taken, in etoken
    /// @return maker 得到的币数量; 单位 etoken 
    function convertBuyAmountByETokenIn(
                    DataTypes.TokenAmount memory data,
                    uint amtToTaken
                )
                public
                view
                returns (uint) {
        // address src = data.srcToken;
        // address srcEToken = data.srcEToken;
        address dst = data.destToken;
        address dstEToken = data.destEToken;
        // // uint256 feeTaker = DENOMINATOR - data.feeTaker;
        // // uint256 feeMaker = DENOMINATOR - data.feeMaker;

        if (dst == dstEToken) {
            // 挂单就是以 etoken 来挂的
            return amtToTaken.mul(data.guaranteeAmountOut).div(data.amountInMint);
        }
        uint destRate = getCurrentExchangeRate(ICToken(dstEToken));
        uint destEAmt = data.guaranteeAmountOut.mul(1e18).div(destRate);
        return amtToTaken.mul(destEAmt).div(data.amountInMint);
    }


}