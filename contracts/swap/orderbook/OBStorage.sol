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
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";
import { DataTypes } from "./DataTypes.sol";
import { OBPairConfig } from "./OBPairConfig.sol";

// 存储
contract OBStorage is Ownable {
    using OBPairConfig for DataTypes.OBPairConfigMap;

    uint private constant _PAIR_INDEX_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;   // 128 bit
    uint private constant _ADDR_INDEX_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   // 128 bit
    uint private constant _MARGIN_MASK     = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint private constant _EXPIRED_AT_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   // 128 bit
    uint private constant _ADDR_INDEX_OFFSET = 128;
    // uint private constant _EXPIRED_AT_OFFSET = 128;

    uint256 public constant DENOMINATOR = 10000;

    // // 计算价格的乘数 price = token0 * priceRatio / token1, such as 1e30
    // uint public priceRatio = 1e30; 

    uint public orderId;   // order Id 自增

    // 关闭订单薄功能
    bool    public closed; // prettier-ignore
    // address public router;
    address public wETH;
    address public cETH;  // compound ETH token
    address public ctokenFactory;
    address public marginAddr;  // 代持合约
    address public feeTo;       // 手续费地址

    // 每个杠杆用户 每个pair 的最大订单量
    uint public maxMarginOrder = 5;
    // maker 手续费 && taker 手续费
    uint public defaultFeeMaker = 30;
    uint public defaultFeeTaker = 30;
    mapping(uint256 => DataTypes.OBPairConfigMap) public pairFeeRate;
    // 最低挂单量
    mapping(address => uint256) public minAmounts;
    mapping(address => mapping(address => uint)) public balanceOf;   // 代持用户的币

    // orders
    mapping (uint => DataTypes.OrderItem) public orders;
    mapping (address => uint[]) public marginOrders;         // 杠杆合约代持的挂单
    mapping (address => uint[]) public addressOrders;
    mapping (uint => uint[]) public pairOrders;
    mapping (address => mapping(uint => uint)) public marginUserOrderCount;   // 杠杆合约用户的挂单总数量, 每个交易对限制

    function pairIndex(uint id) public pure returns(uint) {
        return (id & _PAIR_INDEX_MASK);
    }

    function addrIndex(uint id) public pure returns(uint) {
        return (id & _ADDR_INDEX_MASK) >> _ADDR_INDEX_OFFSET;
    }

    // pairIdx 不变, addrIdx 更新
    function updateAddrIdx(uint idx, uint addrIdx) public pure returns(uint) {
      return pairIndex(idx) | addrIndex(addrIdx);
    }

    // pairIdx 不变, addrIdx 更新
    function updatePairIdx(uint idx, uint pairIdx) public pure returns(uint) {
      return (idx & _ADDR_INDEX_MASK) | pairIdx;
    }

    function maskAddrPairIndex(uint pairIdx, uint addrIdx) public pure returns (uint) {
        return (pairIdx) | (addrIdx << _ADDR_INDEX_OFFSET);
    }

    function isMargin(uint flag) public pure returns (bool) {
      return (flag & _MARGIN_MASK) != 0;
    }

    // function getExpiredAt(uint ts) public pure returns (uint) {
    //   return (ts & _EXPIRED_AT_MASK) >> _EXPIRED_AT_OFFSET;
    // }

    // function maskTimestamp(uint ts, uint expired) public pure returns (uint) {
    //   return (ts) | (expired << _EXPIRED_AT_OFFSET);
    // }
    
    // function setSwapMining(address _swapMininng) public onlyOwner {
    //     swapMining = _swapMininng;
    // }
}
