const hre = require('hardhat')

import { deployOrderBook } from '../../deployments/deploys'
import { getCETH, getWETH, getCTokenFactory } from './network'

// deploy hecotest contracts

// ctoken factory, ceth, weth, marginAddr, true, true
let ctokenFactory = getCTokenFactory()
    , ceth = getCETH()
    , marginAddr = '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836'
    , weth = getWETH() // '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836'

deployOrderBook(ctokenFactory, ceth, weth, marginAddr, true, true)
