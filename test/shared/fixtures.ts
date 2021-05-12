import { ethers } from 'hardhat'

const hre = require('hardhat')
// 测试 token USDT, SEA, DOGE, SHIB
export interface Tokens {
  addresses: Map<string, string>
  abi: any
}

// 部署或查找合约, 返回合约地址
export async function deployTokens(): Promise<Tokens> {
  // contract info not exist
  // const network = hre.network.name
  console.log('deploy tokens to network:', hre.network.name)

  const signer = await ethers.getSigners()
  const deployer = signer[0].address
  const factory = await ethers.getContractFactory('Token')
  const supply = '10000000000000000000000000000'
  let address: Map<string, string> = new Map();

  for (let name of ['USDT', 'SEA', 'DOGE', 'SHIB']) {
    let deployed = await factory.deploy(name, name, supply, deployer)
    address.set(name, deployed.address)
  }

  const tokenArt = await hre.artifacts.readArtifact('contracts/common/Token.sol:Token')
  // console.log('token artifacts:', tokenArt.abi)
  return {
    addresses: address,
    abi: tokenArt.abi
  }
}
