const hre = require('hardhat')
// const ethers = hre.ethers
import { flattenContract } from '../helpers/flatten'

// flattenContract('Orderbook', './deploy/Orderbook.sol')
flattenContract('Orderbook', './deploy/Orderbook.sol')
flattenContract('Factory', './deploy/Factory.sol')
flattenContract('Router', './deploy/Router.sol')
flattenContract('StepSwap', './deploy/StepSwap.sol')
flattenContract('EBEToken', './deploy/EBEToken.sol')
flattenContract('HecoPool', './deploy/HecoPool.sol')
flattenContract('SwapMining', './deploy/SwapMining.sol')


// async function flat(src: string, to: string) {
//   // let output = 
//   await hre.run("flatten", {
//       files: [src],
//       output: to
//   })

//   // console.log(output)
// }

// flat('contracts/swap/heco/Factory.sol', 'flatten/Facotroy.sol')
// flat('contracts/swap/heco/Router.sol', 'flatten/Router.sol')
