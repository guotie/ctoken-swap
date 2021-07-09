const hre = require('hardhat')
const ethers = hre.ethers

async function flat(src: string, to: string) {
  // let output = 
  await hre.run("flatten", {
      files: [src],
      output: to
  })

  // console.log(output)
}

flat('contracts/swap/heco/Factory.sol', 'flatten/Facotroy.sol')
flat('contracts/swap/heco/Router.sol', 'flatten/Router.sol')
