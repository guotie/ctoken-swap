// import { ethers } from 'hardhat'
const hre = require('hardhat')
const ethers = hre.ethers

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, Contract, Signer } from 'ethers'
import { network } from 'hardhat'
import sleep from '../utils/sleep'
import { getCreate2Address } from '@ethersproject/address'
import { pack, keccak256 } from '@ethersproject/solidity'
import { assert } from 'console'
import { addressOf } from '../helpers/contractHelper';
// import { getContract } from 'hardhat-deploy-ethers/dist/src/helpers'

export interface DeployParams {
  log?: boolean
  baseRatePerYear?: string    // 基础利率
  multiplierPerYear?: string  // 利率乘数
  baseSymbol?: string         // price orace 的 baseSymbol
  anchorToken?: string        // usdt地址, 用于将手续费兑换为usdt
  addresses?: string[]        // 需要生成 ctoken 的 token数组
}

export interface ContractAddrAbi {
  abi: any
  address: string
}

// 部署结果
export interface DeployContracts {
  comptroller: ContractAddrAbi
  unitroller: ContractAddrAbi
  interest: ContractAddrAbi
  priceOracle: ContractAddrAbi
  mdexFactory: ContractAddrAbi
  lErc20Delegate: ContractAddrAbi
  lErc20DelegatorFactory: ContractAddrAbi
  WHT: ContractAddrAbi
  cWHT: ContractAddrAbi
  router: ContractAddrAbi
  orderbook?: ContractAddrAbi
  onesplit?: ContractAddrAbi
  unoswapRouter?: ContractAddrAbi
}

// wETH 的地址
let wETH: Contract;

export async function getAbiByContractName(name: string) {
  const art = await hre.artifacts.readArtifact(name)
  return art.abi
}

export async function _deploy(name: string, opts: any, verify: boolean) {
  const deploy = hre.deployments.deploy

  try {
    let c = await deploy(name, opts)
    // newlyDeployed 是否是新部署
    if (network.name === 'hecotest' && verify && c.newlyDeployed) {
      // do verify
        try {
            // 先等一会 否则有可能在链上还看不到合约地址
            console.log('verify %s at %s:', name, c.address)
            await sleep(6500)
            await hre.run('verify:verify', {
              address: c.address,
              constructorArguments: opts.args
            })
        } catch (err) {
            console.log('verify failed', err)
        }
    }

    return c
  } catch(err) {
    console.error('deploy %s failed:', name, err)
  }
}

export async function deployStepSwap(
                        wethAddr: string,
                        ceth: string,
                        _ctokenFactory: string,
                        // signer: SignerWithAddress,
                        log: boolean,
                        verify: boolean
                      ) {
  
  let namedSigners = await ethers.getSigners()
    , deployer = namedSigners[0].address

  let e = await _deploy('Exchanges', {
              from: deployer,
              args: [],
              log: log,
          }, verify)

  let p = await _deploy('PathFinder', {
              from: deployer,
              args: [],
              log: log,
          }, false)

  let s = await _deploy('SwapFlag', {
              from: deployer,
              args: [],
              log: log
          }, false)
  let result = await _deploy('StepSwap', {
      from: deployer,
      args: [wethAddr, ceth, _ctokenFactory],
      log: log,
      libraries: {
          // DataTypes: d.address,
          Exchanges: e.address,
          PathFinder: p.address,
          SwapFlag: s.address,
      },
      // deterministicDeployment: false, // new Date().toString()
    }, verify)

  // let exLibC = new ethers.Contract(e.address, e.abi, signer)
  let stepSwapC = new ethers.Contract(result.address, result.abi, namedSigners[0])
  console.log('deploy StepSwap:', stepSwapC.address)
  return {
      abi: result.abi,
      stepSwapC: stepSwapC,
      address: result.address,
    }
}

export async function deployEbe() {
  let namedSigners = await ethers.getSigners()
      , deployer = namedSigners[0].address

  return _deploy('EBEToken', {
        from: deployer,
        //
        args: [],
        log: true,
      }, network.name !== 'hardhat');
}

export async function deployHecoPool(ebe: string, ebePerBlock: number, startBlock: number) {
  let namedSigners = await ethers.getSigners()
      , deployer = namedSigners[0].address

  const e18 = BigNumber.from('1000000000000000000')
  return _deploy('HecoPool', {
        from: deployer,
        args: [ ebe, BigNumber.from(ebePerBlock).mul(e18), startBlock ],
        log: true,
      }, network.name !== 'hardhat');
}

