const hre = require('hardhat')

import { ethers } from 'ethers'
import { deployEbe } from '../../deployments/deploys'
import { deployHecoPool } from '../../deployments/deploys'

(async function () {
    const namedSigners = await hre.ethers.getSigners()
    const ebe = await deployEbe()
    const hecopool = await deployHecoPool(ebe.address, 10, 0)
    const ebeC = new ethers.Contract(ebe.address, ebe.abi, namedSigners[0])

    await ebeC.setMinter(hecopool.address, true)
})()
