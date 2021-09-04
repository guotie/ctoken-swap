const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract, getDefaultProvider } from 'ethers'

import { camtToAmount } from '../helpers/exchangeRate'
import { addressOf, getCTokenContract, getCTokenFactoryContract, getOrderbookContract, getBalance, getOBPriceLogicContract } from '../helpers/contractHelper'

// import { getCreate2Address } from '@ethersproject/address'
// import { pack, keccak256 } from '@ethersproject/solidity'

import { deployTokens, Tokens, getTokenContract, deployOrderBook, zeroAddress } from '../deployments/deploys'
// import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { deployMockContracts } from '../helpers/mock';
import { getMockToken, HTToken, IToken } from '../helpers/token';
import { logHr } from '../helpers/logHr';
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
  let ht = HTToken
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

    console.log('deployer: %s buyer: %s', deployer, buyer.address)

    await deployMockContracts(true)
    // create ctoken
    usdt = await getMockToken('USDT', '100000000000000000000', 6) // tokens.addresses.get('USDT')!
    sea = await getMockToken('SEA', '20000000000000000000000000000000') // tokens.addresses.get('SEA')!

    delegatorFactory = getCTokenFactoryContract(undefined, namedSigners[0]) // await getContractAt(deployContracts.lErc20DelegatorFactory)

    orderBookC = getOrderbookContract(addressOf('OrderBook'), namedSigners[0]) //new ethers.Contract(rr.address, rr.abi, namedSigners[0])
    orderBook = orderBookC.address

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
      gas = gas.mul(2)
      tx = await orderBookC.createOrder(token0.address, token1.address, deployer, amtIn, amtOut, 0, {value: amtIn, gasLimit: gas})
    } else {
      console.log('approve token0 ....', token0.address)
      await token0.contract!.approve(orderBook, BigNumber.from(amtIn).mul(10000))
      // await ctoken0.transfer(orderBook, amtIn)
      let gas: BigNumber
      try {
        gas = await orderBookC.estimateGas.createOrder(token0.address, token1.address, deployer, amtIn, amtOut, 0)
        console.log('estimate gas:', gas.toString())
      } catch(err) {
        console.log('estimate gas failed, set to 6000000')
        gas = BigNumber.from(6000000)
      }

      tx = await orderBookC.createOrder(token0.address, token1.address, deployer, amtIn, amtOut, 0, {gasLimit: gas})
    }

    let receipt = await tx.wait(1)
    // console.log('receipt:', receipt)
    let data = receipt.events[receipt.events.length-1].data
    let orderId = data.slice(0, 66)
    // console.log('event data:', data)
    console.log('put order: ', orderId, BigNumber.from(orderId).toNumber())
    return BigNumber.from(orderId).toNumber()
  }

  const cancelOrder = async (orderId: BigNumberish) => {
    console.log('cancel order:', orderId)
    await orderBookC.cancelOrder(orderId)
  }

  const withdraw = async (token: IToken, amt = 0) => {
    let etoken : string
    if (token.address === zeroAddress) {
      etoken = addressOf('CETH')
    } else {
      etoken = await delegatorFactory.getCTokenAddressPure(token.address)
      if (!etoken) {
          throw new Error('invalid etoken address')
      }
    }

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

  const balanceOf = async (tokenC: IToken, owner: string) => {  
    let amt = await getBalance(tokenC, owner)
    // } else {
    //   amt = await tokenC.contract!.balanceOf(owner)
    // }

    return amt.toString()
  }

  const dealOrders = async (tokenIn: IToken, tokenOut: IToken, orderIds: number[], amts: string[], isToken = true) => {

    if (tokenIn.address == zeroAddress) {
      // await tokenC.transfer(orderBook, {value: amt})
      console.log('token %s, balance: %s', tokenIn.name, )
      // todo
      let total = BigNumber.from(0)
      for (let amt of amts) {
        total = total.add(amt)
      }
      await orderBookC.fulfilOrders(orderIds, amts, deployer, true, true, [], {value: total})
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

    let order = await orderBookC.orders(orderId)
      , tokenAmt = order.tokenAmt

    console.log('deal order %d', orderId.toString())
    if (tokenIn.address == zeroAddress) {
      // await tokenC.transfer(orderBook, {value: amt})
      // console.log('order to take tokenAmt:', tokenAmt)
      console.log('token %s, balance: %s', 'HT', (await getBalance(tokenIn, deployer)).toString())
      let pricec = getOBPriceLogicContract()
      let takerAmt = await pricec.calcTakerAmount(tokenAmt.destToken, tokenAmt.destEToken, tokenAmt.amountOutMint, tokenAmt.guaranteeAmountIn, amt)
      console.log('taker pay amt: ', takerAmt.takerEAmt.toString(), takerAmt.takerAmt.toString())
      await orderBookC.fulfilOrder(orderId, amt, deployer, true, true, [], {value: takerAmt.takerAmt})
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

      console.log('to fulfil order %d, etoken to take: %s', orderId, amt.toString())
      let gas = await orderBookC.estimateGas.fulfilOrder(orderId, amt, deployer, true, true, [])
      console.log('estimate fulfilOrder gas:', gas.toString())
      await orderBookC.fulfilOrder(orderId, amt, deployer, true, true, [], {gasLimit: gas})
      console.log('orderbook balance: %s', tokenIn.name, await balanceOf(tokenIn, deployer))
      console.log('tokenIn %s, balance: %s', tokenIn.name, await balanceOf(tokenIn, deployer))
      console.log('tokenOut %s, balance: %s', tokenIn.name, await balanceOf(tokenOut, deployer))

      let order = await orderBookC.orders(orderId)
      console.log('order status:', order.flag.toHexString(), order.pairAddrIdx.toHexString())
    }
  }

  /*
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

  it('fulfil order, then cancel order', async () => {
    let o1 = await putOrder(usdt, sea, 100000, 300000)

    await dealOrder(sea, usdt, o1, 200)
    // await dealOrder(sea, usdt, o1, 200)
    // await dealOrder(sea, usdt, o1, 600)
    await cancelOrder(o1)
  })
  */

  it('create HT order, then cancel', async () => {
    logHr('create HT order, then cancel')
    let o1 = await putOrder(ht, sea, 100000000, 3000000000)
    await cancelOrder(o1)
  })

  it('fulfil sell HT order, then withdraw', async () => {
    logHr('fulfil sell HT order, then withdraw')
    let o1 = await putOrder(ht, sea, 10000000, 300000000)

    await dealOrder(sea, ht, o1, 20000)
    await withdraw(sea, 0)
  })

  it('fulfil buy HT order, then withdraw', async () => {
    logHr('fulfil buy HT order, then withdraw')
    let o1 = await putOrder(sea, ht, 100000000, 3000000000)

    await dealOrder(ht, sea, o1, 200000)
    await withdraw(ht, 0)
  })

  it('fulfil order, then withdraw', async () => {
    logHr('fulfil order, then withdraw')
    let o1 = await putOrder(usdt, sea, 100000, 300000)

    await dealOrder(sea, usdt, o1, 200)
    await withdraw(sea, 0)
  })

  // it('fulfil order, then withdrawUnderlying', async () => {
  //   let o1 = await putOrder(usdt, sea, 100000, 300000)

  //   await dealOrder(sea, usdt, o1, 200)
  //   // await dealOrder(sea, usdt, o1, 200)
  //   // await dealOrder(sea, usdt, o1, 600)
  //   await withdrawUnderlying(sea, 0)
  // })

  // it('fulfil orders, then withdraw', async () => {
  //   let o1 = await putOrder(usdt, sea, 100000, 300000)
  //   let o2 = await putOrder(usdt, sea, 100000, 300000)

  //   await dealOrders(sea, usdt, [o1, o2], ['200', '200'])
  //   // await dealOrder(sea, usdt, o1, 200)
  //   // await dealOrder(sea, usdt, o1, 600)
  //   await withdraw(sea, 0)
  // })


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
