import { Config, Provide } from '@midwayjs/decorator';
import { Contract, ethers } from 'ethers'
import { abi as OneSplitABI } from '../config/abis/OneSplit.json'
import { abi as OrderBookABI } from '../config/abis/OrderBook.json'
import { abi as UnoswapRouterABI } from '../config/abis/UnoswapRouter.json'

@Provide()
export class ContractService {
  @Config('')
  endpoint: string

  contracts: Object = {};

  public async getContractByNameAddress(name: string, addr: string) {
    let provider = new ethers.providers.JsonRpcProvider(this.endpoint)
    if (this.contracts[name]) {
      return this.contracts[name]
    }
    
    let c: Contract
    switch (name) {
      case 'OrderBook':
        c = new Contract(addr, OrderBookABI, provider)
        break;

      case 'OneSplit':
        c = new Contract(addr, OneSplitABI, provider)
        break;

      case 'UnoswapRouter':
        c = new Contract(addr, UnoswapRouterABI, provider)
        break;

      default:
        throw new Error('invalid contract name: ' + name)
    }

    this.contracts[name] = c
    return c;
  }
}
