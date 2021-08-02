const hre = require('hardhat')

import { deployRouter } from '../../deployments/deploys'
import { getWETH } from './network'

// deploy hecotest contracts

// ctoken factory, ceth, weth, marginAddr, true, true
let factory = ''
    ,ctokenFactory = ''
    , ceth = ''
    // case 'heco':
    //     wht.address = '0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F'
    // case 'hecotest':
    //     wht.address = '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836'
    , weth = getWETH() // '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836'

deployRouter(factory, weth, ceth, ctokenFactory)

