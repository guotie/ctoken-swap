const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'

import { getContractAt, getContractBy } from '../utils/contracts'
// import { getCreate2Address } from '@ethersproject/address'
// import { pack, keccak256 } from '@ethersproject/solidity'

import { DeployContracts, deployAll, deployTokens, Tokens, getTokenContract, getCTokenContract, deployStablePair } from '../deployments/deploys'
import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
// import sleep from '../utils/sleep';
const hre = require('hardhat')
const ethers = hre.ethers
// const network = hre.network

const e18 = BigNumber.from('100000000000000000')

// 测试 swap pair
describe("stable coin 测试", function() {
  let deployer: string
  let usdt: string
  let dai: string
  let stable: string
  let usdtC: Contract
  let daiC: Contract
  let stableC: Contract
  let mintAmt0: BigNumberish
  let mintAmt1: BigNumberish
  let mintAmt2: BigNumberish
  let mintAmt3: BigNumberish

  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')

  before(async () => {
    const namedSigners = await ethers.getSigners()
    deployer = namedSigners[0].address
    // buyer = namedSigners[1]

    console.log('deployer: %s buyer: %s', deployer, deployer)

    let result = await deployStablePair()

    usdt = result.usdt.address
    usdtC = result.usdtC
    dai = result.dai.address
    daiC = result.daiC
    stable = result.stable.address
    stableC = result.stableC
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

  // mint 流动性代币
  const swapMint = async (amt0: BigNumberish, amt1: BigNumberish) => {
    await transfer(usdtC, stable, amt0)
    await transfer(daiC, stable, amt1)

    const tx = await stableC.addLiquidity()
    const receipt = await tx.wait(2)
    const mintAmt = receipt.logs[0].data
    console.log('mint:', BigNumber.from(mintAmt).toString())

    return mintAmt
  }

  const deadlineTs = (second: number) => {
    return (new Date()).getTime() + second * 1000
  }


  const swapToken = async (_amt0: BigNumberish, _amt1: BigNumberish, minAmt0: BigNumberish, minAmt1: BigNumberish) => {
    const amt0 = BigNumber.from(_amt0).mul(1000000)
    const amt1 = BigNumber.from(_amt1).mul(e18)

    if (amt0.gt(0)) {
      await transfer(usdtC, stable, amt0)
    }
    if (amt1.gt(0)) {
      await transfer(daiC, stable, amt1)
    }
    await stableC.swap(minAmt0, minAmt1, deployer)
  }

  const removeLiquidity = async (amt: BigNumberish) => {
    await transfer(stableC, stable, amt)
    await stableC.removeLiquidity(deployer)
  }

  it('router-mint', async () => {
    const amt0 =  BigNumber.from('100000').mul(1000000) // usdt
    const amt1 =  BigNumber.from('102000').mul(e18) // dai

    // await depositToken(usdtc, cusdtCt, mintAmt)
    // await depositToken(seac, cseaCt, mintAmt)
    
    mintAmt0 = await swapMint(amt0, amt1)
    mintAmt1 = await swapMint(amt0.mul(10), amt1.mul(10))
    mintAmt2 = await swapMint(amt0.mul(3), amt1.mul(3))
    mintAmt3 = await swapMint(amt0.mul(2), amt1.mul(2))
  })

  it('exchange', async () => {
    await swapToken('10', 0, 0, 0)
    await swapToken(0, '10', 0, 0)
  })

  it('burn', async () => {
    await removeLiquidity(mintAmt0)
    await removeLiquidity(mintAmt1)
    await removeLiquidity(mintAmt2)
    await removeLiquidity(mintAmt3)
  })

  // it('swapExactTokensForTokens', async () => {

  //   const usdtc = await getTokenContract(usdt)
  //   , cusdtCt = await getCTokenContract(cusdt)
  //   , seac = await getTokenContract(sea)
  //   , cseaCt = await getCTokenContract(csea)
  //   , mintAmt = '4000000000000000'

  //   await depositToken(usdtc, cusdtCt, mintAmt)

  //   // const er = await cusdtCt.exchangeRateStored()
  //   let balBefore = await cseaCt.balanceOf(deployer)
  //   let amtIn = await toCAmount(cusdtCt, mintAmt)
  //   await swapExactTokensForTokens(usdt, sea, amtIn)
  //   let balAfter = await cseaCt.balanceOf(deployer)
  //   console.log('swap out csea:', balBefore.toString(), balAfter.toString())
  // })

  // it('swapTokensForExactTokens', async () => {

  //   const usdtc = await getTokenContract(usdt)
  //   , cusdtCt = await getCTokenContract(cusdt)
  //   , seac = await getTokenContract(sea)
  //   , cseaCt = await getCTokenContract(csea)
  //   , mintAmt = '5000000000000000'

  //   await depositToken(usdtc, cusdtCt, mintAmt)

  //   // const er = await cusdtCt.exchangeRateStored()
  //   let balBefore = await cseaCt.balanceOf(deployer)
  //   let amtIn = await toCAmount(cusdtCt, mintAmt)
  //   await swapTokensForExactTokens(usdt, sea, '100000000000000')
  //   let balAfter = await cseaCt.balanceOf(deployer)
  //   console.log('swap out csea:', balBefore.toString(), balAfter.toString())
  // })

  // it('token->ctoken', async () => {
  //   const cusdtCt = await getCTokenContract(cusdt)
  //     , cseaCt = await getCTokenContract(csea)

  //   const erCusdt = await cusdtCt.exchangeRateStored()
  //     , erCsea = await cseaCt.exchangeRateStored()
  //   console.log(erCusdt)
  //   console.log('exchage rate cusdt: %s sea: %s', erCusdt.toString(), erCsea.toString())
  // })

  // it('swap-swap', async () => {
  //   // transfer usdt to buyer

  //   console.log('buyer:', buyer.address)
  //   await swapSwap()
  // })

});
