const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'


import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { addressOf, getBalance, getBalances, getCTokenFactoryContract, getEbankFactory, getEbankPair, getEbankRouter, getEbeTokenContract, getSwapExchangeRateContract, getTokenContract } from '../helpers/contractHelper'
import { IToken, getMockToken, HTToken, readableTokenAmount, deadlineTs, getPairToken } from '../helpers/token';
import { callWithEstimateGas } from '../helpers/estimateGas';
import { deployMockContracts } from '../helpers/mock';
import { getCTokenContract } from '../deployments/deploys';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

// 测试 swap router
describe("Router 测试", function() {
    // let deployContracts: DeployContracts
    let namedSigners: SignerWithAddress[]
    // let unitroller: Contract
    let ctokenFactory: Contract
        , router: Contract
        , factory: Contract
        , ebec: Contract
        , swapHelper: Contract

    let maker: SignerWithAddress
        , taker: SignerWithAddress
        , feeTo: string

    let usdt: IToken
        , sea: IToken
        , wht: IToken
        , eusdt: IToken
        , eSea: IToken
        , eWht: IToken
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
        ctokenFactory = getCTokenFactoryContract(addressOf('CtokenFactory'), maker)
        router = getEbankRouter(undefined, maker)
        swapHelper = getSwapExchangeRateContract()

        // let cfactory = await router.ctokenFactory()
        factory = getEbankFactory(undefined, maker)
        feeTo = namedSigners[2].address
        await factory.setFeeTo(feeTo)

        usdt = await getMockToken('USDT')
        sea = await getMockToken('SEA')
        wht = await getMockToken('WHT')

        let ebe = addressOf('EBEToken')
        ebec = getEbeTokenContract(undefined, namedSigners[0])
        await router.setRewardToken(ebe)
        await router.setEbePerBlock(BigNumber.from(10).mul(e18))
        // 这里切换手续费方式 0 或者 1
        await router.setFeeAlloc(0)

        console.info('contracts: router=%s factory=%s', router.address, factory.address)
    })

    const printBalance = async (title: string, owner: string, tokens: IToken[]) => {
        console.info(title)
        let balances = await getBalances(tokens, owner)
        for (let i = 0; i < tokens.length; i ++) {
            let token = tokens[i]
            console.info('    %s balance: %s', token.name, balances[i].toString())
        }
    }

    const addLiquidityETH = async (t1: IToken, amt0: BigNumberish, amt1: BigNumberish) => {
        await printBalance('Balance ' + maker.address + ' before add liquidity', maker.address, [ht, t1])
        // await t0.contract!.approve(router.address, amt0)
        await t1.contract!.approve(router.address, amt1)
        let tx = await router.addLiquidityETHUnderlying(t1.address, amt1, 0, 0, maker.address, deadlineTs(100), {gasLimit: 6000000, value: amt0})

        await tx.wait(0)
        let pair = await factory.pairFor(wht.address, t1.address)
            , pairToken = await getPairToken(pair)
        await printBalance('Balance ' + maker.address + ' after add liquidity', maker.address, [ht, t1, pairToken])
    }

    const addLiquidity = async (t0: IToken, t1: IToken, amt0: BigNumberish, amt1: BigNumberish) => {
        await printBalance('Balance ' + maker.address + ' before add liquidity', maker.address, [t0, t1])
        await t0.contract!.approve(router.address, amt0)
        await t1.contract!.approve(router.address, amt1)
        let tx = await callWithEstimateGas(
                router,
                'addLiquidityUnderlying',
                [
                    t0.address,
                    t1.address,
                    amt0,
                    amt1,
                    0,
                    0,
                    maker.address,
                    deadlineTs(100)
                ],
                true
            )
        // console.log('tx:', tx)
        await tx.wait(0)
        let pair = await factory.pairFor(t0.address, t1.address)
            , pairToken = await getPairToken(pair)
        await printBalance('Balance ' + maker.address + ' after add liquidity', maker.address, [t0, t1, pairToken])
    }

    // 计算最小输出
    const getAmountOutMin = async (amtIn: BigNumberish, path: string[], to: string) => {
        const factory = addressOf('Factory')
            , ctokenFactory = addressOf('CtokenFactory')
        const { amountOut } = await swapHelper.getAmountsOutUnderlying(factory, ctokenFactory, amtIn, path, to)
        return amountOut
    }

    it('add Liquidity underlying: usdt/sea', async () => {
        let amt0 = readableTokenAmount(usdt, 10)
            , amt1 = readableTokenAmount(sea, 2000)
        await addLiquidity(usdt, sea, amt0, amt1)

        amt0 = readableTokenAmount(usdt, 20)
        amt1 = readableTokenAmount(sea, 4000)
        await addLiquidity(usdt, sea, amt0, amt1)
        
        let cusdt = await ctokenFactory.getCTokenAddressPure(usdt.address)
            , usdtc = await getCTokenContract(cusdt, maker)
        console.log('cusdt:', cusdt)
        eusdt = {
            name: "eUSDT",
            symbol: "eUSDT",
            decimals: 18,
            totalSupply: BigNumber.from(0),
            address: cusdt,
            contract: usdtc
        }
    })

    it('add Liquidity underlying: ht/sea', async () => {
        let amt0 = readableTokenAmount(ht, 1)
            , amt1 = readableTokenAmount(sea, 500)
        await addLiquidityETH(sea, amt0, amt1)

        amt0 = readableTokenAmount(ht, 2)
        amt1 = readableTokenAmount(sea, 1000)
        await addLiquidityETH(sea, amt0, amt1)
    })

    it('add Liquidity underlying: ht/usdt', async () => {
        let amt0 = readableTokenAmount(ht, 2)
            , amt1 = readableTokenAmount(usdt, 5)
        await addLiquidityETH(usdt, amt0, amt1)

        amt0 = readableTokenAmount(ht, 2)
        amt1 = readableTokenAmount(usdt, 5)
        await addLiquidityETH(usdt, amt0, amt1)
    })

    it('swap usdt->sea', async () => {
        let usdtC = getTokenContract(usdt.address, taker)
            , routerC = getEbankRouter(undefined, taker)
            , amt =  readableTokenAmount(usdt, 1)
            , amtIn = readableTokenAmount(usdt, 1)
            , path = [usdt.address, sea.address]
            , b0 = await getBalance(sea, taker.address)
            , min = await getAmountOutMin(amtIn, path, taker.address)

        await usdt.contract!.transfer(taker.address, amt)
        await usdtC.approve(routerC.address, amt)
        await routerC.swapExactTokensForTokensUnderlying(
                            amtIn,
                            min,
                            path,
                            taker.address,
                            deadlineTs(60)
                        )
        let b1 = await getBalance(sea, taker.address)
        expect(b1.sub(b0).gte(min)).to.be.ok // , "amtOut less than amountOutMin")
        await printBalance('Balance feeTo after swap usdt->sea', feeTo, [eusdt])
    })

    it('swap sea->usdt', async () => {
        let amt =  readableTokenAmount(sea, 100)
        await sea.contract!.transfer(taker.address, amt)

        let seaC = getTokenContract(sea.address, taker)
            , routerC = getEbankRouter(undefined, taker)
            , path = [sea.address, usdt.address]
            , amtOutMin = await getAmountOutMin(amt, path, taker.address)

        await seaC.approve(routerC.address, amt)
        await routerC.swapExactTokensForTokensUnderlying(
                            amt,
                            amtOutMin,
                            path,
                            taker.address,
                            deadlineTs(60)
                        )
        await printBalance('Balance feeTo after swap sea->usdt', feeTo, [eusdt])
    })

    it('swap ht->sea', async () => {
        let amt =  e18.div(10)

        await printBalance('HT Balance taker ', taker.address, [ht])
        let routerC = getEbankRouter(undefined, taker)
        await routerC.swapExactETHForTokensUnderlying(
                            0,
                            [wht.address, sea.address],
                            taker.address,
                            deadlineTs(60),
                            {value: amt}
                        )
        await printBalance('Balance feeTo after swap ht->sea', feeTo, [eusdt])
    })

    it('swap ht->sea->usdt', async () => {
        let amt =  e18.div(10)

        await printBalance('HT Balance taker ', taker.address, [ht])
        let routerC = getEbankRouter(undefined, taker)
        await routerC.swapExactETHForTokensUnderlying(
                            0,
                            [wht.address, sea.address, usdt.address],
                            taker.address,
                            deadlineTs(60),
                            {value: amt}
                        )
        await printBalance('Balance feeTo after swap ht->sea->usdt', feeTo, [eusdt])
    })

    it('swap sea->ht', async () => {
        let amt =  readableTokenAmount(sea, 100)
        await sea.contract!.transfer(taker.address, amt)

        let seaC = getTokenContract(sea.address, taker)
            , routerC = getEbankRouter(undefined, taker)

        await seaC.approve(routerC.address, amt)
        await routerC.swapExactTokensForETHUnderlying(
                            amt,
                            0,
                            [sea.address, wht.address],
                            taker.address,
                            deadlineTs(60)
                        )
        await printBalance('Balance feeTo after swap sea->usdt', feeTo, [eusdt])
    })

    it('swap sea->ht->usdt', async () => {
        let amt =  readableTokenAmount(sea, 100)
        await sea.contract!.transfer(taker.address, amt)

        let seaC = getTokenContract(sea.address, taker)
            , routerC = getEbankRouter(undefined, taker)

        await seaC.approve(routerC.address, amt)
        await routerC.swapExactTokensForETHUnderlying(
                            amt,
                            0,
                            [sea.address, wht.address],
                            taker.address,
                            deadlineTs(60)
                        )
        await printBalance('Balance feeTo after swap sea->usdt', feeTo, [eusdt])
    })

    const removeLiquidityUnderlying = async (tokenA: IToken, tokenB: IToken, signer: SignerWithAddress) => {
        let routerc = getEbankRouter(undefined, signer)
            , pair = await router.pairFor(tokenA.address, tokenB.address)
            , pairc = getEbankPair(pair, signer)
            , liq = await pairc.balanceOf(signer.address)
            , lpReward = await pairc.mintRewardOf(signer.address)
            , toRemoved = liq.sub(0)

        console.log('before removeLiquidityUnderlying: pair %s owner %s liquidity %s toRemoved: %s LPReward %s %s %s',
            pair, signer.address, liq.toString(),
            toRemoved.toString(),
            lpReward.amount.toString(), lpReward.pendingReward.toString(), lpReward.rewardDebt.toString())
        await pairc.approve(routerc.address, '1000000000000000000000000000')
        await routerc.removeLiquidityUnderlying(usdt.address, sea.address, toRemoved, 0, 0, signer.address, deadlineTs(100))
        liq = await pairc.balanceOf(signer.address)
        lpReward = await pairc.mintRewardOf(signer.address)
        console.log('after removeLiquidityUnderlying: liquidity %s LPReward %s %s %s', liq.toString(),
            lpReward.amount.toString(), lpReward.pendingReward.toString(), lpReward.rewardDebt.toString())
    }

    it('removeLiquidity', async ()=> {
        logHr('remove liquidity')
        await removeLiquidityUnderlying(usdt, sea, maker)
    })
})

