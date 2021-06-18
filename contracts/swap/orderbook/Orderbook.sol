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
pragma solidity ^0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interface/IERC20.sol";

import "hardhat/console.sol";

contract OrderBook is Ownable {
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

  using SafeMath for uint;
  using SafeMath for uint256;

  struct OrderItem {
    uint orderId;
    address srcToken;
    address destToken;
    address owner;
    address to;
    uint amountIn;
    uint minAmountOut;
    uint timestamp;
    uint flag;
  }

  // 计算价格的乘数 price = token0 * priceRatio / token1, such as 1e30
  uint public priceRatio = 1e30; 

  uint public itemId;

  // 关闭订单薄功能
  bool public closed;
  address public router;
  address public wETH;
  address public ctokenFactory;
  address public marginAddr;

  uint public minBuyAmt;
  uint public minSellAmt;
  uint public feeRate = 30; // 千分之三

    // token 最低挂单量
    mapping(address => uint) minAmounts;

    // orders
    mapping (uint256 => OrderItem) public orders;
    mapping (address => uint256[]) public addressOrders;
    mapping (address => uint256[]) public pairOrders;
  // uint public bestSellPrice;   // 最低卖价
  // uint public bestBuyPrice;    // 最高买价

  constructor(address _router, address _ctokenFactory, address _wETH, address _margin) public {
    router = _router;
    wETH = _wETH;
    ctokenFactory = _ctokenFactory;
    marginAddr = _margin;
  }

  modifier onlyRouter() {
    // require(msg.sender == router, "only router call");
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

  function _putOrder(uint direction, uint amount, uint minOutAmt, uint _itemId, address to) internal {
    // PriceOrders storage priceOrders;

    // if (direction == 0) {
    //   priceOrders = buyOrders[price];
    // } else {
    //   priceOrders = sellOrders[price];
    // }

    // OrderItem storage item;
    address token;

    if (direction == 0) {
      // 挂买单
      OrderItem storage item = buyOrders[_itemId];
      token = address(token1);
      item.owner = to;
      // item.price = price;
      item.amount = amount;
    } else {
      OrderItem storage item = sellOrders[_itemId];
      token = address(token0);
      item.owner = to;
      // item.price = price;
      item.amount = amount;
    }
    
    emit CreateOrder(to, token, _itemId, 0, amount);
  }

  // 在router中已经把token转入
  function putOrder(uint direction, uint amount, uint minOutAmt, address to) public onlyRouter returns (uint) {
    itemId ++;

    _putOrder(direction, amount, minOutAmt, itemId, to);
    return itemId;
  }


  // 删除 order item
  // function _removeOrderItem(PriceOrders storage priceOrders, uint price, uint itemId) private returns (bool){
  //   OrderItem memory orderItem = priceOrders[itemId];
  //   delete priceOrders[itemId];

  //   if (priceOrders.firstItemId == itemId) {
  //     priceOrders.firstItemId = orderItem.next;
  //   }
  //   if (priceOrders.lastItemId == itemId) {
  //     priceOrders.lastItemId = orderItem.prev;
  //   }
  //   if (orderItem.next != 0) {
  //     OrderItem storage next = priceOrders[orderItem.next];
  //     next.prev = orderItem.prev;
  //   }
  //   if (orderItem.prev != 0) {
  //     OrderItem storage prev = priceOrders[orderItem.prev];
  //     prev.next = orderItem.next;
  //   }
  //   if (orderItem.amount > 0) {
  //     // todo transfer token to user
  //   }

  //   return priceOrders.firstItemId == 0;
  // }

  // todo 增加参数 address to, 该参数通过 router 合约传入， 并验证 to == item.owner 
  function cancelOrder(uint direction, uint _itemId, address to) public onlyRouter {

    if (direction == 0) {
      // 买单
      OrderItem memory item = buyOrders[_itemId];
      if (item.amount > 0) {
        require(item.owner == to, "not permit");
        // transfer to msg.sender
        console.log("balance: ", token1.balanceOf(address(this)), item.amount);
        IERC20(token1).transfer(item.owner, item.amount);
      }
      delete buyOrders[_itemId];
    } else {
      // 卖单
      OrderItem memory item = sellOrders[_itemId];
      if (item.amount > 0) {
        require(item.owner == to, "not permit");
        // transfer to msg.sender
        IERC20(token0).transfer(item.owner, item.amount);
      }
      delete sellOrders[_itemId];
    }

    // bool empty = _removeOrderItem(priceOrders, price, itemId);
    // if (empty) {
    //   if (direction == 0) {
    //     delete buyOrders[price];
    //   } else {
    //     delete sellOrders[price];
    //   }
    // }
  }

  // 能买到多少
  // function _buyAmt(uint amt, uint price) internal pure returns (uint) {
  //   return amt * priceRatio / price;
  // }

  // router swap 应该已经把币(扣除手续费)转进来，且已经收了手续费   _amount 为扣除手续费后的
  // 撮合成交
  // pair: token0/token1  price = token1/token0
  // todo events
  function dealOrders(uint direction, uint _amount, uint[] memory items, address to) public onlyRouter {
    // uint amount = _amount * (10000 - feeRate) / 10000;
    uint amount = _amount;
    uint total;

    if (direction == 0) {
      // 买入 操作的是 sellOrders
      console.log("dir = 0, buy order");
      for (uint i = 0; amount > 0 && i < items.length; i ++) {
        uint _itemId = items[i];
        OrderItem storage item = sellOrders[_itemId];
        console.log(_itemId, 0, item.amount);
        if (item.amount > 0) {
          uint money = item.amount.mul(0).div(priceRatio);
          console.log("amount: %d money: %d", amount, money);
          if (amount >= money) {
            // 这个订单全部被买走
            // 买家得到的token0数量
            uint amt0 = item.minDestAmount;
            console.log("amt0: %d total: %d", amt0, total);
            total = total + amt0;
            amount = amount - money;
              // transfer to order book owner
            IERC20(token1).transfer(item.owner, money);
            
            delete sellOrders[_itemId];
          } else {
            uint amt0 = item.minDestAmount;
            total += amt0;
            item.amount -= amt0;
              // transfer to order book owner
            IERC20(token1).transfer(item.owner, amount);
            // transfer to order book owner
            break;
          }
        } else {
          //
          delete sellOrders[_itemId];
        }
      }
      if (total > 0) {
        token0.transfer(to, total);
      }
      console.log("buy:", total);
    } else {
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
      if (total > 0) {
        token1.transfer(to, total);
      }
      console.log("sell got:", total);
    }
  }

  ////////////////////////////////////////////////////////////////////
  // 查询可成交的价格的订单, 返回 orderItem[]. 应该在外部调用，节省手续费
  function getDealableOrderItems(uint direction, uint price, uint amount) external view returns (uint[] memory) {
    uint[] memory items;

    return items;
  }
}
