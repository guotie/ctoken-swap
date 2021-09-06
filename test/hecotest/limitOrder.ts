const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract, getDefaultProvider } from 'ethers'

import { camtToAmount } from '../../helpers/exchangeRate'
import { addressOf, getCTokenContract, getCTokenFactoryContract, getOrderbookContract, getBalance } from '../../helpers/contractHelper'

// import { getCreate2Address } from '@ethersproject/address'
// import { pack, keccak256 } from '@ethersproject/solidity'

import { deployTokens, Tokens, getTokenContract, deployOrderBook } from '../../deployments/deploys'
// import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { deployMockContracts } from '../../helpers/mock';
import { getMockToken, HTToken, IToken } from '../../helpers/token';
// import sleep from '../utils/sleep';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

const e18 = BigNumber.from('1000000000000000000')

// let deployContracts: DeployContracts
// 测试 swap pair
describe("orderbook 测试", function() {
  let namedSigners: SignerWithAddress[]

  let deployer: string
  let buyer: SignerWithAddress
  let usdt: IToken
    , sea: IToken
    , htToken = HTToken
  // let cusdt: string
  // let csea: string
  // let usdtC: Contract
  // let seaC: Contract
  let orderBook: string
  let orderBookC: Contract
  let ht = '0x0000000000000000000000000000000000000000'
  let delegatorFactory: Contract
  let buyItems: number[] = []
  let sellItems: number[] = []

  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')
  const e30 = BigNumber.from('1000000000000000000000000000000')

  this.timeout(600000000);

  before(async () => {
    namedSigners = await ethers.getSigners()
    deployer = namedSigners[0].address
    buyer = namedSigners[1]
    // buyer = namedSigners[1]

    // console.log('deployer: %s buyer: %s', deployer, buyer.address)

    // await deployMockContracts()
    // // create ctoken
    // usdt = await getMockToken('USDT', '100000000000000000000', 6) // tokens.addresses.get('USDT')!
    // sea = await getMockToken('SEA', '20000000000000000000000000000000') // tokens.addresses.get('SEA')!

    delegatorFactory = getCTokenFactoryContract(undefined, namedSigners[0]) // await getContractAt(deployContracts.lErc20DelegatorFactory)

    orderBookC = getOrderbookContract(addressOf('OrderBookProxy'), namedSigners[0]) //new ethers.Contract(rr.address, rr.abi, namedSigners[0])
    orderBook = orderBookC.address

    console.info('orderBook %s cETH: %s', orderBook, await orderBookC.cETH())
  })

  it('getOrder', async () => {
    let order = await orderBookC.orders(3)
    console.log('order %d: flag=%s srcToken=%s destToken=%s amountOut=%s expectAmountIn=%s',
        order.orderId.toString(), order.flag.toString(), order.tokenAmt.srcToken, order.tokenAmt.destToken,
        order.tokenAmt.amountOut.toString(), order.tokenAmt.guaranteeAmountIn.toString())
  })

  it('deal order', async () => {
      console.log('buyer address: %s', buyer.address)
  })
})
