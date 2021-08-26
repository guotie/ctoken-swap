const hre = require('hardhat')
const ethers = hre.ethers

import sleep from '../utils/sleep'

const network = hre.network

async function deploy(name: string, opts: any, verify: boolean) {
    const deploy = hre.deployments.deploy
  
    try {
      let c = await deploy(name, opts)
      // newlyDeployed 是否是新部署
      if (network.name === 'hecotest' && verify && c.newlyDeployed) {
        // do verify
          try {
              // 先等一会 否则有可能在链上还看不到合约地址
              console.log('verify %s at %s:', name, c.address)
              await sleep(6500)
              await hre.run('verify:verify', {
                address: c.address,
                contract: name,
                constructorArguments: opts.args
              })
          } catch (err) {
              console.log('verify failed', err)
          }
      }
  
      return c
    } catch(err) {
      console.error('deploy %s failed:', name, err)
    }
}

export default deploy

