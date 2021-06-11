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
  event CreateOrder(address indexed owner, address indexed token, uint itemId, uint price, uint amount);

  using SafeMath for uint;
  using SafeMath for uint256;

  struct OrderItem {
    address owner;
    uint price;
    uint amount;
    // 通过
    // uint next;
    // uint prev;
    // uint itemId;
  }

  // struct PriceOrders {
  //   uint firstItemId;
  //   uint lastItemId;
  //   mapping(uint => OrderItem) orders;  // key: itemId
  // }

  // 计算价格的乘数 price = token0 * priceRatio / token1, such as 1e30
  uint public priceRatio = 1e30; 

  uint public itemId;
  mapping(uint => OrderItem) public buyOrders;
  mapping(uint => OrderItem) public sellOrders;

  IERC20 public token0;
  IERC20 public token1;

  address public router;

  uint public minBuyAmt;
  uint public minSellAmt;
  uint public feeRate = 30; // 千分之三

  // uint public bestSellPrice;   // 最低卖价
  // uint public bestBuyPrice;    // 最高买价

  constructor(address _router, address _token0, address _token1, uint _minBuyAmt, uint _minSellAmt) {
    router = _router;
    token0 = IERC20(_token0);
    token1 = IERC20(_token1);

    minBuyAmt = _minBuyAmt;
    minSellAmt = _minSellAmt;
  }

  modifier onlyRouter() {
    // require(msg.sender == router, "only router call");
    _;
  }

  function _putOrder(uint direction, uint price, uint amount, uint itemId, address to) internal {
    // PriceOrders storage priceOrders;

    // if (direction == 0) {
    //   priceOrders = buyOrders[price];
    // } else {
    //   priceOrders = sellOrders[price];
    // }

    OrderItem storage item;
    address token;

    if (direction == 0) {
      // 挂买单
      item = buyOrders[itemId];
      token = address(token1);
    } else {
      item = sellOrders[itemId];
      token = address(token0);
    }
    item.owner = to;
    item.price = price;
    item.amount = amount;
    
    emit CreateOrder(to, token, itemId, price, amount);
    // item.itemId = itemId;
    // item.prev = 0;     // 链表前一个
    // item.next = 0;     // 链表后一个

    // priceOrders.lastItemId = itemId;

    // if (priceOrders.firstItemId == 0) {
    //   priceOrders.firstItemId = itemId;
    // } else {
    //   OrderItem last = priceOrders.orders[priceOrders.lastItemId];

    //   last.next = itemId;
    //   item.prev = last.itemId;
    // }
  }

  // 在router中已经把token转入
  function putOrder(uint direction, uint price, uint amount, address to) public onlyRouter returns (uint) {
    itemId ++;

    _putOrder(direction, price, amount, itemId, to);
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
  function cancelOrder(uint direction, uint itemId, address to) public onlyRouter {

    if (direction == 0) {
      // 买单
      OrderItem memory item = buyOrders[itemId];
      if (item.amount > 0) {
        require(item.owner == to, "not permit");
        // transfer to msg.sender
        console.log("balance: ", token1.balanceOf(address(this)), item.amount);
        IERC20(token1).transfer(item.owner, item.amount);
      }
      delete buyOrders[itemId];
    } else {
      // 卖单
      OrderItem memory item = sellOrders[itemId];
      if (item.amount > 0) {
        require(item.owner == to, "not permit");
        // transfer to msg.sender
        IERC20(token0).transfer(item.owner, item.amount);
      }
      delete sellOrders[itemId];
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
        uint itemId = items[i];
        OrderItem storage item = sellOrders[itemId];
        console.log(itemId, item.price, item.amount);
        if (item.amount > 0) {
          uint money = item.amount.mul(item.price).div(priceRatio);
          console.log("amount: %d money: %d", amount, money);
          if (amount >= money) {
            // 这个订单全部被买走
            // 买家得到的token0数量
            uint amt0 = money * priceRatio / item.price;
            console.log("amt0: %d total: %d", amt0, total);
            total = total + amt0;
            amount = amount - money;
              // transfer to order book owner
            IERC20(token1).transfer(item.owner, money);
            
            delete sellOrders[itemId];
          } else {
            uint amt0 = amount * priceRatio / item.price;
            total += amt0;
            item.amount -= amt0;
              // transfer to order book owner
            IERC20(token1).transfer(item.owner, amount);
            // transfer to order book owner
            break;
          }
        } else {
          //
          delete sellOrders[itemId];
        }
      }
      if (total > 0) {
        token0.transfer(to, total);
      }
      console.log("buy:", total);
    } else {
      // 卖出 操作的是 buyOrders
      for (uint i = 0; amount > 0 && i < items.length; i ++) {
        //
        uint itemId = items[i];
        OrderItem storage item = buyOrders[itemId];
        if (item.amount > 0) {
          uint q = item.amount * priceRatio / item.price;
          if (amount >= q) {
            uint amt1 = q * item.price / priceRatio;
            amount -= q;
            total = total + amt1;
            IERC20(token0).transfer(item.owner, q);
            delete buyOrders[itemId];
          } else {
            uint amt1 = amount * item.price / priceRatio;
            total += amt1;
            item.amount -= amt1;
            IERC20(token0).transfer(item.owner, amount);
            break;
          }
        } else {
          delete buyOrders[itemId];
        }
      }
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
