const hre = require('hardhat')
const ethers = hre.ethers

import { deployFactory, deployRouter } from '../../deployments/deploys'
import { getWETH, getCTokenFactory, getCETH, getUSDT } from './network'
import { deployEbe } from '../../deployments/deploys'
import { deployHecoPool, deploySwapMining } from '../../deployments/deploys'

// deploy hecotest contracts

(async function() {
    let usdt = getUSDT()
        , weth = getWETH()
        , ceth = getCETH()
        , ctokenFactory = getCTokenFactory()
        , namedSigners = await ethers.getSigners()

    let factoryResult = await deployFactory(usdt)
    let routerResult = await deployRouter(factoryResult.address, weth, ceth, ctokenFactory)

    // set factory's router
    let factoryC = new ethers.Contract(factoryResult.address, factoryResult.abi, namedSigners[0])
    await factoryC.setRouter(routerResult.address)

    // 
    const ebe = await deployEbe()
    const hecopool = await deployHecoPool(ebe.address, 10, 0)
    const minter = await deploySwapMining(ebe.address, routerResult.address, '10000000000000000000') // 100

    const ebeC = new ethers.Contract(ebe.address, ebe.abi, namedSigners[0])
    await ebeC.setMinter(hecopool.address, true)
    await ebeC.setMinter(routerResult.address, true)
    await ebeC.setMinter(minter.address, true)
})()

// ctoken factory, ceth, weth, marginAddr, true, true
 // '0x04F535663110A392A6504839BEeD34E019FdB4E0'
// let factory = ''
//     ,ctokenFactory = getCTokenFactory()
//     , ceth = getCETH()
//     // case 'heco':
//     //     wht.address = '0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F'
//     // case 'hecotest':
//     //     wht.address = '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836'
//     , weth = getWETH() // '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836'

// deployRouter(factory, weth, ceth, ctokenFactory)

