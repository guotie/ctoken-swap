const hre = require('hardhat')

import { ethers } from 'ethers'
import { deployEbe } from '../../deployments/deploys'
import { deployHecoPool, deploySwapMining } from '../../deployments/deploys'

(async function () {
    const namedSigners = await hre.ethers.getSigners()
    const ebe = await deployEbe()
    const hecopool = await deployHecoPool(ebe.address, 10, 0)
    const ebeC = new ethers.Contract(ebe.address, ebe.abi, namedSigners[0])

    await ebeC.setMinter(hecopool.address, true)

    const minter = await deploySwapMining(ebe.address, '', '10000000000000000000') // 100
    await ebeC.setMinter(minter.address, true)
})()
