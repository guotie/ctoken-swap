// ctoken mint
const hre = require('hardhat')
const ethers = hre.ethers

import { ContractAddrAbi } from '../../deployments/deploys'

// cont should be LErc20Delegator
export default async (cont: ContractAddrAbi, ctoken: string) => {
  const namedSigners = await ethers.getSigners()
  let c = new ethers.Contract(cont.address, cont.abi, namedSigners[0])
}