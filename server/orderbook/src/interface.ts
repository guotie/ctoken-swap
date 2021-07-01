import { BigNumber, BigNumberish } from "ethers";

/**
 * @description User-Service parameters
 */
export interface IUserOptions {
  uid: string;
}

export interface IGetUserResponse {
  success: boolean;
  message: string;
  data: IUserOptions;
}

export interface ISwapRequest {
  fromTokenAddress: string
  toTokenAddress: string
  amount: string
}


// 返回给定交易对及价格的请求
export interface LimitOrderReq {
  src: string    // 卖出币种
  dest: string   // 买入币种
  amtIn: BigNumberish  // src 的数量
  amtOut: BigNumberish // 预期得到的dest数量
}

// 待成交的订单
export interface OrderToTake {
  amt: BigNumber
  orderId: string
}

// 返回特定价格的订单及成交数量列表
export interface LimitOrderResp {
  orders: OrderToTake[]
}