export async function deploySwapMining(ebe: string, router: string, perBlock: string) {
  let namedSigners = await ethers.getSigners()
      , deployer = namedSigners[0].address
  
  return _deploy('SwapMining', {
          from: deployer,
          args: [ebe, router, perBlock, 0]
        }, network.name !== 'hardhat')
      // , c = new ethers.Contract(swapMining.address, swapMining.abi, namedSigners[0])
  // setContractAddress('SwapMining', swapMining.address)
}

export async function deployUniswap(salt: string) {
  let namedSigners = await ethers.getSigners()
    , deployer = namedSigners[0].address

  // console.log('deployer: %s salt: %s', deployer, salt)
  let dr = await _deploy('MdexFactory', {
      from: deployer,
      args: [deployer],
      log: true,
      deterministicDeployment: salt, //
  }, true)
  let fc = new ethers.Contract(dr.address, dr.abi, namedSigners[0])

  let wht = addressOf('WHT')
  let router = await _deploy('MdexRouter', {
      from: deployer,
      args: [dr.address, wht],
      log: true,
      deterministicDeployment: salt, //
  }, true)
  let rc = new ethers.Contract(router.address, router.abi, namedSigners[0])

  console.log('deployed factory/router: salt=%s %s %s', salt, dr.address, router.address)
  return { fa: dr.address, fc: fc, ra: router.address, rc: rc}
}


export async function deployFactory(usdt: string) {
  let namedSigners = await ethers.getSigners()
      , deployer = namedSigners[0].address

  return await _deploy('DeBankFactory', {
    from: deployer,
    // 10% 60% 稳定币 usdt 地址
    args: [ usdt],
    // args: [namedSigners[0].address, lercFactoryDeployed.address, anchorToken],
    log: true,
  }, true);
}

export async function deployRouter(
                factory: string,
                wht: string,
                lht: string,
                ctokenFactory: string
              ) {
  let namedSigners = await ethers.getSigners()
      , deployer = namedSigners[0].address

  const router = await _deploy('DeBankRouter', {
    from: deployer,
    // factory wht lht startBlock
    args: [factory, wht, lht, ctokenFactory],
    // libraries: { 'ExchangeRate': exchangeRateLib.address },
    log: true
  }, true)

  return router
}

// 部署 OrderBook
export async function deployOrderBook(
                        ctokenFactory: string,
                        _ceth: string,
                        _weth: string,
                        _margin: string,
                        log: any,
                        verify: any
                      ) {
  let namedSigners = await ethers.getSigners()
      , deployer = namedSigners[0].address

  let l = await _deploy('OBPriceLogic', {
                      from: deployer,
                      args: [],
                      log: log,
                  }, false)
  let c = await _deploy('OBPairConfig', {
                      from: deployer,
                      args: [],
                      log: log,
                  }, false)
  console.log('deploy OBPriceLogic at:', l.address)
  return _deploy('OrderBook', {
      from: deployer,
      args: [ctokenFactory, _ceth, _weth, _margin],
      libraries: {
          OBPriceLogic: l.address,
          OBPairConfig: c.address
      },
      log: log,
    }, verify);
}

export async function deployWHT(signer: any, log: boolean, verify: boolean): Promise<Contract> {
    let dr = await _deployWHT(signer.address, log, verify)

    wETH = new ethers.Contract(dr.address, dr.abi, signer)
    return wETH
}

export async function _deployWHT(deployer: any, log: any, verify: any): Promise<ContractAddrAbi> {
  let wht: ContractAddrAbi = {address: '', abi: await getAbiByContractName('WHT')}

  switch (network.name) {
    case 'hardhat':
      // deploy wht
      let dr = await _deploy('WHT', {
          from: deployer,
          //
          args: [],
          log: log
        }, verify)
      wht.address = dr.address
      break;

    case 'heco':
      wht.address = '0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F'
      break;

    case 'hecotest':
      wht.address = '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836'
      break

    default:
      // heco mainnet
      wht.address = '0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F'
  }

  console.warn('network name: %s wht address: %s', network.name, wht.address)
  return wht
}

interface StableToken {
  decimals: number
  totalSupply: number  // 总发行量 单位个 无精度
  name: string
}

