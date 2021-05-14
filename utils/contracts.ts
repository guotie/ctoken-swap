// 获取合约部署地址 abi
import { Contract } from 'ethers'
import { ContractAddrAbi } from '../deployments/deploys'
import { readFileSync } from "fs"

const hre = require('hardhat')
const ethers = hre.ethers // from '@nomiclabs/hardhat-ethers'

function getDeployedContractInfoByName(network: string, name: string) {
  // path.join()
  let fn = './deployments/artifacts/' + network + '/' + name + '.json'
  let data = readFileSync(fn, 'utf-8')
  let json = JSON.parse(data)
  return {address: json.address, abi: json.abi}
}

// 根据 ContractAddrAbi 来构建 Contract
export async function getContractAt(addrAbi: ContractAddrAbi): Promise<Contract> {
  const signer = await ethers.getSigners()
  return await ethers.getContractAt(addrAbi.abi, addrAbi.address, signer[0])
}

export async function getContractBy(abi: any, addr: string): Promise<Contract> {
  const signer = await ethers.getSigners()
  return await ethers.getContractAt(abi, addr, signer[0])
}

export default {
  getDeployedContractInfoByName,
}