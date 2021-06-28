import { Provide } from '@midwayjs/decorator';
import { Contract } from 'ethers'
import { abi as OneSplitABI } from '../config/abis/OneSplit.json'
import { abi as OrderBookABI } from '../config/abis/OrderBook.json'
import { abi as UnoswapRouterABI } from '../config/abis/UnoswapRouter.json'

@Provide()
export class ContractService {
  static contracts: Object = {};

  public static async getContractByNameAddress(name: string, addr: string) {
    if (this.contracts[name]) {
      return this.contracts[name]
    }
    
    let c: Contract
    switch (name) {
      case 'OrderBook':
        c = new Contract(addr, OrderBookABI)
        break;

      case 'OneSplit':
        c = new Contract(addr, OneSplitABI)
        break;

      case 'UnoswapRouter':
        c = new Contract(addr, UnoswapRouterABI)
        break;

      default:
        throw new Error('invalid contract name: ' + name)
    }

    this.contracts[name] = c
    return c;
  }
}
