const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'

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

const e18 = BigNumber.from('100000000000000000')

// 测试 swap pair
describe("ctoken swap 测试", function() {
  let tokens: Tokens
  let deployContracts: DeployContracts
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

    let rr = await deployOrderBook(router.address, sea, usdt, deployer, true, true)
    orderBook = rr.address
    orderBookC = await getContractBy(obArt.abi, orderBook)

    console.info('USDT:', usdt, 'SEA:', sea, 'orderBook:', orderBook)
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

  const putOrder = async (dir: number, price: string, amt: BigNumberish) => {
    console.log('put order:', dir, price, amt.toString())
    if (dir === 0) {
      // console.log('transfer: ', seaC.address, amt.toString())
      //
      await transfer(usdtC, orderBook, amt)
    } else {
      await transfer(seaC, orderBook, amt)
    }

    let p = calcPrice(price)
    let tx = await orderBookC.putOrder(dir, p, amt, deployer)
    let receipt = await tx.wait()
      , logs = receipt.logs
      , data = logs[0].data.slice(0, 66)
    expect(logs.length == 1)

    let orderId = BigNumber.from(data).toNumber()
    console.log('order itemId:', orderId)
    if (dir === 0) {
      buyItems.push(orderId)
    } else {
      sellItems.push(orderId)
    }
    return orderId
  }

  it('putBuyOrder', async () => {
    await putOrder(0, '0.1324', 10000)
    await putOrder(0, '0.11234345', 11000)
    await putOrder(0, '0.19483', 21000)
    await putOrder(0, '0.023', 23000)
    await putOrder(0, '1.05', 1000500)
    await putOrder(0, '2.078', 1000500)
    await putOrder(0, '21.3595', 210500)
    
  })

  it('putSellOrder', async () => {
    // await putOrder(1, '0.1193483', 10000)
    await putOrder(1, '0.023132', 23000) // 8
    await putOrder(1, '1.051238', 1000500)
    await putOrder(1, '2.07811909', 1000500)
    await putOrder(1, '21.35951', 210500)
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

  it('sell', async () => {

  })

  it('cancelOrder', async () => {
    
  })

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

  it('sell', async () => {
    await transfer(seaC, buyer.address, 100000000)
    
    let seaCB = await ethers.getContractAt(tokenABI, sea, buyer)
    let obBuyer = await ethers.getContractAt(obABI, orderBook, buyer)

    console.log('before buy: usdt of deployer:', (await usdtC.balanceOf(deployer)).toString());
    await transfer(seaCB, orderBook, 532)
    await obBuyer.dealOrders(1, 532, [1,2,3], buyer.address)

    console.log('after buy: usdt of deployer:', (await usdtC.balanceOf(deployer)).toString());
    console.log('after buy: usdt balance of buyer:', (await usdtC.balanceOf(buyer.address)).toString())
    console.log('after buy: sea balance of buyer:', (await seaC.balanceOf(buyer.address)).toString())
  })
});
