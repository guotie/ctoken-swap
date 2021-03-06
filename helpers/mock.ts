import deploy from './deploy'
import { e18, addressOf, dumpAddresses, NETWORK, setContractAddress, getEbeTokenContract, getEbankRouter } from './contractHelper'
import { getMockToken, IToken, readableTokenAmount, deadlineTs } from './token'

import { BigNumber } from '@ethersproject/bignumber'
import { Contract } from 'ethers'
// import { Contract } from '@ethersproject/contracts'
import { zeroAddress } from '../deployments/deploys'
import { BigNumberish } from 'ethers'
import { callWithEstimateGas } from './estimateGas';
import { AbiCoder, id } from 'ethers/lib/utils';

const hre = require('hardhat')
// const ethers = hre.ethers
const ethers = hre.ethers

async function _deployMock(name: string, opts: any) {
    const networkName = hre.network.name
    if (networkName !== 'hardhat') {
        return { 'address': '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836' } // hecotest
    }

    let namedSigners = await ethers.getSigners()

    opts.from = namedSigners[0].address
    opts.log = true

    return deploy(name, opts, networkName !== 'hardhat')
}

export async function _deployWHT() {
    let result = await _deployMock('WHT', {args: [] })
    setContractAddress('WHT', result.address)
    setContractAddress('WETH', result.address)
}

async function setUnitrollerMethodId(unitroller: Contract) {
    let methods = [
                "0x27efe3cb",
                "0x26634e4c",
                "0xc1abfaa3",
                "0xd7f4f30f",
                "0x2f52e595",
                "0x007e3dd2",
                "0x7df0f767",
                "0xabfceffc",
                "0x929fe9a1",
                "0x8708ec63",
                "0x31975b69"
            ]
        , impls = ["1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"]
    let tx = await unitroller._setMethodId(methods, impls)
    await tx.wait(1)
}

async function setDelegateFactory(ctokenFactoryc: Contract, admin: string) {
    // 1. setComproller
    let troller = addressOf('Unitroller')
    await ctokenFactoryc._setComptroller(troller)
	// 2. setDelegate
    let delegate = addressOf('LErc20Delegate')
    await ctokenFactoryc._setImplementation(delegate)
	// 3. setInterestRateModel
    let interest = addressOf('InterestRateModel')
    await ctokenFactoryc._setInterestRateModel(interest)
	// 4. ?????? swap ??????
	// 5. ?????? delegatorAdmin
    await ctokenFactoryc._setDelegatorAdmin(admin)
}

// must called after deploy wht
export async function deployCompound() {
    let namedSigners = await ethers.getSigners()
        , deployer = namedSigners[0].address

    let comp = await _deployMock('Comptroller', { args: [] });
    setContractAddress('Comptroller', comp.address)

    let compv2 = await _deployMock('ComptrollerV2', { args: [] });
    setContractAddress('ComptrollerV2', comp.address)

    let uni = await _deployMock('Unitroller', { args: [] });
    setContractAddress('Unitroller', uni.address)
    
    // ?????? unitroller ??? implement ??? comp.address
    // console.log('namedSigners[0]:', namedSigners[0])
    let unitrollerc = new ethers.Contract(uni.address, uni.abi, namedSigners[0])
    let comptrollerv2c = new ethers.Contract(uni.address, compv2.abi, namedSigners[0])
    
    let comptrollerImplementation = await unitrollerc.implementsMapping(0)
    if (comptrollerImplementation !== comp.address) {
        console.log('comptroller implemention set to %s & %s ...', comp.address, compv2.address)
        // await (await unitroller._setPendingImplementation(comp.address)).wait(1)
        await (await unitrollerc._setImplementation(0, comp.address)).wait(1)
        await (await unitrollerc._setImplementation(1, compv2.address)).wait(1)

        await setUnitrollerMethodId(unitrollerc)
        // todo set method Id
        // ???????????? comptroller ????????? !!!
        // await unitroller.functions._acceptImplementation()
        // await (await comptroller._become(uni.address)).wait(1)
    }
    
    // 
  // ????????????
  const interest = await _deployMock('WhitePaperInterestRateModel', {
    // 10% 60%
    args: [
        '1000000000000000000',
        '3000000000000000000'
        ],
    });
    setContractAddress('InterestRateModel', interest.address)

      // LErc20Delegate erc20 implement
    let lerc20Implement = await _deployMock('LErc20Delegate', { args: [] });
    setContractAddress('LErc20Delegate', lerc20Implement.address)

    let lercFactoryDeployed = await _deployMock('LErc20DelegatorFactory', {
        args: [], // lerc20Implement.address, unitroller.address, interest.address],
      });
    let  ctokenFactoryc = new ethers.Contract(lercFactoryDeployed.address, lercFactoryDeployed.abi, namedSigners[0])
    await setDelegateFactory(ctokenFactoryc, deployer)
    setContractAddress('CtokenFactory', lercFactoryDeployed.address)
    // ?????? compv2 ??? _setDelegateFactoryAddress
    // console.info('_setDelegateFactoryAddress .... ')
    await (await comptrollerv2c._setDelegateFactoryAddress(lercFactoryDeployed.address)).wait(1)
    
    let lht = await _deployMock('LHT', {
        // comptroller_ interestRateModel_ initialExchangeRateMantissa_ name_ symbol_ decimals_ admin_
        args: [unitrollerc.address, interest.address, '15000000000000000000', 'WHT', 'WHT', 18, deployer],
      });
    setContractAddress('CETH', lht.address)
    
    let wht = addressOf('WHT')
    // console.info('list WHT to compound market')
    await comptrollerv2c._supportMarket(wht, lht.address)
}