function decimalPrecsion(decimal: number) {
  let precision = BigNumber.from('1')

  for (let i = 0; i < decimal; i ++) {
    precision = precision.mul(10)
  }
  return precision
}

function totalSupplyWithDecimals(token: StableToken) {
  let precision = decimalPrecsion(token.decimals)

  return precision.mul(token.totalSupply)
}

export async function deployStableCoin(factory: Contract, token: StableToken, deployer: any) {
  return factory.deploy(token.name, token.name, totalSupplyWithDecimals(token), deployer, token.decimals)
}

export async function deployStablePair() {
  const namedSigners = await ethers.getSigners()
  const deployer = namedSigners[0].address

  const factory = await ethers.getContractFactory('Token')
  // const supply = BigNumber.from('100000000')
  const tokens = {
    USDT: { decimals: 6, totalSupply: 10000000, name: 'USDT' },
    USDC: { decimals: 18, totalSupply: 10000000, name: 'USDC' },
    DAI: { decimals: 18, totalSupply: 10000000, name: 'DAI' },
  }

  let usdt = await deployStableCoin(factory, tokens['USDT'], deployer) // factory.deploy(tokens['USDT'].name, tokens['USDT'].name, totalSupplyWithDecimals(tokens['USDT']), deployer, tokens['USDT'].decimals)
  let dai = await deployStableCoin(factory, tokens['DAI'], deployer)  // factory.deploy(tokens['DAI'].name, tokens['DAI'].name, totalSupplyWithDecimals(tokens['DAI']), deployer, tokens['DAI'].decimals)

  let stable = await _deploy('StablePair', {
      from: deployer,
      // tokenA tokenB A fee precision0, precision1
      args: [usdt.address, dai.address, 800, 4000000, decimalPrecsion(tokens['USDT'].decimals), decimalPrecsion(tokens['DAI'].decimals)],
      log: true
    }, true)

  const tokenArt = await hre.artifacts.readArtifact('contracts/common/Token.sol:Token')
    , stableArt = await hre.artifacts.readArtifact('StablePair')
  return {
    usdt: usdt,
    usdtC: await ethers.getContractAt(tokenArt.abi, usdt.address, deployer),
    dai: dai,
    daiC: await ethers.getContractAt(tokenArt.abi, dai.address, deployer),
    stable: stable,
    stableC: await ethers.getContractAt(stableArt.abi, stable.address, deployer),
  }
}

