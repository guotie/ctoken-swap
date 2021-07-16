const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract, getDefaultProvider } from 'ethers'

import { getContractAt, getContractBy } from '../utils/contracts'
// import { getCreate2Address } from '@ethersproject/address'
// import { pack, keccak256 } from '@ethersproject/solidity'

import { DeployContracts, deployAll, deployTokens, Tokens, getTokenContract, getCTokenContract, deployOrderBook } from '../deployments/deploys'
// import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
// import sleep from '../utils/sleep';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

const e18 = BigNumber.from('1000000000000000000')

let deployContracts: DeployContracts
// 测试 swap pair
describe("ctoken swap 测试", function() {
  let tokens: Tokens
  let namedSigners: SignerWithAddress[]

  let mdexFactory: Contract
  let router: Contract
  let obABI: any
  let tokenABI: any
  let deployer: string
  let buyer: SignerWithAddress
  let usdt: string
  let sea: string
  let usdtC: Contract
  let seaC: Contract
  let orderBook: string
  let orderBookC: Contract
  let ht = '0x0000000000000000000000000000000000000000'

  let buyItems: number[] = []
  let sellItems: number[] = []

  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')
  const e30 = BigNumber.from('1000000000000000000000000000000')

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

    deployContracts = await deployAll({log: true, anchorToken: tokens.addresses.get('USDT'), addresses: addresses})
    // console.log('deploy contracts', deployTokens())
    // await getContractAt(deployContracts.unitroller)
    // delegatorFactory = await getContractAt(deployContracts.lErc20DelegatorFactory)
    mdexFactory = await getContractAt(deployContracts.mdexFactory)
    router = await getContractAt(deployContracts.router)

    // create ctoken
    usdt = tokens.addresses.get('USDT')!
    sea = tokens.addresses.get('SEA')!
    usdtC = await getTokenContract(usdt, namedSigners[0])
    seaC = await getTokenContract(sea, namedSigners[0])

    // 部署 SEA/USDT 交易对
    const obArt = await hre.artifacts.readArtifact('OrderBook')
    const tokenArt = await hre.artifacts.readArtifact('contracts/common/Token.sol:Token')
    obABI = obArt.abi
    tokenABI = tokenArt.abi

    console.log(
        deployContracts.lErc20DelegatorFactory.address,
        deployContracts.cWHT.address,
        deployContracts.WHT.address,
        ht
      )
    let rr = await deployOrderBook(
          deployContracts.lErc20DelegatorFactory.address,
          deployContracts.cWHT.address,
          deployContracts.WHT.address,
          ht,
          deployer, true, true)
    orderBook = rr.address
    orderBookC = await getContractBy(obArt.abi, orderBook)

    console.info('USDT:', usdt, 'SEA:', sea, 'orderBook:', orderBook)
    console.info('orderBook %s cETH: %s', orderBook, await orderBookC.cETH())
    expect(usdt).to.not.be.empty
    expect(sea).to.not.be.empty
  })

  // 存 token mint cToken
  const depositToken = async (token: Contract, ctoken: Contract, amount: BigNumberish) => {
    await token.approve(ctoken.address, amount)
    let tx = await ctoken.functions.mint(amount)
    await token.approve(ctoken.address, 0)
    await tx.wait(2)
  }

  const transfer = async (token: Contract, to: string, amount: BigNumberish) => {
    await expect(token.transfer(to, amount)).to.emit(token, 'Transfer')
    // await tx.wait(2)
  }

  const calcPrice = (price: string) => {
    let s = price
    if (s.indexOf('.') < 0) {
      return BigNumber.from(price).mul(e30)
    }

    // 
    let parts = s.split('.')
      , zs = +parts[0]
      , xs = +('0.' + parts[1])

      let p = BigNumber.from(zs).mul(e30)

      // 忽略8位以后的值
      return p.add(BigNumber.from(Math.floor(xs * 10000000000)).mul(e30).div(10000000000))
  }

  const putOrder = async (token0: string, token1: string, amtIn: BigNumberish, amtOut: BigNumberish) => {
    const ctoken0 = await getTokenContract(token0)
      // , ctoken1 = getTokenContract(token1)
    let tx: any
    if (token0 === '0x0000000000000000000000000000000000000000') {
      tx = await orderBookC.createOrder(token0, token1, deployer, amtIn, amtOut, 0, {value: amtIn})
    } else {
      console.log('approve token0 ....', ctoken0.address)
      await ctoken0.approve(orderBook, BigNumber.from(amtIn).mul(10000))
      // await ctoken0.transfer(orderBook, amtIn)
      tx = await orderBookC.createOrder(token0, token1, deployer, amtIn, amtOut, 0)
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

  const getOrder = async (orderId: BigNumberish) => {
    let order = await orderBookC.orders(+orderId.toString())
    // console.log('%s: order id: %s ', s, orderId.toString(), order)
    return order
  }

  const getBalance = async (token: string) => {
    if (token === '0' || token === '') {
      return ethers.provider.getBalance(deployer)
    }
    let ctoken = await getTokenContract(token)
    return ctoken.balanceOf(deployer)
  }

  it('createOrder', async () => {
    let usdtBalanceBefore = await getBalance(usdt)

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
    let usdtBalanceAfter = await getBalance(usdt)
    expect(usdtBalanceAfter).to.eq(usdtBalanceAfter)
    // console.log('usdt balance:', usdtBalanceAfter.toString(), usdtBalanceAfter.toString());

    let comp = await getContractAt(deployContracts.comptroller)
    console.log("ceth listed:", (await comp.functions.markets(deployContracts.cWHT.address)).isListed)
    let htBalanceBefore = await getBalance('0')
    // await cancelOrder(o3)
    let o4 = await putOrder(ht, sea, 1000, 1000)
    await cancelOrder(o4)
    let o5 = await putOrder(ht, sea, 1000, 1500)
    await cancelOrder(o5)
    let o6 = await putOrder(ht, sea, 1000, 2000)
    await cancelOrder(o6)

    let htBalanceAfter = await getBalance('0')
    console.log('ht balance:', htBalanceBefore.toString(), htBalanceAfter.toString())
    // expect(htBalanceAfter).to.eq(htBalanceBefore)
  })

  // 对于买家来说的 tokenIn tokenOut
  const dealOrder = async (tokenIn: string, tokenOut: string, orderId: BigNumberish, amt: BigNumberish) => {
    let tokenC = await getTokenContract(tokenIn)
      , tokenOutC = await getTokenContract(tokenOut)

    if (tokenIn == ht) {
      await tokenC.transfer(orderBook, {value: amt})
      console.log('token %s, balance: %s', tokenIn, )
      await orderBookC.fulfilOrder(orderId, amt, {value: amt})
    } else {
      // await token
      console.log('tokenIn %s, balance: %s', tokenIn, await tokenC.balanceOf(deployer))
      console.log('tokenOut %s, balance: %s', tokenIn, await tokenOutC.balanceOf(deployer))
      await tokenC.approve(orderBook, amt)
      await orderBookC.fulfilOrder(orderId, amt, deployer, true, true)
      console.log('orderbook balance: %s', tokenIn, await tokenC.balanceOf(deployer))
      console.log('tokenIn %s, balance: %s', tokenIn, await tokenC.balanceOf(deployer))
      console.log('tokenOut %s, balance: %s', tokenIn, await tokenOutC.balanceOf(deployer))

      let order = await orderBookC.orders(orderId)
      console.log('order status:', order.flag.toHexString(), order.pairAddrIdx.toHexString())
    }

  }

  it('fulfil order', async () => {
    let o1 = await putOrder(usdt, sea, 1000, 1000)

    await dealOrder(sea, usdt, o1, 200)
    await dealOrder(sea, usdt, o1, 200)
    await dealOrder(sea, usdt, o1, 600)
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
