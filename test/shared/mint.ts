// ctoken mint
const hre = require('hardhat')
const ethers = hre.ethers

import { ContractAddrAbi } from '../../deployments/deploys'

export default async (cont: ContractAddrAbi, ctoken: string) => {
  const namedSigners = await ethers.getSigners()
  let c = new ethers.Contract(cont.address, cont.abi, namedSigners[0])
}