// deploy: hardhat deploy 函数
// verify: 是否需要 verify 合约
export async function deployAll(opts: DeployParams = {}, verify = false): Promise<DeployContracts> {
  const namedSigners = await ethers.getSigners()
  const deployer = namedSigners[0].address
  const log = opts.log === true ? true : false
  // const deploy = hre.deployments.deploy

  // console.log('log:', log)
  let comp = await _deploy('Comptroller', {
    from: deployer,
    args: [],
    log: log,
  }, verify);

  // console.log('log:', log)
  let compv2 = await _deploy('ComptrollerV2', {
    from: deployer,
    args: [],
    log: log,
  }, verify);

  let uni = await _deploy('Unitroller', {
    from: deployer,
    args: [],
    log: log,
  }, verify);

  // 设置 unitroller 的 implement 为 comp.address
  let unitroller = new ethers.Contract(uni.address, uni.abi, namedSigners[0])
  let comptroller = new ethers.Contract(comp.address, comp.abi, namedSigners[0])
  let comptrollerv2 = new ethers.Contract(compv2.address, compv2.abi, namedSigners[0])
  let methods = ["0x3e3158d7","0x27efe3cb","0x26634e4c","0x1d3a86df","0xa29e154d","0xc1abfaa3","0xd7f4f30f","0x929fe9a1","0x31975b69","0xabfceffc","0x9d1b5a0a","0x1e80e9e4","0x2f52e595","0x007e3dd2","0x7df0f767","0xaf0801b6","0x8708ec63"]
    , addr = ["1","1","1","1","1","1","1","1","1","1","1","1","1","1","1","1","1"]

    await (await unitroller._setMethodId(methods, addr)).wait()
    await (await unitroller._setImplementation(0, comp.address)).wait()
    await (await unitroller._setImplementation(1, compv2.address)).wait()
  /*
  let comptrollerImplementation = await unitroller.comptrollerImplementation()
  if (comptrollerImplementation !== comp.address) {
    console.log('comptroller implemention is %s, set to %s ...', comptrollerImplementation, comp.address)
    await (await unitroller._setPendingImplementation(comp.address)).wait(1)
    // 必须要从 comptroller 中调用 !!!
    // await unitroller.functions._acceptImplementation()
    await (await comptroller._become(uni.address)).wait(1)
  }
  */

  // 利率合约
  const interest = await _deploy('WhitePaperInterestRateModel', {
    from: deployer,
    // 10% 60%
    args: [
        opts.baseRatePerYear ?? '1000000000000000000',
        opts.multiplierPerYear ?? '6000000000000000000'
      ],
    log: log,
  }, verify);
  
  // 价格预言机
  // const priceOrace = await _deploy('SimplePriceOracle', {
  //   from: deployer,
  //   // 10% 60%
  //   args: [opts.baseSymbol ?? 'USDT'],
  //   log: log,
  // }, verify);

  // LErc20Delegate erc20 implement
  let lerc20Implement = await _deploy('LErc20Delegate', {
    from: deployer,
    // 
    args: [],
    log: log,
  }, verify);

  let lht = await _deploy('LHT', {
    from: deployer,
    // comptroller_ interestRateModel_ initialExchangeRateMantissa_ name_ symbol_ decimals_ admin_
    args: [unitroller.address, interest.address, '15000000000000000000', 'WHT', 'WHT', 18, namedSigners[0].address],
    log: log,
  }, verify);

  //
  console.log('list markt LHT ...', lht.address)
  // let cunitroller = await ethers.getContractAt(unitroller.abi, unitroller.address, namedSigners[0]);
  await comptrollerv2._supportMarket(zeroAddress, lht.address)
  // let listed = await comptroller.markets(lht.address)
  // console.log('listed:', listed.isListed)

  let lercFactoryDeployed = await _deploy('LErc20DelegatorFactory', {
    from: deployer,
    // 
    args: [], // [lerc20Implement.address, unitroller.address, interest.address],
    log: log,
  }, verify);
  let ctokenFactoryc = new ethers.Contract(lercFactoryDeployed.address, lercFactoryDeployed.abi, namedSigners[0])
  // await ()

  let wht = await _deployWHT(deployer, log, verify)
  wETH = new ethers.Contract(wht.address, wht.abi, namedSigners[0])

  // 设置 wht lht 对应关系
  const cf = await ethers.getContractAt(lercFactoryDeployed.abi, lercFactoryDeployed.address, namedSigners[0])
  await cf.addNewCToken(wht.address, lht.address)

  if (opts.addresses) {
    await deployCTokens(lercFactoryDeployed.address, opts.addresses, deployer)
  }

  // mdex pair
  const anchorToken = opts.anchorToken ?? '0x04F535663110A392A6504839BEeD34E019FdB4E0'
  console.log('mdex anchor token:', anchorToken)
  const mdexFactory = await _deploy('DeBankFactory', {
    from: deployer,
    // 10% 60% 稳定币 usdt 地址
    args: [ anchorToken],
    // args: [namedSigners[0].address, lercFactoryDeployed.address, anchorToken],
    log: log,
  }, verify);

  // const exchangeRateLib = await _deploy('ExchangeRate', {
  //       from: deployer,
  //       args: [],
  //       log: log,
  //     }, verify)
  const router = await _deploy('DeBankRouter', {
    from: deployer,
    // factory wht lht startBlock
    args: [mdexFactory.address, wht.address, lht.address, lercFactoryDeployed.address],
    // libraries: { 'ExchangeRate': exchangeRateLib.address },
    log: log
  }, verify)

  // mdexFactory 设置 router 地址
  const mdexFactoryCont = new ethers.Contract(mdexFactory.address, mdexFactory.abi, namedSigners[0])
  await mdexFactoryCont.setRouter(router.address)

  const obPriceLogic = await _deploy('OBPriceLogic', {
    from: deployer,
    args: [],
    log: log
  }, verify)

  console.log('deploy OBPriceLogic at:', obPriceLogic.address)

  // const orderbook = await _deploy('OrderBook', {
  //   from: deployer,
  //   args: [lercFactoryDeployed.address, lht.address, wht.address, zeroAddress],
  //   libraries: { 'OBPriceLogic': obPriceLogic.address },
  //   log: log
  // }, verify)

  // const onesplit = await _deploy('OneSplit', {
  //   from: deployer,
  //   args: [wht.address, lercFactoryDeployed.address],
  //   log: log,
  // }, verify)

  // const unoswapRouter = await _deploy('UnoswapRouter', {
  //   from: deployer,
  //   args: [wht.address, lercFactoryDeployed.address],
  //   log: log
  // }, verify)

  /////////////////////////////////////////////////////////////////////////////////////////////////////
  // deploy bank margin
  // 1. deploy margin goblin 每个交易对一个 goblin， MdxStrategyAddTwoSidesOptimal
  // 2. deploy bank
  // 3. 上架 bank product, 配置 goblin
  //
  /////////////////////////////////////////////////////////////////////////////////////////////////////

  if (log) {
    console.log('contract WHT at:', wht.address)
    console.log('deploy comptroller at: ', comp.address)
    console.log('deploy unitroller at: ', uni.address)
    console.log('deploy interest at: ', interest.address)
    console.log('deploy priceOrace at: ', '')
    console.log('deploy mdexFactory at: ', mdexFactory.address)
    console.log('deploy lerc20Implement at: ', lerc20Implement.address)
    console.log('deploy lerc20DelegatorFactory at: ', lercFactoryDeployed.address)
    console.log('deploy CETH at: ', lht.address)
    console.log('deploy router at: ', router.address)
    // console.log('deploy onesplit at: ', onesplit.address)
    // console.log('deploy orderbook at: ', orderbook.address)
    // console.log('deploy unoswapRouter at: ', unoswapRouter.address)
  }

  return {
    comptroller: { address: comp.address, abi: await getAbiByContractName('Comptroller') },
    unitroller: { address: uni.address, abi: await getAbiByContractName('Unitroller') },
    interest: { address: interest.address, abi: await getAbiByContractName('WhitePaperInterestRateModel') },
    priceOracle: { address: zeroAddress, abi: await getAbiByContractName('SimplePriceOracle') },
    mdexFactory: { address: mdexFactory.address, abi: await getAbiByContractName('DeBankFactory') },
    lErc20Delegate: { address: lerc20Implement.address, abi: await getAbiByContractName('LErc20Delegate') },
    WHT: wht,
    cWHT: { address: lht.address, abi: await getAbiByContractName('LHT')},
    lErc20DelegatorFactory: { address: lercFactoryDeployed.address, abi: await getAbiByContractName('LErc20DelegatorFactory') },
    router: { address: router.address, abi: await getAbiByContractName('DeBankRouter') },
    // orderbook: { address: orderbook.address, abi: await getAbiByContractName('OrderBook') },
    // onesplit: { address: onesplit.address, abi: await getAbiByContractName('OneSplit') },
    // unoswapRouter: { address: unoswapRouter.address, abi: await getAbiByContractName('UnoswapRouter') },
  }
}

