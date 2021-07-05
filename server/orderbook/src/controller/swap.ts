import { Controller, Get, Post, Param, Provide, Body, ALL, Inject } from '@midwayjs/decorator';

import { ISwapRequest, ILimitOrderReq } from '../interface'
import { OrderBookService } from '../service/orderBook'

// https://docs.1inch.io/api/quote-swap

@Provide()
@Controller('/v1')
export class SwapController {

  @Inject()
  orderBookService: OrderBookService

  @Post('/swap')
  async swap(@Body(ALL) req: ISwapRequest) {
    return 'Hello Midwayjs!';
  }

  // 查询交易对的所有挂单列表
  @Get('/orderbook/:srcToken/:destToken')
  async orders(@Param('srcToken') srcToken: string, @Param('destToken') destToken: string) {
    return this.orderBookService.getPairOrders(srcToken, destToken)
  }

  // 查询交易对的报价比设定价格更优的挂单列表
  @Post('/getBetterOrders')
  async getBetterOrders(@Body(ALL) cond: ILimitOrderReq) {
    return this.orderBookService.getBetterOrders(cond.src, cond.dest, cond.amtIn, cond.amtOut)
  }
}
