const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'
import { getContractAt, getContractBy } from '../utils/contracts'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { AbiCoder } from 'ethers/lib/utils';
import { assert } from 'console';

import { DeployContracts, deployAll, deployTokens, Tokens, zeroAddress, deployStepSwap } from '../deployments/deploys'
import { logHr } from '../helpers/logHr'
import createCToken from './shared/ctoken'
import { setNetwork, getTokenContract, getCTokenContract, getProvider, getContractByAddressName } from '../helpers/contractHelper'
import { buildAggressiveSwapTx } from '../helpers/aggressive';

const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network
const ht = zeroAddress

setNetwork(network.name)
// console.log('provider:', ethers.provider)

const e18 = BigNumber.from('1000000000000000000')

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
    let ebankFactory: Contract
    let ebankRouter: Contract
    // let pairABI: any
    let deployer: string
    let buyer: SignerWithAddress

    let usdt: string
        , sea: string
        , doge: string
        , shib: string
        , cusdt: string
        , csea: string
        , cdoge: string
        , usdtc: Contract
        , seac: Contract
        , dogec: Contract
        , shibc: Contract

    let wht: string
        , whtC: Contract
        , ceth: string
        , ctokenFactory: string
        , ctokenFactoryC: Contract
    let s1: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
        , s2: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
        , s3: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
    
    let stepSwapC: Contract
        , stepSwapAddr: string
        , stepSwapAbi: any
        // , exLibC: Contract
  
    // e18 是 18位数
    const e18 = BigNumber.from('1000000000000000000')
    const deploy = hre.deployments.deploy

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
        ebankFactory = await getContractAt(deployContracts.mdexFactory)
        ebankRouter = await getContractAt(deployContracts.router)
    
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

        let result = await deployStepSwap(_wht, _ceth, _ctokenFactory, true, false)
        stepSwapC = result.stepSwapC
        stepSwapAbi = result.abi
        stepSwapAddr = result.address

        await stepSwapC.addSwap(1, s1.ra)
        await stepSwapC.addSwap(1, s2.ra)
        await stepSwapC.addSwap(1, s3.ra)
        await stepSwapC.addSwap(3, ebankRouter.address)
    }

    const getStepSwapContract = (signer: SignerWithAddress) => {
        return new ethers.Contract(stepSwapAddr, stepSwapAbi, signer)
    }

    const deadlineTs = (second: number) => {
        return (new Date()).getTime() + second * 1000
    }

    // 参数必须为 etoken 地址
    const _getTokenAddress = async (etoken: string) => {
        return delegatorFactory.getTokenAddress(etoken)
    }
    const _getETokenAddress = async (etoken: string) => {
        return delegatorFactory.getCTokenAddressPure(etoken)
    }

    const addTokenLiquidity = async (
                rc: Contract,
                fc: Contract,
                underlying: boolean,
                token0: string,
                token1: string,
                _amt0: BigNumberish,
                _amt1: BigNumberish,
                // to: string,
                signer: SignerWithAddress
            ) => {
        let to = signer.address
            , amt0 = BigNumber.from(_amt0).mul(e18)
            , amt1 = BigNumber.from(_amt1).mul(e18)

        if (token0 === zeroAddress || token1 == zeroAddress) {
            // token -> eth or eth -> token
            if (token0 === zeroAddress) {
                let token1c = getTokenContract(token1, signer)
                await token1c.approve(rc.address, amt1)
                if (underlying) {
                    console.log('addLiquidityETHUnderlying: token0 is HT, token1=%s amt0=%s amt1=%s', token1, amt0.toString(), amt1.toString())
                    await rc.addLiquidityETHUnderlying(token1, amt1, 0, 0, to, deadlineTs(600), {value: amt0})
                } else {
                    await rc.addLiquidityETH(token1, amt1, 0, 0, to, deadlineTs(600), {value: amt0})
                }
            } else {
                let token0c = getTokenContract(token0, signer)
                await token0c.approve(rc.address, amt0)
                if (underlying) {
                    await rc.addLiquidityETHUnderlying(token0, amt0, 0, 0, to, deadlineTs(600), {value: amt1})
                } else {
                    await rc.addLiquidityETH(token0, amt0, 0, 0, to, deadlineTs(600), {value: amt1})
                }
            }
        } else {
            // token <-> token
            let token0c = getTokenContract(token0, signer)
                , token1c = getTokenContract(token1, signer)
            await token0c.approve(rc.address, amt0)
            await token1c.approve(rc.address, amt1)
            if (underlying) {
                await rc.addLiquidityUnderlying(token0, token1, amt0, amt1, 0, 0, to, deadlineTs(600))
            } else {
                await rc.addLiquidity(token0, token1, amt0, amt1, 0, 0, to, deadlineTs(600))
            }
        }
        
        let ctoken0 = token0 === zeroAddress ? ceth : await _getETokenAddress(token0)
            , ctoken1 = token1 === zeroAddress ? ceth : await _getETokenAddress(token1)
            , pair = await fc.pairFor(token0 === zeroAddress ? wht : token0, token1 === zeroAddress ? wht : token1)
            , pairc = await getContractByAddressName(pair, 'MdexPair', signer)
            , reserve = await pairc.getReserves()
            , tokens0 = await pairc.token0()
            , tokens1 = await pairc.token1()
    
        console.log('add liquidity: %s(%s) %s(%s)', token0, ctoken0, token1, ctoken1)
        console.log('pair token0/token1: %s %s', tokens0, tokens1)
        console.log('reserves:', reserve[0].toString(), reserve[1].toString())
    }

    const addTokenLiquidityFactory = async (
        fc: Contract,
        underlying: boolean,
        token0: string,
        token1: string,
        amt0: BigNumberish,
        amt1: BigNumberish,
        signer: SignerWithAddress
    ) => {
        let t0: Contract
            , t1: Contract
        if (token0 === zeroAddress) {
            t0 = whtC
            await whtC.deposit({value: amt0})
        } else {
            t0 = getTokenContract(token0, signer)
        }
        if (token1 === zeroAddress) {
            t1 = whtC
            await whtC.deposit({value: amt1})
        } else {
            t1 = getTokenContract(token1, signer)
        }

        let pair = await fc.pairFor(t0.address, t1.address)

        if (pair === zeroAddress) {
            console.warn('pair not exist, create pair')
            await fc.createPair(t0.address, t1.address)
            pair = await fc.pairFor(t0.address, t1.address)
            assert(pair !== zeroAddress, "create pair failed")
        }

        console.log('pair:', pair)
        await t0.transfer(pair, amt0)
        await t1.transfer(pair, amt1)
        // let pair = getPair
        let pairc = await getContractByAddressName(pair, 'MdexPair', signer)
        await pairc.mint(signer.address)
    }

    // 移除所有流动性
    const removeAllLiquidity = async (rc: Contract, fc: Contract, underlying: boolean, token0: string, token1: string, owner: string) => {
        let pair = await fc.pairFor(token0 === zeroAddress ? wht : token0, token1 === zeroAddress ? wht : token1)
        // console.log('pair:', pair)
        let pairc = getTokenContract(pair, namedSigners[0])
        let amt = await pairc.balanceOf(owner)
        console.log('pair:', pair, amt.toString())
        await pairc.approve(rc.address, amt)
        if (token0 === zeroAddress || token1 === zeroAddress) {
            if (underlying) {
                await rc.removeLiquidityETHUnderlying(token0 === zeroAddress ? token1 : token0, amt, 0, 0, owner, deadlineTs(600))
            } else {
                console.log('removeLiquidityETH .... ')
                await rc.removeLiquidityETH(token0 === zeroAddress ? token1 : token0, amt, 0, 0, owner, deadlineTs(600))
                console.log('removeLiquidityETH ')
            }
        } else {
            if (underlying) {
                await rc.removeLiquidityUnderlying(token0, token1, amt, 0, 0, owner, deadlineTs(600))
            } else {
                await rc.removeLiquidity(token0, token1, amt, 0, 0, owner, deadlineTs(600))
            }
        }
    }
    
    // create pair
    const createPair = async (tokenA: string, tokenB: string) => {
        await ctokenFactoryC.getCTokenAddress(tokenA)
        await ctokenFactoryC.getCTokenAddress(tokenB)
        let etokenA = await ctokenFactoryC.getCTokenAddressPure(tokenA)
            , etokenB = await ctokenFactoryC.getCTokenAddressPure(tokenB)

        let tx = await ebankFactory.createPair(tokenA, tokenB, etokenA, etokenB)
        console.log('create pair: tokenA: %s(%s) tokenB: %s(%s)', tokenA, etokenA, tokenB, etokenB, await ebankFactory.pairFor(tokenA, tokenB))
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

    interface PairReserve {
        token0: string
        token1: string
        amountA: BigNumberish
        amountB: BigNumberish
    }

    interface LiquidityParam {
        rc: Contract
        fc?: Contract
        underlying: boolean
        owner: SignerWithAddress
        pairs: PairReserve[]
    }

    const sanitizeMidTokens = async (
                                    isEToken: boolean,
                                    tokenIn:  string,
                                    tokenOut: string,
                                    mids: string[]
                                ): Promise<string[]> => {
        let midTokens: string[] = []
            , ti = tokenIn
            , to = tokenOut
        if (isEToken) {
            ti = await _getTokenAddress(tokenIn)
            to = await _getTokenAddress(tokenOut)
        }
        if (ti === zeroAddress) {
            ti = wht
        }
        if (to === zeroAddress) {
            to = wht
        }

        for (let t of mids) {
            // 
            if (t !== ti && t !== to) {
                midTokens.push(t)
            }
        }
        return midTokens
    }

    const _getBalance = async (token: string, owner: string) => {
        if (token === zeroAddress) {
            return getProvider().getBalance(owner)
        }
        let tokenc = getTokenContract(token, namedSigners[0])
        return tokenc.balanceOf(owner)
    }

    // transfer from maker to taker
    // token is NOT ht
    const transferToTaker = async (token: string, taker: string, amt: BigNumberish) => {
        let tokenc = getTokenContract(token, namedSigners[0])
        await tokenc.transfer(taker, amt)
    }

    const makeTestCase = async (
                                tokenIn:  string,
                                tokenOut: string,
                                amountIn: BigNumber,
                                _midTokens: string[],
                                liquidities: LiquidityParam[],
                                taker: SignerWithAddress,
                                isEToken = false,
                                complex = 2,
                                parts = 100,
                            ) => {
        amountIn = amountIn.mul(e18)
        let midTokens: string[] = await sanitizeMidTokens(isEToken, tokenIn, tokenOut, _midTokens)

        if (tokenIn !== zeroAddress) {
            await transferToTaker(tokenIn, taker.address, amountIn)
        }

        for (let i = 0; i < liquidities.length; i ++) {
            let liquidity = liquidities[i]

            for (let j = 0; j < liquidity.pairs.length; j ++) {
                let pair = liquidity.pairs[j]

                await addTokenLiquidity(
                            liquidity.rc,
                            liquidity.fc!,
                            liquidity.underlying,
                            pair.token0,
                            pair.token1,
                            pair.amountA,
                            pair.amountB,
                            // liquidity.owner.address,
                            liquidity.owner
                        )
                // await addTokenLiquidityFactory(
                //             liquidity.fc!,
                //             liquidity.underlying,
                //             pair.token0,
                //             pair.token1,
                //             pair.amountA,
                //             pair.amountB,
                //             // liquidity.owner.address,
                //             liquidity.owner
                //         )
                console.log('add liquidity by router %s done', liquidity.rc.address)
            }
        }
        
        let txdata = await buildAggressiveSwapTx(
            stepSwapC,
            deployer,
            tokenIn, 
            tokenOut,
            midTokens,
            amountIn,
            100,
            complex,
            parts
        )
        
        console.log('tx:', 'tx')
        let b0b = await _getBalance(tokenIn, buyer.address)
            , b1b = await _getBalance(tokenOut, buyer.address)
        let ssc: Contract = getStepSwapContract(taker)
        if (tokenIn === zeroAddress) {
            let tx = await ssc.unoswap(txdata, {value: amountIn})
            await tx.wait(1)
        } else {
            let tokenInC = getTokenContract(tokenIn, taker)
            await tokenInC.approve(stepSwapC.address, amountIn)
            let tx = await ssc.unoswap(txdata)
            await tx.wait(1)
        }
        let b0a = await _getBalance(tokenIn, buyer.address)
            , b1a = await _getBalance(tokenOut, buyer.address)
        
        console.log('taker balance: tokenIn:  %s -> %s, -%s',
                    b0b.toString(), b0a.toString(), b0b.sub(b0a).toString())
        console.log('taker balance: tokenOut: %s -> %s, +%s',
                    b1b.toString(), b1a.toString(), b1a.sub(b1b).toString())

        console.log('remove liquidity (total: %d) ....', liquidities.length)
        // clean liquidity
        for (let i = 0; i < liquidities.length; i ++) {
            let liquidity = liquidities[i]

            for (let j = 0; j < liquidity.pairs.length; j ++) {
                let pair = liquidity.pairs[j]

                await removeAllLiquidity(
                            liquidity.rc,
                            liquidity.fc!,
                            liquidity.underlying,
                            pair.token0,
                            pair.token1,
                            liquidity.owner.address,
                        )
                console.log('remove liquidity ok: %d', i)
            }
        }
    }

    // it('basic-token-token', async () => {
    //     let signer = namedSigners[0]
    //     await makeTestCase(sea, doge, BigNumber.from('5000000000000000000'), [usdt], [{
    //         rc: s1.rc!,
    //         fc: s1.fc!,
    //         underlying: false,
    //         owner: signer,
    //         pairs: [
    //             {
    //                 token0: sea,
    //                 token1: doge,
    //                 amountA: '1000000000000000000000',
    //                 amountB: '20000000',
    //             },
    //         ]
    //     }, {
    //         rc: s2.rc!,
    //         fc: s2.fc!,
    //         underlying: false,
    //         owner: signer,
    //         pairs: [
    //             {
    //                 token0: sea,
    //                 token1: doge,
    //                 amountA: '2000000000000000000000',
    //                 amountB: '40000000',
    //             },
    //         ]
    //     },
    // ], signer)
    // })

    
    it('ht-token-1', async () => {
        logHr('ht->token')
        let maker = namedSigners[0]
        await makeTestCase(ht, doge, BigNumber.from('5'), [usdt], [{
            rc: s1.rc!,
            fc: s1.fc!,
            underlying: false,
            owner: maker,
            pairs: [
                {
                    token0: ht,
                    token1: doge,
                    amountA: '200',
                    amountB: '1000',
                },
            ]
        }, {
            rc: ebankRouter,
            fc: ebankFactory,
            underlying: true,
            owner: maker,
            pairs: [{
                token0: ht,
                token1: doge,
                amountA: '200',
                amountB: '1000',
            }
            ]
        }], buyer)
    })
    
    it('token-ht-1', async () => {
        logHr('token->ht')
        let maker = namedSigners[0]
            , midTokens: string[] = [] // [usdt]

        await makeTestCase(doge, sea, BigNumber.from('5'), midTokens, [{
            rc: s1.rc!,
            fc: s1.fc!,
            underlying: false,
            owner: maker,
            pairs: [
                {
                    token0: doge,
                    token1: sea,
                    amountA: '10000',
                    amountB: '2000',
                },
            ]
        }, {
            rc: s2.rc!,
            fc: s2.fc!,
            underlying: false,
            owner: maker,
            pairs: [
                {
                    token0: doge,
                    token1: ht,
                    amountA: '20000',
                    amountB: '4000',
                },
            ]
        }, {
            rc: ebankRouter,
            fc: ebankFactory,
            underlying: true,
            owner: maker,
            pairs: [{
                token0: doge,
                token1: ht,
                amountA: '20000',
                amountB: '4000',
            }
            ]
        }
        ], buyer)
    })
     
})