export const zeroAddress = '0x0000000000000000000000000000000000000000'

// 测试 token USDT, SEA, DOGE, SHIB
export interface Tokens {
  addresses: Map<string, string>
  abi: any
}

export function setWEth(c: Contract) {
  wETH = c
}

export function getWETH(): Contract {
  return wETH
}

// 获取 usdt sea doge 的合约
export async function getTokenContract(addr: string, _signer?: Signer) {
    assert(wETH !== undefined, "wETH not initialized")

    if (addr === wETH.address) {
      console.log('return wht token !!!')
      return wETH
    }

  const signer = await ethers.getSigners()
  const deployer = signer[0].address
  const tokenArt = await hre.artifacts.readArtifact('contracts/common/Token.sol:Token')
  // const factory = await ethers.getContractFactory('Token')
  return ethers.getContractAt(tokenArt.abi, addr, _signer ?? deployer)
}

// ctoken 合约
export async function getCTokenContract(addr: string, _signer?: Signer) {
  const signer = await ethers.getSigners()
  const deployer = signer[0].address
  const tokenArt = await hre.artifacts.readArtifact('contracts/compound/LErc20Delegator.sol:LErc20Delegator')
  // const factory = await ethers.getContractFactory('Token')
  return ethers.getContractAt(tokenArt.abi, addr, _signer ?? deployer)
}

