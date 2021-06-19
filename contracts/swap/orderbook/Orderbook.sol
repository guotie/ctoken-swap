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

import "../aggressive/Ownable.sol";
import "../aggressive/SafeMath.sol";
import "../aggressive/IERC20.sol";

import "hardhat/console.sol";

interface ISwapMining {
    function swap(address account, address input, address output, uint256 amount) external returns (bool);
}

// 存储
contract OBStorage is Ownable {
    uint private constant _PAIR_INDEX_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;   // 128 bit
    uint private constant _ADDR_INDEX_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   // 128 bit
    uint private constant _MARGIN_MASK     = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint private constant _EXPIRED_AT_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   // 128 bit
    uint private constant _ADDR_INDEX_OFFSET = 128;
    uint private constant _EXPIRED_AT_OFFSET = 128;

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
      address owner;
      address to;              // 兑换得到的token发送地址 未使用
      uint pair;               // hash(srcToken, destToken)
      uint timestamp;          // 过期时间 | 挂单时间 
      uint flag;
      TokenAmount tokenAmt;
      // bool margin;             // 是否是杠杆合约的挂单
    }

    // 计算价格的乘数 price = token0 * priceRatio / token1, such as 1e30
    uint public priceRatio = 1e30; 

    uint public orderId;   // order Id 自增

    // 关闭订单薄功能
    bool public closed;
    address public router;
    address public wETH;
    address public ctokenFactory;
    address public marginAddr;  // 代持合约
    address public swapMining;  // 交易挖矿

    uint public minBuyAmt;
    uint public minSellAmt;
    uint public feeRate = 30; // 千分之三

    // token 最低挂单量
    mapping(address => uint) public minAmounts;
    mapping(address => mapping(address => uint)) balanceOf;   // 代持用户的币

    // orders
    mapping (uint => OrderItem) public orders;
    mapping (address => uint[]) public marginOrders;   // 杠杆合约代持的挂单
    mapping (address => uint[]) public addressOrders;
    mapping (uint => uint[]) public pairOrders;

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

    function getExpiredAt(uint ts) public pure returns (uint) {
      return (ts & _EXPIRED_AT_MASK) >> _EXPIRED_AT_OFFSET;
    }

    function maskTimestamp(uint ts, uint expired) public pure returns (uint) {
      return (ts) | (expired << _EXPIRED_AT_OFFSET);
    }
    
    function setSwapMining(address _swapMininng) public onlyOwner {
        swapMining = _swapMininng;
    }
}

interface IWHT {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IOrderBook {
    event CreateOrder(address indexed owner,
          address indexed srcToken,
          address indexed destToken,
          uint orderId,
          uint amountIn,
          uint minAmountOut,
          uint flag);

    event FulFilOrder(address indexed maker,
          address indexed taker,
          uint orderId,
          uint amt,
          uint amtOut,
          uint remaining);

