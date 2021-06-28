import { Provide } from '@midwayjs/decorator';
import { BigNumber, BigNumberish, Contract } from 'ethers';
import { ContractService } from './contract';
import std from "tstl";


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
  pairAddrIdx: number
  owner: string
  to: string
  pair: string
  timestamp: string
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
  addr: string
  obCt: Contract;
  orders: std.HashMap<string, std.TreeMap<BigNumber, OrderItem>>;

  constructor(addr: string) {
    this.addr = addr;
    this.orders = new std.HashMap();
  }

  async getContract() {
    if (!this.obCt) {
      this.obCt = await ContractService.getContractByNameAddress('OrderBook', this.addr)
    }
    return this.obCt
  }

  async initOrderBook() {
    let c = await this.getContract()
    let orders = await c.getAllOrders()
  }

  // 获取更优的价格的订单列表
  //
  // src: 源token
  // dest: 目标token
  // amtIn: src 数量
  // amtOut: dest 数量
  async getBetterOrders(src: string, dest: string, amtIn: BigNumberish, amtOut: BigNumberish) {

  }
}
