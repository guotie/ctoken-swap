// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

library DataTypes {
    uint constant internal  SRC_IS_ETOKEN = 0x00001; // prettier-ignore
    uint constant internal DEST_IS_ETOKEN = 0x00002;
 
    struct TokenAmount {
        uint isEToken;            // 挂单卖出的币是否是 eToken | 挂单卖出的币是否是 etoken 
        address srcToken;
        address destToken;
        address srcEToken;             // srcToken 对应的 eToken
        address destEToken;            // destToken 对应的 eToken
        uint amountIn;                 // 初始挂单数量
        uint amountInMint;             // 如果 srcToken 不是 eToken, mint 成为 etoken 的数量
        uint fulfiled;                 // 已经成交部分, 单位 etoken
        uint guaranteeAmountOut;       // 最低兑换后要求得到的数量
        uint guaranteeAmountOutEToken; // 最低兑换后要求得到的 etoken 数量
    }

    struct OrderItem {
      uint orderId;
      uint pairAddrIdx;        // pairIdx | addrIdx
      uint pair;               // hash(srcToken, destToken)
      uint timestamp;          // 过期时间 | 挂单时间 
      uint flag;
      address owner;
      address to;              // 兑换得到的token发送地址 未使用
      TokenAmount tokenAmt;
    }

    struct OBPairConfigMap {
      // bit 0-127 min amount
      // bit 128-191 maker fee rate
      // bit 192-255 taker fee rate
      uint256 data;
    }
}
