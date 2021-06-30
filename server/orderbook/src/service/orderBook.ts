import { Config, Init, Inject, Provide } from '@midwayjs/decorator';
import { BigNumber, BigNumberish, Contract } from 'ethers';
import { ContractService } from './contract';
import std, { HashMap, TreeMap } from "tstl";
import BigNumberKey from '../utils/BigNumberKey';

// uint orderId;
// uint pairAddrIdx;        // pairIdx | addrIdx
// address owner;
// address to;              // 兑换得到的token发送地址 未使用
// uint pair;               // hash(srcToken, destToken)
// uint timestamp;          // 过期时间 | 挂单时间 
// uint flag;
// TokenAmount tokenAmt;
interface OrderItem {
  orderId: string
  // pairAddrIdx: number
  owner: string
  to: string
  pair: string
  timestamp: BigNumber
  expiredAt: BigNumber
  flag: string
  // TokenAmount
  srcToken: string
  destToken: string
  amountIn: BigNumber
  fulfiled: BigNumber
  guaranteeAmountOut: BigNumber
}

@Provide()
export class OrderBookService {
  @Config('OrderBookAddr')
  addr: string

  @Inject()
  contractService: ContractService

  E18 = BigNumber.from('1000000000000000000')
  MaskTimestamp = BigNumber.from('0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff')
  MaskExpiredAt = BigNumber.from('0xffffffffffffffffffffffffffffffff00000000000000000000000000000000')

  obCt: Contract;
  // key: srcToken-destToken
  _orders: HashMap<string, TreeMap<BigNumberKey, std.List<OrderItem>>>;

  @Init()
  async init() {
    this.obCt = await this.contractService.getContractByNameAddress('OrderBook', this.addr)
    this._orders = new HashMap()

    this.onContractEvents()
  }

  // 监听合约的事件并处理
  onContractEvents() {
    // 创建订单
    this.obCt.on('CreateOrder', (owner, srcToken, destToken, orderId, amtIn, amtOut, flag) => {
      console.log('found CreateOrder:', owner, srcToken, destToken, orderId)
      this.onCreateOrder(owner, srcToken, destToken, orderId, amtIn, amtOut, flag)
    })

    // 成交
    this.obCt.on('FulFilOrder', async (maker, taker, orderId, amt, amtOut, remaining) => {
      console.log('found FulFilOrder:', maker, taker, orderId, amt, amtOut, remaining)
      await this.onFulfilOrder(maker, taker, orderId, amt, amtOut, remaining)
    })

    // 取消订单
    this.obCt.on('CancelOrder', async (owner, src, dest, orderId) => {
      console.log('found CancelOrder:', owner, orderId)
      await this.onCancelOrder(owner, src, dest, orderId)
    })
  }

  async getContract() {
    if (!this.obCt) {
      throw new Error('contract OrderBook is null')
    }
    return this.obCt
  }

  // 新建订单
  onCreateOrder(owner: string, srcToken: string, destToken: string, orderId: BigNumber, amtIn: BigNumber, amtOut: BigNumber, flag: BigNumber) {
    let pair = this.pairFor(srcToken, destToken)
      , price = this.price(amtIn, amtOut)
      , ts = BigNumber.from(Math.floor(new Date().getTime()/1000))
      , order = {
        orderId: orderId.toString(),
        // pairAddrIdx: number
        owner: owner,
        to: owner,
        pair: pair,
        timestamp: this.getTimestamp(ts),
        expiredAt: this.getExpiredAt(ts),
        flag: flag.toString(),
        // TokenAmount
        srcToken: srcToken,
        destToken: destToken,
        amountIn: amtIn,
        fulfiled: BigNumber.from(0),
        guaranteeAmountOut: amtOut
      }
    
    this._insertOrder(pair, BigNumberKey.from(price), order)
  }

  async onFulfilOrder(maker: string, taker: string, orderId: BigNumber, amt: BigNumber, amtOut: BigNumber, remaining: BigNumber) {
    let order = await this.getOrderById(orderId.toString())
    let pair = this.pairFor(order.srcToken, order.destToken)

    this._updateOrder(pair, this.price(order.amountIn, order.guaranteeAmountOut), order)
  }

  async onCancelOrder(owner: string, src: string, dest: string, orderId: BigNumber) {
    let pair = this.pairFor(src, dest)
    //: 根据 orderId 查找 order
    let order = await this.getOrderById(orderId.toString())

    this._removeOrder(pair, this.price(order.amountIn, order.guaranteeAmountOut), orderId.toString())
  }

