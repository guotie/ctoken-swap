const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract, getDefaultProvider } from 'ethers'

import { getContractAt, getContractBy } from '../utils/contracts'
import { camtToAmount } from '../helpers/exchangeRate'
import { addressOf, getCTokenContract, getCTokenFactoryContract, getEbankRouter, getBalance } from '../helpers/contractHelper'

// import { getCreate2Address } from '@ethersproject/address'
// import { pack, keccak256 } from '@ethersproject/solidity'

import { deployTokens, Tokens, getTokenContract, deployOrderBook } from '../deployments/deploys'
// import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { deployMockContracts } from '../helpers/mock';
import { getMockToken, HTToken, IToken } from '../helpers/token';
// import sleep from '../utils/sleep';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

const e18 = BigNumber.from('1000000000000000000')

// let deployContracts: DeployContracts
// 测试 swap pair
describe("orderbook 测试", function() {
  let tokens: Tokens
  let namedSigners: SignerWithAddress[]

  let mdexFactory: Contract
  let router: Contract
  let obABI: any
  let tokenABI: any
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

  this.timeout(60000000);

  before(async () => {
    namedSigners = await ethers.getSigners()
    deployer = namedSigners[0].address
    buyer = namedSigners[1]

    console.log('deployer: %s buyer: %s', deployer, buyer.address)

    tokens = await deployTokens()
    let addresses: string[] = []
    for (let key of tokens.addresses.keys()) {
      addresses.push(tokens.addresses.get(key)!)
    }

    // deployContracts = await deployAll({log: true, anchorToken: tokens.addresses.get('USDT'), addresses: addresses}, true)
    await deployMockContracts()
    // console.log('deploy contracts', deployTokens())
    // await getContractAt(deployContracts.unitroller)
    // delegatorFactory = await getContractAt(deployContracts.lErc20DelegatorFactory)
    router = getEbankRouter(undefined, namedSigners[0]) // getContractAt(deployContracts.mdexFactory)
    // router = await getContractAt(deployContracts.router)

    // create ctoken
    usdt = await getMockToken('USDT', '100000000000000000000', 6) // tokens.addresses.get('USDT')!
    sea = await getMockToken('SEA', '20000000000000000000000000000000') // tokens.addresses.get('SEA')!
    // usdtC = await getTokenContract(usdt, namedSigners[0])
    // seaC = await getTokenContract(sea, namedSigners[0])
    // const delegatorFactoryContract = await getCon
    delegatorFactory = getCTokenFactoryContract(undefined, namedSigners[0]) // await getContractAt(deployContracts.lErc20DelegatorFactory)
    // cusdt = await delegatorFactory.getCTokenAddressPure(usdt)
    // console.log('cusdt address:', cusdt)
    // csea = await delegatorFactory.getCTokenAddressPure(sea)
    // console.log('csea address:', csea)

    // 部署 SEA/USDT 交易对
    const obArt = await hre.artifacts.readArtifact('OrderBook')
    const tokenArt = await hre.artifacts.readArtifact('contracts/common/Token.sol:Token')
    obABI = obArt.abi
    tokenABI = tokenArt.abi

    // console.log(
    //     deployContracts.lErc20DelegatorFactory.address,
    //     deployContracts.cWHT.address,
    //     deployContracts.WHT.address,
    //     ht
    //   )
    let rr = await deployOrderBook(
      delegatorFactory.address,
          addressOf('CETH'),
          addressOf('WHT'),
          ht,
          true, true)
    orderBook = rr.address
    orderBookC = await getContractBy(obArt.abi, orderBook)

    console.info('USDT:', usdt.address, 'SEA:', sea.address, 'orderBook:', orderBook)
    console.info('orderBook %s cETH: %s', orderBook, await orderBookC.cETH())
    expect(usdt).to.not.be.empty
    expect(sea).to.not.be.empty
  })


  const putOrder = async (token0: IToken, token1: IToken, amtIn: BigNumberish, amtOut: BigNumberish) => {
    // const ctoken0 = await getTokenContract(token0)
      // , ctoken1 = getTokenContract(token1)
    let tx: any
    if (token0.address === '0x0000000000000000000000000000000000000000') {
      let gas = await orderBookC.estimateGas.createOrder(token0.address, token1.address, deployer, amtIn, amtOut, 0, {value: amtIn})
      console.log('estimate ht gas:', gas.toString())
      tx = await orderBookC.createOrder(token0.address, token1.address, deployer, amtIn, amtOut, 0, {value: amtIn, gasLimit: gas})
    } else {
      console.log('approve token0 ....', token0.address)
      await token0.contract!.approve(orderBook, BigNumber.from(amtIn).mul(10000))
      // await ctoken0.transfer(orderBook, amtIn)
      let gas = await orderBookC.estimateGas.createOrder(token0.address, token1.address, deployer, amtIn, amtOut, 0)
      console.log('estimate gas:', gas.toString())
      tx = await orderBookC.createOrder(token0.address, token1.address, deployer, amtIn, amtOut, 0, {gasLimit: gas})
    }

    let receipt = await tx.wait(1)
    // console.log('receipt:', receipt)
    let data = receipt.events[receipt.events.length-1].data
    let orderId = data.slice(0, 66)
    // console.log('event data:', data)
    console.log('put order:', orderId, BigNumber.from(orderId).toNumber())
    return BigNumber.from(orderId).toNumber()
  }

  const cancelOrder = async (orderId: BigNumberish) => {
    console.log('cancel order:', orderId)
    await orderBookC.cancelOrder(orderId)
  }

  const withdraw = async (token: IToken, amt = 0) => {
    let etoken = await delegatorFactory.getCTokenAddressPure(token.address)
    await orderBookC.withdraw(etoken, amt)
  }

  const withdrawUnderlying = async (token: IToken, amt = 0) => {
    await orderBookC.withdrawUnderlying(token.address, amt)
  }

  const getOrder = async (orderId: BigNumberish) => {
    let order = await orderBookC.orders(+orderId.toString())
    // console.log('%s: order id: %s ', s, orderId.toString(), order)
    return order
  }

  // const getBalance = async (token: IToken) => {
  //   getBalance
  //   if (token === '0' || token === '') {
  //     return ethers.provider.getBalance(deployer)
  //   }
  //   let ctoken = await getTokenContract(token)
  //   return ctoken.balanceOf(deployer)
  // }

  it('createOrder', async () => {
    let owner = namedSigners[0].address
    let usdtBalanceBefore = await getBalance(usdt, owner)

    let o1 = await putOrder(usdt, sea, 1000, 1000)
    let order1 = await getOrder(o1)
    console.log('order1 flag:', order1.flag.toHexString(), order1.pairAddrIdx.toHexString())
    // console.log('order1:', order1)
    let o2 = await putOrder(usdt, sea, 1000, 2000)
    let order2 = await getOrder(o2)
    console.log('order2 flag:', order2.flag.toHexString(), order2.pairAddrIdx.toHexString())

    let o3 = await putOrder(usdt, sea, 1000, 1500)
    let order3 = await getOrder(o3)
    console.log('order3 flag:', order3.flag.toHexString(), order3.pairAddrIdx.toHexString())

    await cancelOrder(o1)
    order2 = await getOrder(o2)
    console.log('after cancel order1, order2 flag:', order2.flag.toHexString(), order2.pairAddrIdx.toHexString())
    order3 = await getOrder(o3)
    console.log('after cancel order1, order3 flag:', order3.flag.toHexString(), order3.pairAddrIdx.toHexString())

    await cancelOrder(o2)
    order3 = await getOrder(o3)
    console.log('after cancel order1 & order2, order3 flag:', order3.flag.toHexString(), order3.pairAddrIdx.toHexString())
    await cancelOrder(o3)
    order1 = await getOrder(o1)
    console.log('after cancel, order1:', order1.flag.toHexString())

    // 比较 usdt 是否已经退回
    let usdtBalanceAfter = await getBalance(usdt, owner)
    expect(usdtBalanceAfter).to.eq(usdtBalanceAfter)
    // console.log('usdt balance:', usdtBalanceAfter.toString(), usdtBalanceAfter.toString());

    // let comp = await getContractAt(deployContracts.comptroller)
    // console.log("ceth listed:", (await comp.functions.markets(deployContracts.cWHT.address)).isListed)
    let htBalanceBefore = await getBalance(htToken, owner)
    // await cancelOrder(o3)
    let o4 = await putOrder(htToken, sea, 1000, 1000)
    await cancelOrder(o4)
    let o5 = await putOrder(htToken, sea, 1000, 1500)
    await cancelOrder(o5)
    let o6 = await putOrder(htToken, sea, 1000, 2000)
    await cancelOrder(o6)

    let htBalanceAfter = await getBalance(htToken, owner)
    console.log('ht balance:', htBalanceBefore.toString(), htBalanceAfter.toString())
    // expect(htBalanceAfter).to.eq(htBalanceBefore)
  })

  const balanceOf = async (tokenC: IToken, owner: string) => {
    let amt = await tokenC.contract!.balanceOf(owner)
    return amt.toString()
  }

  const dealOrders = async (tokenIn: IToken, tokenOut: IToken, orderIds: number[], amts: string[], isToken = true) => {

    if (tokenIn.address == ht) {
      // await tokenC.transfer(orderBook, {value: amt})
      console.log('token %s, balance: %s', tokenIn.name, )
      // todo 
      await orderBookC.fulfilOrders(orderIds, amts, deployer, true, true, [], {value: 0})
    } else {
      let namt: BigNumber
      namt = BigNumber.from('100000000000000000000000000000000')
      // await token
      console.log('tokenIn %s, balance: %s', tokenIn.name, await balanceOf(tokenIn, deployer))
      console.log('tokenOut %s, balance: %s', tokenOut.name, await balanceOf(tokenOut, deployer))
      console.log('aprrove %s', tokenIn.name, namt.toString())
      await tokenIn.contract!.approve(orderBook, namt)

      let gas = await orderBookC.estimateGas.fulfilOrders(orderIds, amts, deployer, true, true, [])
      console.log('estimate gas:', gas.toString())
      await orderBookC.fulfilOrders(orderIds, amts, deployer, true, true, [], {gasLimit: gas})
      console.log('orderbook balance: %s', tokenIn.name, await balanceOf(tokenIn, deployer))
      console.log('tokenIn %s, balance: %s', tokenIn.name, await balanceOf(tokenIn, deployer))
      console.log('tokenOut %s, balance: %s', tokenIn.name, await balanceOf(tokenOut, deployer))

      // let order = await orderBookC.orders(orderId)
      // console.log('order status:', order.flag.toHexString(), order.pairAddrIdx.toHexString())
    }
  }

  // 对于买家来说的 tokenIn tokenOut
  const dealOrder = async (tokenIn: IToken, tokenOut: IToken, orderId: BigNumberish, amt: BigNumberish, isToken = true) => {
    // let tokenC = await getTokenContract(tokenIn)
    //   , tokenOutC = await getTokenContract(tokenOut)

    if (tokenIn.address == ht) {
      // await tokenC.transfer(orderBook, {value: amt})
      console.log('token %s, balance: %s', tokenIn, )
      await orderBookC.fulfilOrder(orderId, amt, deployer, true, true, [], {value: amt})
    } else {
      let namt: BigNumber
      if (isToken) {
        // console.log('tokenIn %s, balance: %s', tokenIn, await balanceOf(tokenC, deployer))
        let ctokenIn = await delegatorFactory.getCTokenAddressPure(tokenIn.address)
        console.log('ctoken: %s', ctokenIn)
        let ctokenInC = getCTokenContract(ctokenIn, namedSigners[0])
        namt = await camtToAmount(ctokenInC, amt)
      } else {
        namt = BigNumber.from(amt)
      }
      namt = BigNumber.from('100000000000000000000000000000000')
      // await token
      console.log('tokenIn %s, balance: %s', tokenIn.name, await balanceOf(tokenIn, deployer))
      console.log('tokenOut %s, balance: %s', tokenOut.name, await balanceOf(tokenOut, deployer))
      console.log('aprrove %s', tokenIn.name, namt.toString())
      await tokenIn.contract!.approve(orderBook, namt)

      let gas = await orderBookC.estimateGas.fulfilOrder(orderId, amt, deployer, true, true, [])
      console.log('estimate gas:', gas.toString())
      await orderBookC.fulfilOrder(orderId, amt, deployer, true, true, [], {gasLimit: gas})
      console.log('orderbook balance: %s', tokenIn.name, await balanceOf(tokenIn, deployer))
      console.log('tokenIn %s, balance: %s', tokenIn.name, await balanceOf(tokenIn, deployer))
      console.log('tokenOut %s, balance: %s', tokenIn.name, await balanceOf(tokenOut, deployer))

      let order = await orderBookC.orders(orderId)
      console.log('order status:', order.flag.toHexString(), order.pairAddrIdx.toHexString())
    }
  }

  it('fulfil order, then cancel order', async () => {
    let o1 = await putOrder(usdt, sea, 100000, 300000)

    await dealOrder(sea, usdt, o1, 200)
    // await dealOrder(sea, usdt, o1, 200)
    // await dealOrder(sea, usdt, o1, 600)
    await cancelOrder(o1)
  })

  it('fulfil order, then withdraw', async () => {
    let o1 = await putOrder(usdt, sea, 100000, 300000)

    await dealOrder(sea, usdt, o1, 200)
    // await dealOrder(sea, usdt, o1, 200)
    // await dealOrder(sea, usdt, o1, 600)
    await withdraw(sea, 0)
  })

  it('fulfil order, then withdrawUnderlying', async () => {
    let o1 = await putOrder(usdt, sea, 100000, 300000)

    await dealOrder(sea, usdt, o1, 200)
    // await dealOrder(sea, usdt, o1, 200)
    // await dealOrder(sea, usdt, o1, 600)
    await withdrawUnderlying(sea, 0)
  })

  it('fulfil orders, then withdraw', async () => {
    let o1 = await putOrder(usdt, sea, 100000, 300000)
    let o2 = await putOrder(usdt, sea, 100000, 300000)

    await dealOrders(sea, usdt, [o1, o2], ['200', '200'])
    // await dealOrder(sea, usdt, o1, 200)
    // await dealOrder(sea, usdt, o1, 600)
    await withdraw(sea, 0)
  })


  // it('cancelOrder', async () => {
  //   for (let i of buyItems) {
  //     console.log('cancel buy order:', i)
  //     await orderBookC.cancelOrder(0, i, deployer)
  //   }
  //   for (let i of sellItems) {
  //     console.log('cancel sell order:', i)
  //     await orderBookC.cancelOrder(1, i, deployer)
  //   }
  // })


  // it('buy', async () => {
  //   await transfer(usdtC, buyer.address, 100000000)
    
  //   let usdtCB = await ethers.getContractAt(tokenABI, usdt, buyer)
  //   let obBuyer = await ethers.getContractAt(obABI, orderBook, buyer)

  //   console.log('before buy: usdt of deployer:', (await usdtC.balanceOf(deployer)).toString());
  //   await transfer(usdtCB, orderBook, 542)
  //   await obBuyer.dealOrders(0, 542, [8, 9], buyer.address)

  //   console.log('after buy: usdt of deployer:', (await usdtC.balanceOf(deployer)).toString());
  //   console.log('after buy: usdt balance of buyer:', (await usdtC.balanceOf(buyer.address)).toString())
  //   console.log('after buy: sea balance of buyer:', (await seaC.balanceOf(buyer.address)).toString())
  // })

  // it('sell', async () => {
  //   await transfer(seaC, buyer.address, 100000000)
    
  //   let seaCB = await ethers.getContractAt(tokenABI, sea, buyer)
  //   let obBuyer = await ethers.getContractAt(obABI, orderBook, buyer)

  //   console.log('before buy: usdt of deployer:', (await usdtC.balanceOf(deployer)).toString());
  //   await transfer(seaCB, orderBook, 532)
  //   await obBuyer.dealOrders(1, 532, [1,2,3], buyer.address)

  //   console.log('after buy: usdt of deployer:', (await usdtC.balanceOf(deployer)).toString());
  //   console.log('after buy: usdt balance of buyer:', (await usdtC.balanceOf(buyer.address)).toString())
  //   console.log('after buy: sea balance of buyer:', (await seaC.balanceOf(buyer.address)).toString())
  // })
});