export async function deploySwap() {
    let usdt = addressOf('USDT')
        , wht = addressOf('WHT')
        , ceth = addressOf('CETH')
        , ctokenFactory = addressOf('CtokenFactory')
        , namedSigners = await ethers.getSigners()

    const factory = await _deployMock('DeBankFactory', {
        // 10% 60% ????????? usdt ??????
        args: [ usdt ],
      });
    setContractAddress('Factory', factory.address)
    
    const router = await _deployMock('DeBankRouter', {
        // factory wht lht startBlock
        args: [factory.address, wht, ceth, ctokenFactory],
      })
    setContractAddress('Router', router.address)

    // SwapExchangeRate
    const rate = await _deployMock('SwapExchangeRate', { args: []} )
    setContractAddress('SwapExchangeRate', rate.address)

    // set factory router !!!
    let fc = new ethers.Contract(factory.address, factory.abi, namedSigners[0])
    await fc.setRouter(router.address)

    let rc = new ethers.Contract(router.address, router.abi, namedSigners[0])
    console.info('router factory:', await rc.factory())
}

export async function deployTokens() {
    await getMockToken('USDT', '100000000000000000', 6)
    await getMockToken('SEA',  '200000000000000000000000000000000')
    await getMockToken('DOGE', '300000000000000000000000000000000')
    await getMockToken('SHIB', '400000000000000000000000000000000')
    // await getMockToken()
}

async function deployOrderBook(proxy = false) {
    let namedSigners = await ethers.getSigners()
        , admin = namedSigners[1].address
    let l = await _deployMock('OBPriceLogic', { args: [] })
    let c = await _deployMock('OBPairConfig', { args: [] })
    let ctokenFactory = addressOf('CtokenFactory')
        , ceth = addressOf('CETH')
        , weth = addressOf('WHT')
        , margin = zeroAddress
        , args: any[] = []

    if (!proxy) {
        args = [ctokenFactory, ceth, weth, margin]
    }
    let ob = await _deployMock('OrderBook', {
        args: args,
        libraries: {
            OBPriceLogic: l.address,
            OBPairConfig: c.address
        },
    });

    setContractAddress('OBPriceLogic', l.address)
    setContractAddress('OrderBook', ob.address)
    if (!proxy) {
        // let obc = new ethers.Contract(ob.address, ob.abi, namedSigners[0])
        // await (await obc.initialize(ctokenFactory, ceth, weth, margin)).wait()
        setContractAddress('OrderBookProxy', ob.address)
    } else {
        
        const abiCoder = new AbiCoder()
        let args = abiCoder.encode(['address', 'address', 'address', 'address'], [ctokenFactory, ceth, weth, margin])
        // 0xf8c8765e
        // initialize(address _ctokenFactory, address _cETH, address _wETH, address _margin)
        let func = id('initialize(address,address,address,address)')
        let selector = '0xf8c8765e' // func.slice(0, 10)
        let param = selector + args.slice(2)

        // console.log('initialize(): %s', id('initialize()'))
        // console.log('initialize(address,address,address,address): %s', id('initialize(address,address,address,address)'))
        // console.log('func: %s\nparam: %s\nargs:%s', func, args, param)

        let proxyAdmin = await _deployMock('ProxyAdmin', { args: [] })
        setContractAddress('OrderBookProxyAdmin', proxyAdmin.address)
        // param = '0x8129fc1c' // initialize()
        let proxy = await _deployMock('TransparentUpgradeableProxy', {
            args: [ ob.address, proxyAdmin.address, param]
        })
        setContractAddress('OrderBookProxy', proxy.address)
        // setContractAddress('OrderBook', proxy.address)
    }

    console.info('orderbook deploy success')
    return ob
}

export async function deployEbe() {
    // let namedSigners = await ethers.getSigners()
        // , deployer = namedSigners[0].address
    const result = await _deployMock('EBEToken', { args: [] });

    setContractAddress('EBEToken', result.address)
    return result
}

export async function deployHecoPool(ebe: string, ebePerBlock: number, startBlock: number) {
    const e18 = BigNumber.from('1000000000000000000')
        , result = await _deployMock('HecoPool', {
            args: [ ebe, BigNumber.from(ebePerBlock).mul(e18), startBlock ],
            });
    setContractAddress('HecoPool', result.address)
    return result
}

