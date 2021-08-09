const hre = require('hardhat')

import { deployEbe } from '../../deployments/deploys'
import { deployHecoPool } from '../../deployments/deploys'

(async function () {
    const ebe = await deployEbe()
    deployHecoPool(ebe.address, 10, 0)
})()