// 计算 ctoken 地址
export async function calcCTokenAddress(factory: string, token: string) {
  const INIT_CODE_HASH = '0x71a762e9b044ae662a0d792ceaa9aaa4bf09c9ecdd90967035ae11e75f841390'

  return getCreate2Address(
    factory,
    keccak256(['bytes'], [pack(['address'], [token])]),
    INIT_CODE_HASH
  )
}

export async function deployCTokens(factoryAddr: string, addresses: string[], deployer: any) {
  let abi = await getAbiByContractName('LErc20DelegatorFactory')
    , ctokenFactory = await ethers.getContractAt(abi, factoryAddr, deployer)

  for (let addr of addresses) {
    await ctokenFactory.getCTokenAddress(addr)
  }
}

export async function deployToken(name: string, supply: BigNumber, decimals = 18) {
  const signer = await ethers.getSigners()
  const deployer = signer[0].address
  const factory = await ethers.getContractFactory('Token')

  let deployed = await factory.deploy(name, name, supply, deployer, decimals)
  console.info('deploy mock token:', name, deployed.address)
  // let c = new ethers.Contract(deployed.address, deployed.abi, signer[0])
  return {
    name: name,
    symbol: name,
    decimals: decimals,
    totalSupply: supply,
    address: deployed.address,
    contract: deployed,
  }
}

// 部署或查找合约, 返回合约地址
export async function deployTokens(newly = false): Promise<Tokens> {
  // contract info not exist
  // const network = hre.network.name
  const tokenArt = await hre.artifacts.readArtifact('contracts/common/Token.sol:Token')
  console.log('deploy tokens to network:', hre.network.name)

  let address: Map<string, string> = new Map();
  // todo 更新地址
  if (network.name === 'hecotest' && newly === false) {
    address.set('USDT', '0x04F535663110A392A6504839BEeD34E019FdB4E0')
    address.set('SEA', '0xEe798D153F3de181dE16DedA318266EE8Ad56dEA')
    address.set('DOGE', '0xA323120A386558ac95203019881C739D3c0A1346')
    address.set('SHIB', '0xf2b80eff2A06f46cA839CA77cCaf32aa820e78D1')
    return {
      addresses: address,
      abi: tokenArt.abi
    }
  }

  const signer = await ethers.getSigners()
  const deployer = signer[0].address
  const factory = await ethers.getContractFactory('Token')
  const supply = '10000000000000000000000000000'

  for (let name of ['USDT', 'SEA', 'DOGE', 'SHIB']) {
    let deployed = await factory.deploy(name, name, supply, deployer, 18)
    address.set(name, deployed.address)
    console.log('deploy ERC20 token: %s %s', name, deployed.address)
    
    if (network.name === 'hecotest') {
      await sleep(6000)
      await hre.run("verify:verify", {
        address: deployed.address,
        constructorArguments: [name, name, supply, deployer]
      })
    }
  }

  // console.log('token artifacts:', tokenArt.abi)
  return {
    addresses: address,
    abi: tokenArt.abi
  }
}

/*
  let lercFactory = new ethers.Contract(lercFactoryDeployed.address, lercFactoryDeployed.abi, namedSigners[0])

  let usdt = await deploy('Token', {
    from: deployer,
    args: ['USDT', 'USDT', '100000000000000000000000000', deployer]
  })
  console.log('deploy USDT at:', usdt.address)
  let tx = await lercFactory.getCTokenAddress(usdt.address)
  let receipt = await tx.wait(1)
  // 通过 event 来获取得到的地址, 这个只有在 js evm 中才能成功，因为此时每次都会创建, 有对应的evm事件
  // console.log('receipt', tx, receipt)
  const events = receipt.events
  let cUsdt
  if (events[0]) {
    // console.log('events: ', events
    cUsdt = events[0].address
    console.log('createCTokenAddress cUSDT:', cUsdt)
  } else {
    cUsdt = await lercFactory.getCTokenAddressPure(usdt.address)
    console.info('getCTokenAddress cUSDT:', cUsdt)
  }

  let ctoken = await ethers.getContractAt(lerc20Implement.abi, cUsdt, namedSigners[0])
  const total = await ctoken.totalSupply()
  console.log('ctoken totalsupply:', total)
  console.log('mint')
  // evm_mine()
  tx = await ctoken.mint(100000)
  // console.log('mint tx:', tx)
  await tx.wait(1)
*/