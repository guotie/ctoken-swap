const { expect } = require("chai");
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, Contract } from 'ethers'
import { getEbankFactory, getEbankRouter, getCTokenFactoryContract, getSwapExchangeRateContract, addressOf, getCTokenContract, getTokenContract, getBalance, getEbankPair } from '../helpers/contractHelper';
import { deployMockContracts, addLiquidityUnderlying } from '../helpers/mock';
import { getCTokenRate } from '../helpers/exchangeRate'
import { deadlineTs, getMockToken, HTToken, IToken } from '../helpers/token';
import { logHr } from '../helpers/logHr';

// 测试 swap pair
describe("swap ht 测试", function() {
  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')
  let fc: Contract
    , rc: Contract
    , hc: Contract
    , ctokenFc: Contract
    , owner: SignerWithAddress
    , ht = HTToken

  before(async () => {
        const namedSigners = await hre.ethers.getSigners()
        owner = namedSigners[0]
        if (hre.network.name === 'hardhat') {
            await deployMockContracts(true)
            // let usdt = await getMockToken('USDT', '10000000000000000000000', 6)
            //   , router = getEbankRouter(undefined, owner)
            // await addLiquidityUnderlying(router, ht, usdt, 1, 10, owner.address)
        }

        fc = getEbankFactory(undefined, owner)
        rc = getEbankRouter(undefined, owner)
        hc = getSwapExchangeRateContract(undefined, owner)
        ctokenFc = getCTokenFactoryContract(undefined, owner)
  })

  it('add liquidity', async () => {
    logHr('add liquidity')
    let usdt = await getMockToken('USDT', '10000000000000000000000', 6)
      , router = getEbankRouter(undefined, owner)
      , wht = addressOf('WETH')
      , usdtBalance = await getBalance(usdt, owner.address)
    console.log('before addLiquidity, usdt balance of owner: %s', usdtBalance.toString())
      // , paric = getEbankPair(pair)
    await addLiquidityUnderlying(router, ht, usdt, 1, 10, owner.address)
    let pair = await router.pairFor(wht, usdt.address)
      , balance = await getBalance(pair, owner.address)
    console.log('pair LP ht/usdt %s balance of owner: %s', pair, balance.toString())
  })

  it('exchange rate', async () => {
    let usdt = addressOf('USDT') // 0x04f535663110a392a6504839beed34e019fdb4e0
    let eusdt = await ctokenFc.getCTokenAddressPure(usdt)
    let eusdtc = getCTokenContract(eusdt)
    let rate = await getCTokenRate(eusdtc)
    console.log('exchange rate usdt: %s', rate.toString())
  })

  it('getAmountOutMin', async ()=> {
      let amtIn = BigNumber.from(e18).div(10)
        , wht = addressOf('WHT')   // 0x7af326b6351c8a9b8fb8cd205cbe11d4ac5fa836
        , usdt = addressOf('USDT') // 0x04f535663110a392a6504839beed34e019fdb4e0
        , eusdt = await ctokenFc.getCTokenAddressPure(usdt)
        , feeRate = 30

        let { amounts, amountOut } = await hc.getAmountsOutUnderlying(fc.address, ctokenFc.address, amtIn, [wht, usdt], owner.address)
        console.log('amtOut: %s amounts: %s %s', amountOut.toString(), amounts[0].toString(), amounts[1].toString())

        let rateA = await hc.getCurrentExchangeRate(addressOf('CETH'))
          , rateB = await hc.getCurrentExchangeRate(eusdt)
          , camtIn = amtIn.mul(e18).div(rateA)
        console.log('rate wht: %s rate USDT: %s', rateA.toString(), rateB.toString())

        let {reserveA, reserveB} = await fc.getReserves(wht, usdt)
        console.log('pair wht/usdt reserves: %s %s', reserveA.toString(), reserveB.toString())

        let out1 = await fc.getAmountOutFeeRate(camtIn, reserveA, reserveB, feeRate)
            , out2 = await fc.getAmountOutFeeRateAnchorToken(camtIn, reserveA, reserveB, feeRate)

        console.log('out1: %s out2: %s', out1.toString(), out2.toString())

        let routerc = getEbankRouter(undefined, owner)
          , b0 = await getBalance(usdt, owner.address)
        await (await routerc.swapExactETHForTokensUnderlying(amountOut, [wht, usdt], owner.address, deadlineTs(100), {value: amtIn})).wait()
        let b1 = await getBalance(usdt, owner.address)

        console.log('swap wht->usdt: %s -> %s', amtIn.toString(), b1.sub(b0).toString())
  })

  it('remove liquidity', async () => {
    let router = getEbankRouter(undefined, owner)
      , usdt = await getMockToken('USDT', '10000000000000000000000', 6)
      , wht = addressOf('WETH')
      , pair = await router.pairFor(wht, usdt.address)
      , pairc = await getEbankPair(pair, owner)

    let balance = await getBalance(pair, owner.address)
      , usdtBalance = await getBalance(usdt, owner.address)
    console.log('pair address:', pair)
    console.log('before removeLiquidity, usdt balance of owner: %s', usdtBalance.toString())
    
    await pairc.approve(router.address, balance)
    await router.removeLiquidityETHUnderlying(usdt.address, balance, 0, 0, owner.address, deadlineTs(100))

    balance = await getBalance(pair, owner.address)
    usdtBalance = await getBalance(usdt, owner.address)
    console.log('after   removeLiquidity, usdt balance of owmer: %s', usdtBalance.toString())
    console.log('after   removeLiquidity, pair ht/usdt balance of owmer: %s', balance.toString())
  })
})
