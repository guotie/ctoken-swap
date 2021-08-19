const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { addressOf, getBalance, getBalances, getCTokenFactoryContract, getEbankFactory, getEbankRouter, getEbeTokenContract, getSwapExchangeRateContract, getTokenContract } from '../helpers/contractHelper'
import { IToken, getMockToken, HTToken, readableTokenAmount, deadlineTs, getPairToken, printBalance, getMockTokenWithSigner } from '../helpers/token';
import { callWithEstimateGas } from '../helpers/estimateGas';
import { deployMockContracts } from '../helpers/mock';
import { addLiquidity, swapExactTokensForTokens } from '../helpers/liquidity';
import { getCTokenContract } from '../deployments/deploys';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

// 测试 swap router
describe("LP 手续费挖平台币 测试", function() {
    // let deployContracts: DeployContracts
    let namedSigners: SignerWithAddress[]
    // let unitroller: Contract
    let ctokenFactory: Contract
        , router: Contract
        , factory: Contract
        , ebec: Contract
        , swapRate: Contract

    let maker: SignerWithAddress
        , taker: SignerWithAddress
        , feeTo: string
        , receiver: string

    let usdt: IToken
        , sea: IToken
        , shib: IToken
        , wht: IToken
        , ht = HTToken

    const logHr = (s: string) => console.log('--------------------------  ' + s + '  --------------------------')
  
    // e18 是 18位数
    const e18 = BigNumber.from('1000000000000000000')
    
    this.timeout(60000000);
  
    before(async () => {
        if (network.name === 'hecotest') {
            // throw new Error('should test in hecotest')
            console.info('network hecotest ....')
        } else if (network.name === 'hardhat') {
            // deploy all contracts here
            await deployMockContracts()
        } else {
            throw new Error('invalid network: ' + network.name)
        }

        let namedSigners = await ethers.getSigners()
        maker = namedSigners[0]
        taker = namedSigners[1]
        feeTo = namedSigners[2].address
        receiver = namedSigners[3].address

        console.log('    maker: %s\n    taker: %s\n    feeTo: %s\n    receiver: %s',
            maker.address, taker.address, feeTo, receiver)

        ctokenFactory = getCTokenFactoryContract(addressOf('CtokenFactory'), maker)
        router = getEbankRouter(undefined, maker)
        console.info('router factory:', await router.factory())
        // let cfactory = await router.ctokenFactory()
        factory = getEbankFactory(undefined, maker)
        swapRate = getSwapExchangeRateContract(undefined, maker)

        await factory.setFeeTo(feeTo)

        usdt = await getMockToken('USDT')
        sea = await getMockToken('SEA')
        wht = await getMockToken('WHT')
        shib = await getMockToken('SHIB')

        // 设置 router 平台币
        let ebe = addressOf('EBEToken')
        ebec = getEbeTokenContract(undefined, namedSigners[0])
        await router.setRewardToken(ebe)
        await router.setEbePerBlock(BigNumber.from(10).mul(e18))
        await router.setFeeAlloc(1)

        console.info('contracts: router=%s factory=%s', router.address, factory.address)

        await makerLP()
    })

    // maker 提供 LP
    const makerLP = async () => {
        let amt0 = readableTokenAmount(usdt, 100)
            , amt1 = readableTokenAmount(sea, 200)

        await addLiquidity(router, usdt, sea, amt0, amt1, maker.address)
        await addLiquidity(router, usdt, sea, amt0, amt1, maker.address)
        await addLiquidity(router, usdt, shib, readableTokenAmount(usdt, 200), readableTokenAmount(shib, 500), maker.address)
    }

    const doSwap = async (taker: SignerWithAddress, from: string, to: string, amtIn: BigNumber) => {
        const fromToken = await getMockTokenWithSigner(from.toUpperCase(), taker)
            , toToken = await getMockTokenWithSigner(to.toUpperCase(), taker)
            , router = getEbankRouter(undefined, taker)

        await swapExactTokensForTokens(router, fromToken, toToken, amtIn, taker.address)
    }

    it('交易手续费', async () => {
        logHr('交易手续费')
        let amt = readableTokenAmount(usdt, 2)
        await usdt.contract!.transfer(taker.address, amt)
        await doSwap(taker, 'USDT', 'SEA', amt)

        // 再次增加流动性
        let seaAmt = await swapRate.getAmountsOutUnderlying(factory.address, ctokenFactory.address, amt, [usdt.address, sea.address], maker.address)
        console.log('getAmountsOutUnderlying sea: %s', seaAmt.toString())
    })

    it('ExchangeRate', async () => {
        let cusdt = await ctokenFactory.getCTokenAddressPure(usdt.address)
        console.log('cusdt: ', cusdt)
        let rate = await swapRate.getCurrentExchangeRate(cusdt)
        console.log('usdt exchange rate:', rate.toString())
    })

    it('LP withdraw EBE', async () => {

    })

    it('transfer LP', async () => {
        let pair = await factory.pairFor(usdt.address, sea.address)
            , pairc = await getPairToken(pair, maker)
            , balance = await getBalance(pairc, maker.address)
        console.log('pair: %s balance: %s', pair, balance.toString())
        await pairc.contract!.transfer(taker.address, balance)

        let ebeBal = await ebec.balanceOf(maker.address)
        console.log('after transfer, maker EBE: %s pairs current fee: %s', ebeBal.toString(), (await pairc.contract!.currentFee()).toString())
    })
})
