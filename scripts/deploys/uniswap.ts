const hre = require('hardhat')
const ethers = hre.ethers

import { deployUniswap } from '../../deployments/deploys'

(async function() {
    // console.log(hre.config.paths.deployments)
    await deployUniswap('0x10')
    await deployUniswap('0x20')
})()

