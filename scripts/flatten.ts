const hre = require('hardhat')
// const ethers = hre.ethers
import { flattenContract } from '../helpers/flatten'

// flattenContract('Orderbook', './contracts/flatten/Orderbook.sol')
flattenContract('Orderbook', './contracts/flatten/Orderbook.sol')
flattenContract('Factory', './contracts/flatten/Factory.sol')
flattenContract('Router', './contracts/flatten/Router.sol')
flattenContract('StepSwap', './contracts/flatten/StepSwap.sol')
flattenContract('EBEToken', './contracts/flatten/EBEToken.sol')
flattenContract('HecoPool', './contracts/flatten/HecoPool.sol')
flattenContract('SwapMining', './contracts/flatten/SwapMining.sol')


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