async function deploySwapMining(perBlock: BigNumberish) {
    let ebe = addressOf('EBEToken')
        , router = addressOf('Router')
        // , namedSigners = await ethers.getSigners()
        // , deployer = namedSigners[0].address
    
    let swapMining = await _deployMock('SwapMining', { args: [ebe, router, perBlock, 0] })
        // , c = new ethers.Contract(swapMining.address, swapMining.abi, namedSigners[0])
    setContractAddress('SwapMining', swapMining.address)
}

async function deployEbeHecoPool() {
    // let namedSigners = await ethers.getSigners()
        // , deployer = namedSigners[0].address
    
    const ebe = await deployEbe()
    // let pool = 
    await deployHecoPool(ebe.address, 10, 0)
    // let ebec = new ethers.Contract(ebe.address, ebe.abi, namedSigners[0])
    // await ebec.setMinter(pool.address, true)

    // ????????? 80 ???
    await deploySwapMining(BigNumber.from(80).mul(e18))

    // await ebec.setMinter(addressOf('Router'), true)
    // await ebec.setMinter(addressOf('SwapMining'), true)

    console.log('deploy EBE, heco pool success')
}

async function deployStepSwap() {
    let namedSigners = await ethers.getSigners()
    , deployer = namedSigners[0].address

  let e = await _deployMock('Exchanges', { args: [] })
    , p = await _deployMock('PathFinder', { args: [] })
    , s = await _deployMock('SwapFlag', { args: [], })
    , wethAddr = addressOf('WETH')
    , ceth = addressOf('CETH')
    , ctokenFactory = addressOf('CtokenFactory')
    , result = await _deployMock('StepSwap', {
      args: [wethAddr, ceth, ctokenFactory],
      libraries: {
          // DataTypes: d.address,
          Exchanges: e.address,
          PathFinder: p.address,
          SwapFlag: s.address,
      },
      // deterministicDeployment: false, // new Date().toString()
    })

    setContractAddress('StepSwap', result.address)
    console.log('deploy step swap success')
}

// todo: ??????????????????
async function doSettings() {
    const namedSigners = await ethers.getSigners()
    // factory mintFreeAddress


    // ebe ??????
    const ebec = getEbeTokenContract('', namedSigners[0]) // new ethers.Contract(ebe.address, ebe.abi, namedSigners[0])
    await (await ebec.setMinter(addressOf('HecoPool'), true)).wait()
    await (await ebec.setMinter(addressOf('Router'), true)).wait()
    await (await ebec.setMinter(addressOf('SwapMining'), true)).wait()
    
    const routerc = getEbankRouter(addressOf('Router'), namedSigners[0])
    await (await routerc.setRewardToken(ebec.address)).wait()
    console.log('do setting success')
}


// deploy javascript vm env
export async function deployMockContracts(proxy = false) {
    await deployTokens()
    await _deployWHT()
    if (NETWORK !== 'hardhat') {
        console.info('network %s, contracts should be deployed', NETWORK)
        return
    }
    console.info('deploy mock contracts ....')

    await deployCompound()
    await deploySwap()
    await deployOrderBook(proxy)
    await deployEbeHecoPool()
    await deployStepSwap()

    await doSettings()

    console.log('contracts:', dumpAddresses())
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export async function addLiquidityUnderlying(
                        router: Contract,
                        token0: IToken,
                        token1: IToken,
                        _amt0: BigNumberish,
                        _amt1: BigNumberish,
                        to: string
                    ) {
    let amt0 = readableTokenAmount(token0, _amt0)
        , amt1 = readableTokenAmount(token1, _amt1)

    if (token0.address !== zeroAddress) {
        await token0.contract!.approve(router.address, amt0)
    }
    if (token1.address !== zeroAddress) {
        await token1.contract!.approve(router.address, amt1)
    }

    // if (token0.address === zeroAddress || token1.address === zeroAddress) {
    //     throw new Error('todo: not support ht add liquidity')
    // }
    let tx
    if (token0.address === zeroAddress) {
        tx = await router.addLiquidityETHUnderlying(
                    token1.address,
                    amt1,
                    0,
                    0,
                    to,
                    deadlineTs(100),
                    { value: amt0 }
            )
        await tx.wait()
    } else if (token1.address === zeroAddress) {
        // await callWithEstimateGas(router,
        tx = await router.addLiquidityETHUnderlying(
                token0.address,
                amt0,
                0,
                0,
                to,
                deadlineTs(100),
                { value: amt1 }
        )
        await tx.wait()
    } else {
        await callWithEstimateGas(router,
            'addLiquidityUnderlying',
            [
                token0.address,
                token1.address,
                amt0,
                amt1,
                0,
                0,
                to,
                deadlineTs(100)
            ],
            true)
    }
}