  // 订单是否已经取消, 如果订单被取消, 最后一位被置为1
  _orderClosed(flag: BigNumber): boolean {
    return flag.and(1).eq(1)
  }

  async getOrderById(orderId: string): Promise<OrderItem> {
    let o = await this.obCt.orders(orderId)
      , src = o.tokenAmt.srcToken
      , dst = o.tokenAmt.destToken
      , amtIn = o.tokenAmt.amountIn
      , fulfiled = o.tokenAmt.fulfiled
      , amtOut = o.tokenAmt.guaranteeAmountOut

    if (o.owner === '0x0000000000000000000000000000000000000000') {
      // todo 如果是 000000 zero address 说明订单不存在
      console.warn('orderId %s has invalid zero owner, ignore it', orderId)
      throw new Error('orderId not exist')
    }

    return {
      orderId: orderId,
      // pairAddrIdx: number
      owner: o.owner,
      to: o.to,
      pair: this.pairFor(src, dst),
      timestamp: this.getTimestamp(o.timestamp),
      expiredAt: this.getExpiredAt(o.timestamp),
      flag: o.flag.toString(),
      // TokenAmount
      srcToken: src,
      destToken: dst,
      amountIn: amtIn,
      fulfiled: fulfiled,
      guaranteeAmountOut: amtOut
    }
  }

  async initOrderBook() {
    let orders = await this.getAllOrders();
    
    for (let order of orders) {
      // 订单
      let pair = this.pairFor(order.srcToken, order.destToken)
        , price = this.price(order.amountIn, order.guaranteeAmountOut)
        , key = new BigNumberKey(price)

      this._insertOrder(pair, key, order)
    }
  }

  async getAllOrders() {
    let c = await this.getContract()
    let resp = await c.getAllOrders()

    // console.log('getAllOrders resp:', resp)
    //
    let orders: OrderItem[] = []

    for (let o of resp) {
      let src = o.tokenAmt.srcToken
      , dst = o.tokenAmt.destToken
      , amtIn = o.tokenAmt.amountIn
      , fulfiled = o.tokenAmt.fulfiled
      , guaranteeAmountOut = o.tokenAmt.guaranteeAmountOut
      , flag: BigNumber = o.flag
      , orderId = o.orderId.toString()
      , pair = this.pairFor(src, dst)
      // , price = this.price(amtIn, guaranteeAmountOut)

      let order: OrderItem = {
        orderId: orderId,
        // pairAddrIdx: number
        owner: o.owner,
        to: o.to,
        pair: pair,
        timestamp: this.getTimestamp(o.timestamp),
        expiredAt: this.getExpiredAt(o.timestamp),
        flag: flag.toString(),
        // TokenAmount
        srcToken: src,
        destToken: dst,
        amountIn: amtIn,
        fulfiled: fulfiled,
        guaranteeAmountOut: guaranteeAmountOut
      }

      orders.push(order)

      // this._insertOrder(pair, price, order)
    }

    return orders
  }

  // 成交
  _updateOrder(pair: string, price: BigNumber, order: OrderItem) {
    if (!this._orders.has(pair)) {
      console.warn('_updateOrder: not found pair orders: %s', pair)
      return
    }

    let tm = this._orders.get(pair)
      , key = new BigNumberKey(price)

    if (!tm.has(key)) {
      console.warn('_removeOrder: not found price %s', key.val.toString())
      return
    }
    let items = tm.get(key)
    for (let item = items.begin(); item != items.end(); item = item.next()) {
      if (item.value.orderId === order.orderId) {
        console.info('_updateOrder: update pair %s orderId: %s', pair, order.orderId)
        // 其他值都不会变化
        item.value.fulfiled = order.fulfiled
        item.value.flag = order.flag
        return
      }
    }
    console.warn('_updateOrder: not found pair %s orderId: %s', pair, order.orderId)
  }
  
