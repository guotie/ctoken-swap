const hre = require('hardhat')
// const ethers = hre.ethers
const ethers = hre.ethers

import deploy from './deploy'
import { BigNumberish, BigNumber } from 'ethers'
import { e18, addressOf, setContractAddress } from './contractHelper'
import { zeroAddress } from '../deployments/deploys'

// eth/bsc/heco/hecotest 链部署


async function _deploy(name: string, opts: any) {
    const networkName = hre.network.name
    if (networkName === 'hardhat') {
        throw new Error('network should NOT be hardhat')
    }

    let namedSigners = await ethers.getSigners()

    opts.from = namedSigners[0].address
    opts.log = true

    return deploy(name, opts, networkName !== 'hardhat')
}

// 平台币
async function deployEBE() {
    const result = await _deploy('EBEToken', { args: [] });

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

    const factory = await _deploy('DeBankFactory', {
        // 10% 60% 稳定币 usdt 地址
        args: [ usdt ],
      });
    setContractAddress('Factory', factory.address)
    
    const router = await _deploy('DeBankRouter', {
        // factory wht lht startBlock
        args: [factory.address, wht, ceth, ctokenFactory],
      })
    setContractAddress('Router', router.address)

    // SwapExchangeRate
    const rate = await _deploy('SwapExchangeRate', { args: []} )
    setContractAddress('SwapExchangeRate', rate.address)

    // set factory router !!!
    let fc = new ethers.Contract(factory.address, factory.abi, namedSigners[0])
    await fc.setRouter(router.address)

    let rc = new ethers.Contract(router.address, router.abi, namedSigners[0])
    console.info('router factory:', await rc.factory())
}

export async function deployHecoPool(ebe: string, ebePerBlock: number, startBlock: number) {
    const e18 = BigNumber.from('1000000000000000000')
        , result = await _deploy('HecoPool', {
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
    
    let swapMining = await _deploy('SwapMining', { args: [ebe, router, perBlock, 0] })
        // , c = new ethers.Contract(swapMining.address, swapMining.abi, namedSigners[0])
    setContractAddress('SwapMining', swapMining.address)
}

async function deployEbeHecoPool() {
    let namedSigners = await ethers.getSigners()
        // , deployer = namedSigners[0].address
    
    let ebe = await deployEBE()
    let pool = await deployHecoPool(ebe.address, 10, 0)
    let ebec = new ethers.Contract(ebe.address, ebe.abi, namedSigners[0])
    await ebec.setMinter(pool.address, true)

    // 每个块 80 个
    await deploySwapMining(BigNumber.from(80).mul(e18))

    await ebec.setMinter(addressOf('Router'), true)
    await ebec.setMinter(addressOf('SwapMining'), true)
}

// 聚合器
async function deployStepSwap() {
    let namedSigners = await ethers.getSigners()
    , deployer = namedSigners[0].address

  let e = await _deploy('Exchanges', { args: [] })
    , p = await _deploy('PathFinder', { args: [] })
    , s = await _deploy('SwapFlag', { args: [], })
    , wethAddr = addressOf('WETH')
    , ceth = addressOf('CETH')
    , ctokenFactory = addressOf('CtokenFactory')
    , result = await _deploy('StepSwap', {
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

// 挂单合约
async function deployOrderBook() {
    let l = await _deploy('OBPriceLogic', { args: [] })
    let c = await _deploy('OBPairConfig', { args: [] })
    let ctokenFactory = addressOf('CtokenFactory')
        , ceth = addressOf('CETH')
        , weth = addressOf('WHT')
        , margin = zeroAddress

    let ob = await _deploy('OrderBook', {
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
    deploySwap,
    deployOrderBook,
    deployStepSwap,
}
