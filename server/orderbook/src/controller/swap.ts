import { Controller, Get, Post, Param, Provide, Body, ALL, Inject } from '@midwayjs/decorator';

import { ISwapRequest } from '../interface'
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

  // 查询交易对的买卖订单列表
  @Get('/orderbook/:srcToken/:destToken')
  async orders(@Param('srcToken') srcToken: string, @Param('destToken') destToken: string) {
    return this.orderBookService.getPairOrders(srcToken, destToken)
  }

  // 查询交易对的买卖订单列表
  @Post('/orderbook')
  async orderBook() {

  }
}
