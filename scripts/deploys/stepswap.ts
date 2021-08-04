const hre = require('hardhat')

import { deployStepSwap } from '../../deployments/deploys'
import { getCETH, getCTokenFactory, getWETH } from './network'

// deploy hecotest contracts

// ctoken factory, ceth, weth, marginAddr, true, true
let ceth = getCETH()
    , weth = getWETH() // '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836'
    , ctokenFactory = getCTokenFactory()

deployStepSwap(weth, ceth, ctokenFactory, true, true)

