// 为 token 创建 ctoken
const hre = require('hardhat')
const ethers = hre.ethers

import { ContractAddrAbi } from '../../deployments/deploys'

export default async function createCToken(factory: ContractAddrAbi, token: string) {
  const namedSigners = await ethers.getSigners()
  // const deployer = namedSigners[0].address

  // 设置 unitroller 的 implement 为 comp.address
  let c = new ethers.Contract(factory.address, factory.abi, namedSigners[0])
  return await c.getCTokenAddress(token)
}
