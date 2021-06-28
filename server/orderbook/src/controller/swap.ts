import { Controller, Post, Provide, Body, ALL } from '@midwayjs/decorator';

import { ISwapRequest } from '../interface'
// https://docs.1inch.io/api/quote-swap

@Provide()
@Controller('/v1')
export class SwapController {
  @Post('/swap')
  async swap(@Body(ALL) req: ISwapRequest) {
    return 'Hello Midwayjs!';
  }

  // 查询交易对的买卖订单列表
  @Post('/orderbook')
  async orderBook() {

  }
}
