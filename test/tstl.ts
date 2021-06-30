const { expect } = require("chai");

import { BigNumber, BigNumberish } from 'ethers'
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

  const getBetterOrders = (pair: string, sprice: BigNumberish) => {
    if (false === _orders.has(pair)) {
      return []
    }

    let orders = _orders.get(pair)
      , price = new BigNumberKey(sprice)
      , cursor = orders.upper_bound(price)
      , items: OrderItem[] = []

    if (cursor === orders.end()) {
      cursor = orders.end().prev()
    }

    // 价格优先 时间优先
    for (let iter = orders.begin(); iter !== cursor; iter = iter.next()) {
      for(let order of iter.second) {
        items.push({orderId: order.orderId, amountIn: order.amountIn, fulfiled: order.fulfiled})
      }
    }

    // cursor
    if (cursor.first.less(price) || cursor.first.equals(price)) {
      for(let order of cursor.second) {
        items.push({orderId: order.orderId, amountIn: order.amountIn, fulfiled: order.fulfiled})
      }
    }

    return items
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

    for (let start = orders.begin(); start !== orders.end(); start = start.next()) {
      let items = start.value.second;
      for (let item of items) {
        console.log('orderId:', item.orderId)
      }
    }

    for (let v of [800, 900, 950, 1000, 1200, 1400, 1500, 1600, 1800, 2000, 2500, 3000]) {
      let target = orders.upper_bound(new BigNumberKey(v))
      if (target.equals(orders.end())) {
        console.warn('reach end: ', v);
        continue;
        // break;
      }
      console.log('find %d low_bound:', v, target.value.first.val.toString())
    }

    for (let v of [800, 900, 950, 1000, 1200, 1400, 1500, 1600, 1800, 2000, 2500, 3000]) {
      let items = getBetterOrders(symbol, v)
      let ids = ''
      for (let item of items) {
        ids += item.orderId + ' '
      }
      console.log('orders price less than %d:', v, ids)
    }
    // console.log(orders)
  })
});
