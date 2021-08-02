const hre = require('hardhat')

import { deployFactory } from '../../deployments/deploys'
import { getUSDT } from './network'

// deploy hecotest contracts

// ctoken factory, ceth, weth, marginAddr, true, true
let usdt = getUSDT() // '0x04F535663110A392A6504839BEeD34E019FdB4E0'

deployFactory(usdt)
