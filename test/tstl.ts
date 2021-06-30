const { expect } = require("chai");

import { BigNumber } from 'ethers'
import std, { TreeMap } from "tstl";
import BigNumberKey from '../server/orderbook/src/utils/BigNumberKey'

interface OrderItem {
  orderId: string
  amountIn: BigNumber
  fulfiled: BigNumber
}

// 测试 swap pair
describe("tstl", function() {

  let _orders: std.HashMap<string, std.TreeMap<BigNumberKey, std.List<OrderItem>>> = new std.HashMap();

  const _insertOrder = (pair: string, price: BigNumberKey, order: OrderItem) => {
    if (_orders.has(pair)) {
      let tm = _orders.get(pair)
        // 同一价格的订单列表
        , items: std.List<OrderItem>
      if (tm.has(price)) {
        items = tm.get(price)
      } else {
        console.log('  price %s not exist, create it', price.val.toString())

        items = new std.List<OrderItem>()
        tm.insert_or_assign(price, items)
      }

      items.push_back(order)
    } else {
      console.log('pair %s not exist, create it', pair)
      let tm = new TreeMap<BigNumberKey, std.List<OrderItem>>();
      let items = new std.List<OrderItem>()
      items.push_back(order)
      tm.insert_or_assign(price, items)
      _orders.insert_or_assign(pair, tm)
    }
  }

  it('insertOrder', () => {
    let symbol = 'eth/usdt'
      , p1000 = new BigNumberKey('1000')
      , p1500 = new BigNumberKey(1500)
      , p2000 = new BigNumberKey(2000)
      , p900 = new BigNumberKey(900)

    _insertOrder(symbol, p1500, {orderId: '4', amountIn: BigNumber.from(4000), fulfiled: BigNumber.from(0)})
    _insertOrder(symbol, p1000, {orderId: '1', amountIn: BigNumber.from(1000), fulfiled: BigNumber.from(0)})
    _insertOrder(symbol, p1000, {orderId: '2', amountIn: BigNumber.from(2000), fulfiled: BigNumber.from(0)})
    _insertOrder(symbol, p900, {orderId: '7', amountIn: BigNumber.from(7000), fulfiled: BigNumber.from(0)})
    _insertOrder(symbol, p2000, {orderId: '5', amountIn: BigNumber.from(5000), fulfiled: BigNumber.from(0)})
    _insertOrder(symbol, p2000, {orderId: '6', amountIn: BigNumber.from(6000), fulfiled: BigNumber.from(0)})
    _insertOrder(symbol, p1000, {orderId: '3', amountIn: BigNumber.from(3000), fulfiled: BigNumber.from(0)})
    _insertOrder(symbol, p900, {orderId: '8', amountIn: BigNumber.from(8000), fulfiled: BigNumber.from(0)})
    _insertOrder(symbol, p900, {orderId: '9', amountIn: BigNumber.from(9000), fulfiled: BigNumber.from(0)})

    let orders = _orders.get(symbol)

    for (let start = orders.begin(); start != orders.end(); start = start.next()) {
      let items = start.value.second;
      for (let item of items) {
        console.log('orderId:', item.orderId)
      }
    }
    // console.log(orders)
  })
});
