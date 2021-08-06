const hre = require('hardhat')

import { deployUniswap } from '../../deployments/deploys'

deployUniswap('0x10')
deployUniswap('0x20')
