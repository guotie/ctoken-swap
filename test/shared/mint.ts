// ctoken mint
const hre = require('hardhat')
const ethers = hre.ethers

import { ContractAddrAbi } from '../../deployments/deploys'

// cont should be LErc20Delegator
export default async function getLErc20DelegatorContract(cont: ContractAddrAbi, ctoken: string) {
  const namedSigners = await ethers.getSigners()
  return new ethers.Contract(ctoken, cont.abi, namedSigners[0])
}
