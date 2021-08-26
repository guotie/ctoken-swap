const hre = require('hardhat')
// const ethers = hre.ethers
const ethers = hre.ethers

import deploy from './deploy'
import { BigNumberish, BigNumber } from 'ethers'
import { e18, addressOf, setContractAddress, getEbeTokenContract } from './contractHelper'
import { zeroAddress } from '../deployments/deploys'

// eth/bsc/heco/hecotest 链部署

const deterministic = true // '0x' + Math.ceil(new Date().getTime()).toString(16).slice(0, 8)
console.log('opts.deterministicDeployment:', deterministic)

async function _deploy(name: string, opts: any) {
    const networkName = hre.network.name
    if (networkName === 'hardhat') {
        throw new Error('network should NOT be hardhat')
    }

    let namedSigners = await ethers.getSigners()

    opts.from = namedSigners[0].address
    opts.log = true
    // opts.deterministicDeployment = deterministic

    return deploy(name, opts, networkName !== 'hardhat')
}

// 平台币
async function deployEBE() {
    const result = await _deploy('contracts/flatten/EBEToken.sol:EBEToken', { args: [] });

    setContractAddress('EBEToken', result.address)
    return result
}

// 部署  factory  router swapmining hecopool
async function deploySwap() {
    let usdt = addressOf('USDT')
        , wht = addressOf('WHT')
        , ceth = addressOf('CETH')
        , ctokenFactory = addressOf('CtokenFactory')
        , namedSigners = await ethers.getSigners()

    const factory = await _deploy('contracts/flatten/Factory.sol:DeBankFactory', {
        // 10% 60% 稳定币 usdt 地址
        args: [ usdt ],
      });
    setContractAddress('Factory', factory.address)
    
    const router = await _deploy('contracts/flatten/Router.sol:DeBankRouter', {
        // factory wht lht startBlock
        args: [factory.address, wht, ceth, ctokenFactory],
      })
    setContractAddress('Router', router.address)

    // SwapExchangeRate
    const rate = await _deploy('contracts/flatten/Router.sol:SwapExchangeRate', { args: []} )
    setContractAddress('SwapExchangeRate', rate.address)

    // set factory router !!!
    let fc = new ethers.Contract(factory.address, factory.abi, namedSigners[0])
    await fc.setRouter(router.address)
    console.log('set factory router address success')

    // let rc = new ethers.Contract(router.address, router.abi, namedSigners[0])
    // console.info('router factory:', await rc.factory())
}

export async function deployHecoPool(ebe: string, ebePerBlock: number, startBlock: number) {
    const e18 = BigNumber.from('1000000000000000000')
        , result = await _deploy('contracts/flatten/HecoPool.sol:HecoPool', {
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
    
    let swapMining = await _deploy('contracts/flatten/SwapMining.sol:SwapMining', { args: [ebe, router, perBlock, 0] })
        // , c = new ethers.Contract(swapMining.address, swapMining.abi, namedSigners[0])
    setContractAddress('SwapMining', swapMining.address)
}

async function deployEbeHecoPool() {
    // let namedSigners = await ethers.getSigners()
        // , deployer = namedSigners[0].address
    
    let ebe = await deployEBE()
    await deployHecoPool(ebe.address, 10, 0)

    // 每个块 80 个
    await deploySwapMining(BigNumber.from(80).mul(e18))
}

// 聚合器
async function deployStepSwap() {
    // let namedSigners = await ethers.getSigners()
    // , deployer = namedSigners[0].address

  let e = await _deploy('contracts/flatten/StepSwap.sol:Exchanges', { args: [] })
    , p = await _deploy('contracts/flatten/StepSwap.sol:PathFinder', { args: [] })
    , s = await _deploy('contracts/flatten/StepSwap.sol:SwapFlag', { args: [], })
    , wethAddr = addressOf('WETH')
    , ceth = addressOf('CETH')
    , ctokenFactory = addressOf('CtokenFactory')
    , result = await _deploy('contracts/flatten/StepSwap.sol:StepSwap', {
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
}

// todo: 完成一些设置
async function doSettings() {
    const namedSigners = await ethers.getSigners()
    // factory mintFreeAddress


    // ebe 设置
    const ebec = getEbeTokenContract('', namedSigners[0]) // new ethers.Contract(ebe.address, ebe.abi, namedSigners[0])
    await (await ebec.setMinter(addressOf('HecoPool'), true)).wait()
    await ebec.setMinter(addressOf('Router'), true)
    await ebec.setMinter(addressOf('SwapMining'), true)
}

// 挂单合约
async function deployOrderBook() {
    let l = await _deploy('contracts/flatten/OrderBook.sol:OBPriceLogic', { args: [] })
    let c = await _deploy('contracts/flatten/OrderBook.sol:OBPairConfig', { args: [] })
    let ctokenFactory = addressOf('CtokenFactory')
        , ceth = addressOf('CETH')
        , weth = addressOf('WHT')
        , margin = zeroAddress

    let ob = await _deploy('contracts/flatten/OrderBook.sol:OrderBook', {
        args: [ctokenFactory, ceth, weth, margin],
        libraries: {
            OBPriceLogic: l.address,
            OBPairConfig: c.address
        },
    });

    setContractAddress('OrderBook', ob.address)
    return ob
}

export {
    deployEBE,
    deployEbeHecoPool,
    deploySwap,
    deployOrderBook,
    deployStepSwap,
    doSettings,
}