  // 撤单 取消订单
  _removeOrder(pair: string, price: BigNumber, orderId: string) {
    if (!this._orders.has(pair)) {
      console.warn('_removeOrder: not found pair orders: %s', pair)
      return
    }

    let tm = this._orders.get(pair)
      , key = new BigNumberKey(price)

    if (!tm.has(key)) {
      console.warn('_removeOrder: not found price %s', key.val.toString())
      return
    }
    let items = tm.get(key)
    for (let item = items.begin(); item != items.end(); item = item.next()) {
      if (item.value.orderId === orderId) {
        items.remove(item.value)
        console.info('_removeOrder: remove pair %s orderId: %s', pair, orderId)
        return
      }
    }
    console.warn('_removeOrder: not found pair %s orderId: %s', pair, orderId)
  }

  // 挂单 创建订单
  _insertOrder(pair: string, price: BigNumberKey, order: OrderItem) {
      if (this._orders.has(pair)) {
        let tm = this._orders.get(pair)
          // 同一价格的订单列表
          , items: std.List<OrderItem>
        if (tm.has(price)) {
          items = tm.get(price)
        } else {
          items = new std.List<OrderItem>()
          tm.insert_or_assign(price, items)
        }
        items.push_back(order)
      } else {
        let tm = new TreeMap<BigNumberKey, std.List<OrderItem>>();
        let items = new std.List<OrderItem>()
        items.push_back(order)
        tm.insert_or_assign(price, items)
        this._orders.insert_or_assign(pair, tm)
      }
  }
    // return orders

  getTimestamp(ts: BigNumber): BigNumber {
    return ts.and(this.MaskTimestamp)
  }

  getExpiredAt(ts: BigNumber): BigNumber {
    return ts.and(this.MaskExpiredAt).shr(160)
  }

  price(amtIn: BigNumber, amtOut: BigNumber): BigNumber {
    // return amtIn.mul(this.E18).div(amtOut)
    return amtOut.mul(this.E18).div(amtIn)
  }

  // 根据token获取交易对key
  pairFor(src: string, dest: string) {
    return src + '-' + dest
  }

  // 获取交易对的订单列表，区分顺序, a/b 与 b/a 是不同的交易对
  //
  // src: 源token, 将要卖出的币
  // dest: 目标token, 得到的币对
  // amtIn: src 数量, 卖出的币的数量
  // amtOut: dest 数量, 买入的币的数量
  async getPairOrders(src: string, dest: string) {
    let pair = this.pairFor(src, dest)

    // just for test
    await this.initOrderBook()

    if (!this._orders.has(pair)) {
      return []
    }

    let tree = this._orders.get(pair)
    let orders = new std.List()

    for (let start = tree.begin(); start !== tree.end(); start = start.next()) {
      let items = start.value.second;

      for (let item = items.begin(); item !== items.end(); item = item.next()) {
        orders.push(item.value)
      }
    }

    return orders
  }

  cloneOrder(item: OrderItem): OrderItem {
    return {
      orderId: item.orderId,
      owner: item.owner,
      to: item.to,
      pair: item.pair,
      timestamp: item.timestamp,
      expiredAt: item.timestamp,
      flag: item.flag,
      // TokenAmount
      srcToken: item.srcToken,
      destToken: item.destToken,
      amountIn: item.amountIn,
      fulfiled: item.fulfiled,
      guaranteeAmountOut: item.guaranteeAmountOut
    }
  }

  // 获取更优的价格的订单列表
  //
  // src: 源token
  // dest: 目标token
  // amtIn: src 数量
  // amtOut: dest 数量
  //
  // 寻找卖出src, 买入dest的挂单列表, 且价格 < amtOut/amtIn
  async getBetterOrders(src: string, dest: string, amtIn: BigNumberish, amtOut: BigNumberish) {
    let price = new BigNumberKey(this.price(BigNumber.from(amtIn), BigNumber.from(amtOut)))
      , pair = this.pairFor(src, dest)
    
    if (!this._orders.has(pair)) {
      console.warn('not found pair:', pair)
      return []
    }

    let orders = this._orders.get(pair)
      , cursor = orders.upper_bound(price)  // 找到大于该价格的最近的节点
      , items: OrderItem[] = []
    
    if (cursor === orders.end()) {
        cursor = orders.end().prev()
    }
    // 价格优先 时间优先
    for (let iter = orders.begin(); iter !== cursor; iter = iter.next()) {
      for(let order of iter.second) {
        items.push(this.cloneOrder(order))
      }
    }

    // cursor
    if (cursor.first.less(price) || cursor.first.equals(price)) {
      for(let order of cursor.second) {
        items.push(this.cloneOrder(order))
      }
    }

    return items
  }
}
