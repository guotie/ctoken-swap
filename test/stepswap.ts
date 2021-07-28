const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'
import { getContractAt, getContractBy } from '../utils/contracts'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { AbiCoder } from 'ethers/lib/utils';
import { assert } from 'console';

import { DeployContracts, deployAll, deployTokens, Tokens, zeroAddress, deployStepSwap } from '../deployments/deploys'
import { logHr } from '../helpers/logHr'
import createCToken from './shared/ctoken'
import { setNetwork, getContractByAddressABI, getContractByAddressName, getTokenContract, getCTokenContract } from '../helpers/contractHelper'
import { findBestDistribution, calcExchangeListSwap, buildAggressiveSwapTx } from '../helpers/aggressive';

const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network
const ht = zeroAddress

setNetwork(network.name)

const e18 = BigNumber.from('100000000000000000')

interface Swap {
    fa: string   // factory address
    fc?: Contract // factory contract
    ra: string   // router address
    rc?: Contract // router contract
}

// 测试 swap pair
describe("聚合交易测试", function() {

    let tokens: Tokens
    let deployContracts: DeployContracts
    let namedSigners: SignerWithAddress[]
    let unitroller: Contract
    let delegatorFactory: Contract
    let mdexFactory: Contract
    let router: Contract
    // let pairABI: any
    let deployer: string
    let buyer: SignerWithAddress

    let usdt: string
        , sea: string
        , doge: string
        , cusdt: string
        , csea: string
        , cdoge: string
        , usdtc: Contract
        , seac: Contract
        , dogec: Contract

    let wht: string
        , whtC: Contract
        , ceth: string
        , ctokenFactory: string
        , ctokenFactoryC: Contract
    let s1: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
        , s2: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
        , s3: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
    
    let stepSwapC: Contract
        // , exLibC: Contract
  
    // e18 是 18位数
    const e18 = BigNumber.from('1000000000000000000')
    const deploy = hre.deployments.deploy
    // uint256 public constant FLAG_TOKEN_IN_ETH          = 0x000000000100; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_IN_TOKEN        = 0x000000000200; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_IN_CTOKEN       = 0x000000000400; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_OUT_ETH         = 0x000000000800; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_OUT_TOKEN       = 0x000000001000; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_OUT_CTOKEN      = 0x000000002000; // prettier-ignore
    const FLAG_TOKEN_IN_ETH      = BigNumber.from('0x000000000100')
    const FLAG_TOKEN_IN_TOKEN    = BigNumber.from('0x000000000200')
    const FLAG_TOKEN_IN_CTOKEN   = BigNumber.from('0x000000000400')
    const FLAG_TOKEN_OUT_ETH     = BigNumber.from('0x000000000800')
    const FLAG_TOKEN_OUT_TOKEN   = BigNumber.from('0x000000001000')
    const FLAG_TOKEN_OUT_CTOKEN  = BigNumber.from('0x000000002000')
    const _SHIFT_COMPLEX_LEVEL  = 80

    before(async () => {
        namedSigners = await ethers.getSigners()
        deployer = namedSigners[0].address
        buyer = namedSigners[1]
        let signer = namedSigners[0]
    
        console.log('deployer: %s buyer: %s', deployer, buyer.address)
    
        tokens = await deployTokens()
        let addresses: string[] = []
        for (let key of tokens.addresses.keys()) {
          addresses.push(tokens.addresses.get(key)!)
        }
    
        deployContracts = await deployAll({log: true, anchorToken: tokens.addresses.get('USDT'), addresses: addresses})
        // console.log('deploy contracts', deployTokens())
        unitroller = await getContractAt(deployContracts.unitroller)
        delegatorFactory = await getContractAt(deployContracts.lErc20DelegatorFactory)
        mdexFactory = await getContractAt(deployContracts.mdexFactory)
        router = await getContractAt(deployContracts.router)
    
        // const pairArt = await hre.artifacts.readArtifact('contracts/swap/heco/Factory.sol:MdexPair')
        // pairABI = pairArt.abi
    
        // create ctoken
        usdt = tokens.addresses.get('USDT')!
        sea = tokens.addresses.get('SEA')!
        doge = tokens.addresses.get('DOGE')!
        usdtc = getTokenContract(usdt, signer)
        seac = getTokenContract(sea, signer)
        dogec = getTokenContract(doge, signer)
    
        console.info('USDT:', usdt, 'SEA:', sea)
        expect(usdt).to.not.be.empty
        expect(sea).to.not.be.empty
        await expect(createCToken(deployContracts.lErc20DelegatorFactory, usdt))
          // .to.emit(delegatorFactory, 'NewDelegator').withArgs(delegatorFactory, '0x340d6d7ea30fb8fcc82d906d0232eb65243b0b87')
          // .to.emit(unitroller, 'MarketListed') //.withArgs(usdt, '')
        let tx = await createCToken(deployContracts.lErc20DelegatorFactory, sea)
    
        // const delegatorFactoryContract = await getCon
        cusdt = await delegatorFactory.getCTokenAddressPure(usdt)
        console.log('cusdt address:', cusdt)
        csea = await delegatorFactory.getCTokenAddressPure(sea)
        console.log('csea address:', csea)
    
        await tx.wait(1)
    
        wht = deployContracts.WHT.address
        whtC = new ethers.Contract(wht, deployContracts.WHT.abi, namedSigners[0])
        ceth = deployContracts.cWHT.address
        ctokenFactory = deployContracts.lErc20DelegatorFactory.address
        ctokenFactoryC = new ethers.Contract(ctokenFactory, deployContracts.lErc20DelegatorFactory.abi, namedSigners[0])

        // create pair
        await createPair(usdt, sea)
        await createPair(doge, sea)

        await deployTestFixture(wht, ceth, ctokenFactory)

      })

    // normal mdex factory
    const deployFactoryRouter = async (
                    salt: string,
                    _wht: string,
                    s: Swap
                ) => {
        let signer = namedSigners[0]
        // let salt = new Date().getTime()
        let dr = await deploy('MdexFactory', {
            from: deployer,
            args: [deployer],
            log: true,
            deterministicDeployment: salt + '', //
        })
        let router = await deploy('MdexRouter', {
            from: deployer,
            args: [dr.address, _wht],
            log: true,
            deterministicDeployment: salt + '', //
        })
        console.log('factory/router address:', dr.address, router.address, salt)

        s.fa = dr.address
        s.fc = new ethers.Contract(dr.address, dr.abi, signer)
        let initHash = await s.fc!.getInitCodeHash()
        // console.log('initHash:', initHash)
        await s.fc!.setInitCodeHash(initHash)
        s.ra = router.address
        s.rc = new ethers.Contract(router.address, router.abi, signer)

        return s
    }

    const deployTestFixture = async (_wht: string, _ceth: string, _ctokenFactory: string) => {
        await deployFactoryRouter('0x10', _wht, s1)
        await deployFactoryRouter('0x20', _wht, s2)
        await deployFactoryRouter('0x30', _wht, s3)

        let signer = namedSigners[0]
        stepSwapC = await deployStepSwap(_wht, _ceth, _ctokenFactory, signer, true, false)
        await stepSwapC.addSwap(1, s1.ra)
        await stepSwapC.addSwap(1, s2.ra)
        await stepSwapC.addSwap(1, s3.ra)
    }

    const deadlineTs = (second: number) => {
        return (new Date()).getTime() + second * 1000
    }

    const addTestLiquidityByFactory = async (
                    rc: Contract,
                    fc: Contract,
                    token0: Contract,
                    token1: Contract,
                    amt0: BigNumberish,
                    amt1: BigNumberish,
                    to: string
                ) => {
        await fc.createPair(token0.address, token1.address)
        let pair = await fc.getPair(token0.address, token1.address)
        console.log('pair of factory %s: %s', fc.address, pair)
        
        await token0.transfer(pair, BigNumber.from(amt0))
        await token1.transfer(pair, BigNumber.from(amt1))

        let pairc = await getContractByAddressName(pair, 'MdexPair', namedSigners[0])
        await pairc.mint(to)
        let ts = await pairc.balanceOf(to)
        console.log('add Liquidity: ', ts.toString())
        // await token0.approve(rc.address, amt0)
        // await token1.approve(rc.address, amt1)
        // console.log('approve success')
        // await rc.addLiquidity(token0.address, token1.address, amt0, amt1, 0, 0, to, deadlineTs(600))
        // console.log('addTestLiquidity: token0=%s token1=%s amt0=%s amt1=%s', token0.address, token1.address, amt0.toString(), amt1.toString())
    }

    const addTestLiquidity = async (
                rc: Contract,
                fc: Contract,
                token0: Contract | string,
                token1: Contract | string,
                amt0: BigNumberish,
                amt1: BigNumberish,
                to: string
            ) => {
        let ta0, ta1
        if (typeof token0 === 'string' || typeof token1 === 'string') {
            if (typeof token0 === 'string') {
                assert(typeof token1 !== 'string')
                ta0 = wht
                ta1 = (token1 as Contract).address
                await (token1 as Contract).approve(rc.address, amt1)
                await rc.addLiquidityETH(ta1, amt1, 0, 0, to, deadlineTs(600), {value: amt0})
            } else {
                ta0 =token0.address
                ta1 = wht
                await (token0 as Contract).approve(rc.address, amt0)
                await rc.addLiquidityETH(ta0, amt0, 0, 0, to, deadlineTs(600), {value: amt1})
            }
        } else {
            ta0 = token0.address
            ta1 = token1.address
            await token0.approve(rc.address, amt0)
            await token1.approve(rc.address, amt1)
            // console.log('approve success')
            await rc.addLiquidity(token0.address, ta1, BigNumber.from(amt0), BigNumber.from(amt1), 0, 0, to, deadlineTs(600))
        }
        let pair = await fc.getPair(ta0, ta1)
        // console.log('addTestLiquidity: pair of factory %s: %s', fc.address, pair)
        console.log('addTestLiquidity(%s): token0=%s token1=%s pair=%s amt0=%s amt1=%s',
                fc.address, ta0, ta1, pair, amt0.toString(), amt1.toString())
    }

    // 移除所有流动性
    const removeAllLiquidity = async (rc: Contract, fc: Contract, token0: string, token1: string, owner: string) => {
        let pair = await fc.pairFor(token0, token1)
            , pairc = getTokenContract(pair)
            , amt = await pairc.balanceOf(owner)
        if (token0 === zeroAddress || token1 === zeroAddress) {
            rc.removeLiquidityETH(token0 === zeroAddress ? token1 : token0, amt, 0, 0, owner, deadlineTs(600))
        } else {
            rc.removeLiquidity(token0, token1, amt, 0, 0, owner, deadlineTs(600))
        }
    }
    
    // create pair
    const createPair = async (tokenA: string, tokenB: string) => {
        await ctokenFactoryC.getCTokenAddress(tokenA)
        await ctokenFactoryC.getCTokenAddress(tokenB)
        let etokenA = await ctokenFactoryC.getCTokenAddressPure(tokenA)
            , etokenB = await ctokenFactoryC.getCTokenAddressPure(tokenB)

        let tx = await mdexFactory.createPair(tokenA, tokenB, etokenA, etokenB)
        console.log('create pair: tokenA: %s(%s) tokenB: %s(%s)', tokenA, etokenA, tokenB, etokenB, await mdexFactory.pairFor(tokenA, tokenB))
        await tx.wait(1)
    }

    
    const printParam = (res: any) => {
        console.log("mintAmtOut=%s routes=%s block=%s", res.minAmt.toString(), res.steps.length, res.block.toString())
        for (let i = 0; i < res.steps.length; i ++) {
            let step = res.steps[i]
                , flag = step.flag
            console.log('route %d flag %s', i, flag.toString(), step.data)
            if (flag.eq(1)) {

            } else if (flag.eq(2)) {

            } else if (flag.eq(BigNumber.from('0x101'))) {
                console.log('uniswap router token->token')
            }
            // AbiCoder.decode('', step)
        }
    }

    /*
    it('no-middle-token', async () => {
        // await addTestLiquidityByFactory(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '20000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '20000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, seac, usdtc, '2000000000000000000000', '40000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, seac, usdtc, '4000000000000000000000', '80000000', deployer)

        let amtIn = BigNumber.from('5000000000000000000')
        let parts = BigNumber.from(50).or(FLAG_TOKEN_IN_TOKEN).or(FLAG_TOKEN_OUT_TOKEN)
        let res = await stepSwapC.getExpectedReturnWithGas({
            to: deployer,
            tokenIn: sea,
            tokenOut: usdt,
            amountIn: amtIn,
            tokenPriceGWei: 0,
            fromAddress: deployer,
            dstReceiver: deployer,
            midTokens: [],
            flag: { data: parts },
        })

        printParam(res)

        logHr('unoswap')
        await seac.approve(stepSwapC.address, amtIn)
        await stepSwapC.unoswap(res)

        await removeAllLiquidity(s1.rc!, s1.fc!, sea, usdt, deployer)
        await removeAllLiquidity(s2.rc!, s2.fc!, sea, usdt, deployer)
        await removeAllLiquidity(s3.rc!, s3.fc!, sea, usdt, deployer)
    })
    */

    it('middle-token-1', async () => {
        // await addTestLiquidityByFactory(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '20000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, dogec, '1000000000000000000000', '2000000000000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '1100000000000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, usdtc, dogec, '1000000000000000000000', '2000000000000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, ht, '1000000000000000000000', '11000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, ht, dogec, '10000000000000', '2000000000000000000000', deployer)

        await addTestLiquidity(s2.rc!, s2.fc!, seac, dogec, '2000000000000000000000', '4000000000000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, seac, usdtc, '2000000000000000000000', '2200000000000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, usdtc, dogec, '2000000000000000000000', '4000000000000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, seac, ht, '2000000000000000000000', '22000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, ht, dogec, '20000000000000', '4000000000000000000000', deployer)

        await addTestLiquidity(s3.rc!, s3.fc!, seac, dogec, '4000000000000000000000', '8000000000000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, seac, usdtc, '4000000000000000000000', '4400000000000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, usdtc, dogec, '4000000000000000000000', '8000000000000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, seac, ht, '4000000000000000000000', '44000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, ht, dogec, '40000000000000', '8000000000000000000000', deployer)

        let amtIn = BigNumber.from('5000000000000000000')
            , complex = 2
            , tokenIn = sea
            , tokenInC = getTokenContract(tokenIn, namedSigners[0])
            , tokenOut = doge
            , midTokens = [usdt, ht]
            , parts = 100

        let tx = await buildAggressiveSwapTx(
                        stepSwapC,
                        deployer,
                        tokenIn, 
                        tokenOut,
                        midTokens,
                        amtIn,
                        100,
                        complex,
                        parts
                    )
        console.log('tx:', 'tx')
        await tokenInC.approve(stepSwapC.address, amtIn)
        await stepSwapC.unoswap(tx)
        /*
        let routePath = await stepSwapC.getSwapReserveRates({
                            to: deployer,
                            tokenIn: tokenIn,
                            tokenOut: tokenOut,
                            amountIn: amtIn,
                            midTokens: midTokens,
                            mainRoutes: 100,
                            complex: complex,
                            parts: parts,
                            allowPartial: true,
                            allowBurnchi: true,
                        })
            , flag =  routePath.flag // buildFlag(50, FLAG_TOKEN_IN_TOKEN, FLAG_TOKEN_OUT_TOKEN, complex)
            , routes = routePath.routes
            , paths = routePath.paths
            , cpaths = routePath.cpaths

        // console.log('route, path, reserves:', routePath)
        for (let i = 0; i < routePath.reserves.length; i ++) {
            // console.log('reserve %d: %s', i, routePath.reserves[i].toString())
        }

        let amounts = calcExchangeListSwap(parts, amtIn, routePath)
        // console.log('amouts:', amounts)
        let distributes = findBestDistribution(parts, amounts)
        console.log('distributes swapRoutes: %s returnAmount: %s',
                    distributes.swapRoutes.toString(), distributes.returnAmount.toString())
        */
    })

    // it('ht-token-middle-0', async () => {
    //     // await addTestLiquidityByFactory(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '20000000', deployer)
    //     await addTestLiquidity(s1.rc!, s1.fc!, seac, dogec, '1000000000000000000000', '2000000000000000000000', deployer)
    //     await addTestLiquidity(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '1000000000000000000000', deployer)
    //     await addTestLiquidity(s1.rc!, s1.fc!, usdtc, dogec, '1000000000000000000000', '2000000000000000000000', deployer)

    //     await addTestLiquidity(s2.rc!, s2.fc!, seac, dogec, '2000000000000000000000', '4000000000000000000000', deployer)
    //     await addTestLiquidity(s2.rc!, s2.fc!, seac, usdtc, '2000000000000000000000', '2000000000000000000000', deployer)
    //     await addTestLiquidity(s2.rc!, s2.fc!, usdtc, dogec, '2000000000000000000000', '4000000000000000000000', deployer)

    //     await addTestLiquidity(s3.rc!, s3.fc!, seac, dogec, '4000000000000000000000', '8000000000000000000000', deployer)
    //     await addTestLiquidity(s3.rc!, s3.fc!, seac, usdtc, '4000000000000000000000', '4000000000000000000000', deployer)
    //     await addTestLiquidity(s3.rc!, s3.fc!, usdtc, dogec, '4000000000000000000000', '8000000000000000000000', deployer)

    //     let amtIn = BigNumber.from('5000000000000000000')
    //     let parts = BigNumber.from(50).or(FLAG_TOKEN_IN_ETH).or(FLAG_TOKEN_OUT_TOKEN)
    //     let res = await stepSwapC.getExpectedReturnWithGas({
    //         to: deployer,
    //         tokenIn: sea,
    //         tokenOut: doge,
    //         amountIn: amtIn,
    //         tokenPriceGWei: 0,
    //         fromAddress: deployer,
    //         dstReceiver: deployer,
    //         midTokens: [usdt],
    //         flag: { data: parts },
    //     })

    //     printParam(res)

    //     logHr('unoswap')
    //     await seac.approve(stepSwapC.address, amtIn)
    //     await stepSwapC.unoswap(res)
    // })

    /*
    it('ht-token-middle-1', async () => {
        // await addTestLiquidityByFactory(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '20000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, dogec, '1000000000000000000000', '2000000000000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '1000000000000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, usdtc, dogec, '1000000000000000000000', '2000000000000000000000', deployer)

        await addTestLiquidity(s2.rc!, s2.fc!, seac, dogec, '2000000000000000000000', '4000000000000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, seac, usdtc, '2000000000000000000000', '2000000000000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, usdtc, dogec, '2000000000000000000000', '4000000000000000000000', deployer)

        await addTestLiquidity(s3.rc!, s3.fc!, seac, dogec, '4000000000000000000000', '8000000000000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, seac, usdtc, '4000000000000000000000', '4000000000000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, usdtc, dogec, '4000000000000000000000', '8000000000000000000000', deployer)

        let amtIn = BigNumber.from('5000000000000000000')
        let parts = BigNumber.from(50).or(FLAG_TOKEN_IN_ETH).or(FLAG_TOKEN_OUT_TOKEN)
        let res = await stepSwapC.getExpectedReturnWithGas({
            to: deployer,
            tokenIn: sea,
            tokenOut: doge,
            amountIn: amtIn,
            tokenPriceGWei: 0,
            fromAddress: deployer,
            dstReceiver: deployer,
            midTokens: [usdt],
            flag: { data: parts },
        })

        printParam(res)

        logHr('unoswap')
        await seac.approve(stepSwapC.address, amtIn)
        await stepSwapC.unoswap(res)
    })
    it('token-ht-middle-0', async () => {
        // await addTestLiquidityByFactory(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '20000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, dogec, '1000000000000000000000', '2000000000000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '1000000000000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, usdtc, dogec, '1000000000000000000000', '2000000000000000000000', deployer)

        await addTestLiquidity(s2.rc!, s2.fc!, seac, dogec, '2000000000000000000000', '4000000000000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, seac, usdtc, '2000000000000000000000', '2000000000000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, usdtc, dogec, '2000000000000000000000', '4000000000000000000000', deployer)

        await addTestLiquidity(s3.rc!, s3.fc!, seac, dogec, '4000000000000000000000', '8000000000000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, seac, usdtc, '4000000000000000000000', '4000000000000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, usdtc, dogec, '4000000000000000000000', '8000000000000000000000', deployer)

        let amtIn = BigNumber.from('5000000000000000000')
        let parts = BigNumber.from(50).or(FLAG_TOKEN_IN_ETH).or(FLAG_TOKEN_OUT_TOKEN)
        let res = await stepSwapC.getExpectedReturnWithGas({
            to: deployer,
            tokenIn: sea,
            tokenOut: doge,
            amountIn: amtIn,
            tokenPriceGWei: 0,
            fromAddress: deployer,
            dstReceiver: deployer,
            midTokens: [usdt],
            flag: { data: parts },
        })

        printParam(res)

        logHr('unoswap')
        await seac.approve(stepSwapC.address, amtIn)
        await stepSwapC.unoswap(res)
    })
    it('token-ht-middle-1', async () => {
        // await addTestLiquidityByFactory(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '20000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, dogec, '1000000000000000000000', '2000000000000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '1000000000000000000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, usdtc, dogec, '1000000000000000000000', '2000000000000000000000', deployer)

        await addTestLiquidity(s2.rc!, s2.fc!, seac, dogec, '2000000000000000000000', '4000000000000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, seac, usdtc, '2000000000000000000000', '2000000000000000000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, usdtc, dogec, '2000000000000000000000', '4000000000000000000000', deployer)

        await addTestLiquidity(s3.rc!, s3.fc!, seac, dogec, '4000000000000000000000', '8000000000000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, seac, usdtc, '4000000000000000000000', '4000000000000000000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, usdtc, dogec, '4000000000000000000000', '8000000000000000000000', deployer)

        let amtIn = BigNumber.from('5000000000000000000')
        let parts = BigNumber.from(50).or(FLAG_TOKEN_IN_ETH).or(FLAG_TOKEN_OUT_TOKEN)
        let res = await stepSwapC.getExpectedReturnWithGas({
            to: deployer,
            tokenIn: sea,
            tokenOut: doge,
            amountIn: amtIn,
            tokenPriceGWei: 0,
            fromAddress: deployer,
            dstReceiver: deployer,
            midTokens: [usdt],
            flag: { data: parts },
        })

        printParam(res)

        logHr('unoswap')
        await seac.approve(stepSwapC.address, amtIn)
        await stepSwapC.unoswap(res)
    })
    */
})