    event CancelOrder(address indexed owner, uint orderId);
}

contract OrderBook is OBStorage, IOrderBook {
    using SafeMath for uint;
    using SafeMath for uint256;

    constructor(address _router, address _ctokenFactory, address _wETH, address _margin) public {
      router = _router;
      wETH = _wETH;
      ctokenFactory = _ctokenFactory;
      marginAddr = _margin;
    }

    modifier whenOpen() {
        require(closed == false, "order book closed");
        _;
    }

    function closeOrderBook() external onlyOwner {
      closed = true;
    }

    function openOrderBook() external onlyOwner {
      closed = false;
    }

    function setMinOrderAmount(address token, uint amt) external onlyOwner {
      minAmounts[token] = amt;
    }


    function closeOrder(uint orderId) public {
      OrderItem memory order = orders[orderId];
    }

    function _putOrder(OrderItem storage order) internal {
      uint orderId = order.orderId;
      bool margin = isMargin(order.flag);
      uint addrIdx;
      uint pairIdx;

      if (margin) {
          addrIdx = marginOrders[order.owner].length;
          marginOrders[order.owner].push(orderId);
      } else {
          addrIdx = addressOrders[order.owner].length;
          addressOrders[order.owner].push(orderId);
      }

      pairIdx = pairOrders[order.pair].length;
      pairOrders[order.pair].push(orderId);

      order.pairAddrIdx = maskAddrPairIndex(pairIdx, addrIdx);

      emit CreateOrder(order.owner,
          order.tokenAmt.srcToken,
          order.tokenAmt.destToken,
          orderId,
          order.tokenAmt.amountIn,
          order.tokenAmt.guaranteeAmountOut,
          order.flag);
    }

    function _removeOrder(OrderItem memory order) private {
        uint orderId = order.orderId;
        uint pairIdx = pairIndex(order.pairAddrIdx);
        uint addrIdx = addrIndex(order.pairAddrIdx);
        address owner = order.owner;
        uint rIdx;
        bool margin = isMargin(order.flag);
        
        if (margin) {
            rIdx = marginOrders[owner][marginOrders[owner].length - 1];
            marginOrders[owner][addrIdx] = rIdx;
            orders[rIdx].pairAddrIdx = updateAddrIdx(orders[rIdx].pairAddrIdx, addrIdx);
            marginOrders[owner].pop();
        } else {
            rIdx = addressOrders[owner][addressOrders[owner].length - 1];
            addressOrders[owner][addrIdx] = rIdx;
            orders[rIdx].pairAddrIdx = updateAddrIdx(orders[rIdx].pairAddrIdx, addrIdx);
            addressOrders[owner].pop();
        }

        rIdx = pairOrders[order.pair][pairOrders[order.pair].length - 1];
        pairOrders[order.pair][pairIdx] = rIdx;
        orders[rIdx].pairAddrIdx = updatePairIdx(orders[rIdx].pairAddrIdx, pairIdx);

        pairOrders[order.pair].pop();

        delete orders[orderId];
    }

    // 在router中已经把token转入
    function createOrder(
        address srcToken,
        address destToken,
        address from,           // 兑换得到的token发送地址 未使用
        address to,           // 兑换得到的token发送地址 未使用
        uint amountIn,
        uint guaranteeAmountOut,       // 
        uint timestamp,          // 挂单时间
        uint expiredAt,          // 过期时间
        uint flag) public payable whenOpen returns (uint) {
      require(srcToken != destToken, "identical token");
      require(expiredAt == 0 || expiredAt > block.timestamp, "invalid param expiredAt");

      if (srcToken == address(0)) {
        // 转入 wETH
        require(msg.value >= amountIn, "not enough amountIn");
        // IWHT(wETH).deposit{value: msg.value}();
        srcToken = wETH;
      } else {
        // should approve outside
        TransferHelper.safeTransferFrom(srcToken, msg.sender, address(this), amountIn);
      }

      {
        // 最低挂单量限制
        // uint minAmt = ;
        require(amountIn > minAmounts[srcToken], "less than min amount");
      }
      uint idx = orderId ++;
      OrderItem storage order = orders[idx];
      order.orderId = idx;
      order.tokenAmt.srcToken = srcToken;
      order.tokenAmt.destToken = destToken;
      order.owner = from == address(0) ? msg.sender : from;
      order.to = to == address(0) ? msg.sender : to;
      order.tokenAmt.amountIn = amountIn;
      order.tokenAmt.fulfiled = 0;
      order.tokenAmt.guaranteeAmountOut = guaranteeAmountOut;
      // order.tokenAmt.guaranteeAmountOutLeft = guaranteeAmountOutLeft;
      order.timestamp = maskTimestamp(timestamp, expiredAt);
      // order.expiredAt = expiredAt;
      order.flag = flag;

      // (address token0, address token1) = srcToken < destToken ? (srcToken, destToken) : (destToken, srcToken);
      order.pair = pairFor(srcToken, destToken);

      _putOrder(order);

      return orderId;
    }

    function pairFor(address srcToken, address destToken) public view returns(uint pair) {
      if (srcToken == address(0)) {
          srcToken = wETH;
      }
      if (destToken == address(0)) {
          destToken = wETH;
      }
      (address token0, address token1) = srcToken < destToken ? (srcToken, destToken) : (destToken, srcToken);
      pair = uint(keccak256(abi.encodePacked(token0, token1)));
    }

    // 增加参数 address to, 该参数通过 router 合约传入， 并验证 to == item.owner 
    function cancelOrder(uint orderId) public {
      OrderItem memory order = orders[orderId];

      if (isMargin(order.flag)) {
        require(msg.sender == marginAddr || msg.sender == owner(), "cancelOrder: no auth");
      } else {
        require(msg.sender == owner() || msg.sender == order.owner, "cancelOrder: no auth");
      }
      address srcToken = order.tokenAmt.srcToken;
      if (srcToken == address(0)) {
        TransferHelper.safeTransferETH(order.owner, order.tokenAmt.fulfiled);
      } else {
        TransferHelper.safeTransfer(srcToken, order.owner, order.tokenAmt.fulfiled);
      }
      _removeOrder(order);
    }

    // 剩余可成交部分
    function _amountRemaining(uint amtTotal, uint fulfiled) internal pure returns (uint) {
        // (amtTotal - fulfiled) * (1 - fee)
        return (amtTotal - fulfiled);
    }

    // buyAmt: 待买走的挂卖token的数量, 未扣除手续费
    // outAmt: 挂卖得到的token 的数量, 未扣除手续费
    function _swap(address srcToken, address destToken, address maker, address buyer, uint buyAmt, uint outAmt, bool margin) private {
      // bool margin = isMargin(order.flag);

      if (margin) {
        // todo 回调
      } else {
        balanceOf[destToken][maker] += outAmt;
      }

      // 买家得到的币
      if (srcToken == address(0)) {
        TransferHelper.safeTransferETH(buyer, buyAmt);
      } else {
        TransferHelper.safeTransfer(srcToken, buyer, buyAmt);
      }
    }

    // todo
    function getFeeRate() public view returns (uint) {
      return 10000 - 30;
    }

    // order 成交, 收取成交后的币的手续费
    // todo 
    function fulfilOrder(uint orderId, uint amtToTaken) external payable whenOpen {
      OrderItem storage order = orders[orderId];
      uint left = _amountRemaining(order.tokenAmt.amountIn, order.tokenAmt.fulfiled);

      require(left >= amtToTaken, "not enough");

      address destToken = order.tokenAmt.destToken;
      // 挂单者在不扣除手续费的情况下得到的币的数量
      uint amtDest = amtToTaken.mul(order.tokenAmt.guaranteeAmountOut).div(order.tokenAmt.amountIn);
      uint fee = getFeeRate();
      // 买家得到的
      uint _buyAmt = amtToTaken.mul(fee).div(10000);
      uint _outAmt = amtDest.mul(fee).div(10000);
      _swap(order.tokenAmt.srcToken, order.tokenAmt.destToken, order.owner, msg.sender, _buyAmt, _outAmt, isMargin(order.flag));

      // 验证转移买家的币
      if (destToken == address(0)) {
        require(msg.value >= amtDest, "amount not transfer in");
      } else {
        TransferHelper.safeTransferFrom(destToken, msg.sender, address(this), amtDest);
      }

      left -= amtToTaken;
      order.tokenAmt.fulfiled += amtToTaken;

      emit FulFilOrder(order.owner, msg.sender, orderId, amtToTaken, amtDest, left);
      if (left == 0) {
        //
        _removeOrder(order);
      }
    }

    // function fulfilOrders(uint[] memory orderIds, uint[] memory amtToTaken) external whenOpen {
    //     require(orderIds.length == amtToTaken.length, "array length should equal");

    //     for (uint i = 0; i < orderIds.length; i ++) {
    //       try fulfilOrder(orderIds[i], amtToTaken[i]) {
    //       } catch {
    //         // nothing
    //       }
    //     }
    // }

    // 用户成交后，资金由合约代管, 用户提现得到自己的 token
    function withdraw(address token, uint amt) external {
        uint total = balanceOf[token][msg.sender];
        require(total >= amt, "not enough asset");

        if (token == address(0)) {
          TransferHelper.safeTransferETH(msg.sender, amt);
        } else {
          TransferHelper.safeTransferFrom(token, address(this), msg.sender, amt);
        }

        balanceOf[token][msg.sender] = total.sub(amt);
    }

    // 将手续费收入转移
    function adminTransfer(address token, address to, uint amt) external onlyOwner {
        if (token == address(0)) {
          TransferHelper.safeTransferETH(to, amt);
        } else {
          TransferHelper.safeTransferFrom(token, address(this), to, amt);
        }
    }

  // 能买到多少
  // function _buyAmt(uint amt, uint price) internal pure returns (uint) {
  //   return amt * priceRatio / price;
  // }

  // router swap 应该已经把币(扣除手续费)转进来，且已经收了手续费   _amount 为扣除手续费后的
  // 撮合成交
  // pair: token0/token1  price = token1/token0
  // todo events
  // function dealOrders(uint direction, uint _amount, uint[] memory items, address to) public {
    // uint amount = _amount * (10000 - feeRate) / 10000;
    // uint amount = _amount;
    // uint total;

    // if (direction == 0) {
    //   // 买入 操作的是 sellOrders
    //   console.log("dir = 0, buy order");
    //   for (uint i = 0; amount > 0 && i < items.length; i ++) {
    //     uint _itemId = items[i];
    //     OrderItem storage item = sellOrders[_itemId];
    //     console.log(_itemId, 0, item.amount);
    //     if (item.amount > 0) {
    //       uint money = item.amount.mul(0).div(priceRatio);
    //       console.log("amount: %d money: %d", amount, money);
    //       if (amount >= money) {
    //         // 这个订单全部被买走
    //         // 买家得到的token0数量
    //         uint amt0 = item.minDestAmount;
    //         console.log("amt0: %d total: %d", amt0, total);
    //         total = total + amt0;
    //         amount = amount - money;
    //           // transfer to order book owner
    //         IERC20(token1).transfer(item.owner, money);
            
    //         delete sellOrders[_itemId];
    //       } else {
    //         uint amt0 = item.minDestAmount;
    //         total += amt0;
    //         item.amount -= amt0;
    //           // transfer to order book owner
    //         IERC20(token1).transfer(item.owner, amount);
    //         // transfer to order book owner
    //         break;
    //       }
    //     } else {
    //       //
    //       delete sellOrders[_itemId];
    //     }
    //   }
    //   if (total > 0) {
    //     token0.transfer(to, total);
    //   }
    //   console.log("buy:", total);
    // } else {
      // 卖出 操作的是 buyOrders
      // for (uint i = 0; amount > 0 && i < items.length; i ++) {
      //   //
      //   uint _itemId = items[i];
      //   OrderItem storage item = buyOrders[_itemId];
      //   if (item.amount > 0) {
      //     uint q = item.amount * priceRatio / item.price;
      //     if (amount >= q) {
      //       uint amt1 = q * item.price / priceRatio;
      //       amount -= q;
      //       total = total + amt1;
      //       IERC20(token0).transfer(item.owner, q);
      //       delete buyOrders[_itemId];
      //     } else {
      //       uint amt1 = amount * item.price / priceRatio;
      //       total += amt1;
      //       item.amount -= amt1;
      //       IERC20(token0).transfer(item.owner, amount);
      //       break;
      //     }
      //   } else {
      //     delete buyOrders[_itemId];
      //   }
      // }
    //   if (total > 0) {
    //     token1.transfer(to, total);
    //   }
    //   console.log("sell got:", total);
    // }
  // }

  ////////////////////////////////////////////////////////////////////
  // 查询可成交的价格的订单, 返回 orderItem[]. 应该在外部调用，节省手续费
  function getDealableOrderItems(uint direction, uint price, uint amount) external view returns (uint[] memory) {
    uint[] memory items;

    return items;
  }
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call.value(value)(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}
