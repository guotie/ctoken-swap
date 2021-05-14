// import { ethers } from 'hardhat'
const hre = require('hardhat')
const ethers = hre.ethers

import { Signer } from 'ethers'
import { network } from 'hardhat'
import sleep from '../utils/sleep'

export interface DeployParams {
  log?: boolean
  baseRatePerYear?: string    // 基础利率
  multiplierPerYear?: string  // 利率乘数
  baseSymbol?: string // price orace 的 baseSymbol
}

export interface ContractAddrAbi {
  abi: any
  address: string
}

// 部署结果
export interface DeployContracts {
  comptroller: ContractAddrAbi
  unitroller: ContractAddrAbi
  interest: ContractAddrAbi
  priceOracle: ContractAddrAbi
  mdexFactory: ContractAddrAbi
  lErc20Delegate: ContractAddrAbi
  lErc20DelegatorFactory: ContractAddrAbi
}

async function getAbiByContractName(name: string) {
  const art = await hre.artifacts.readArtifact(name)
  return art.abi
}

async function _deploy(name: string, opts: any, verify: boolean) {
  const deploy = hre.deployments.deploy

  try {
    let c = await deploy(name, opts)
    if (network.name === 'hecotest' && verify) {
      // do verify
      // 先等一会 否则有可能在链上还看不到合约地址
      await sleep(6000)
      await hre.run('verify:verify', {
        address: c.address,
        constructorArguments: opts.args
      })
    }

    return c
  } catch(err) {
    console.error('deploy %s failed:', name, err)
  }
}
// deploy: hardhat deploy 函数
// verify: 是否需要 verify 合约
export async function deployAll(opts: DeployParams = {}, verify = false): Promise<DeployContracts> {
  const namedSigners = await ethers.getSigners()
  const deployer = namedSigners[0].address
  const log = opts.log === true ? true : false
  // const deploy = hre.deployments.deploy

  // console.log('log:', log)
  let comp = await _deploy('Comptroller', {
    from: deployer,
    args: [],
    log: log,
  }, verify);

  let uni = await _deploy('Unitroller', {
    from: deployer,
    args: [],
    log: log,
  }, verify);

  // 设置 unitroller 的 implement 为 comp.address
  let unitroller = new ethers.Contract(uni.address, uni.abi, namedSigners[0])
  let comptroller = new ethers.Contract(comp.address, comp.abi, namedSigners[0])

  let comptrollerImplementation = await unitroller.comptrollerImplementation()
  if (comptrollerImplementation !== comp.address) {
    console.log('comptroller implemention is %s, set to %s ...', comptrollerImplementation, comp.address)
    await (await unitroller._setPendingImplementation(comp.address)).wait(1)
    // 必须要从 comptroller 中调用 !!!
    // await unitroller.functions._acceptImplementation()
    await (await comptroller._become(uni.address)).wait(1)
  }

  // 利率合约
  const interest = await _deploy('WhitePaperInterestRateModel', {
    from: deployer,
    // 10% 60%
    args: [
        opts.baseRatePerYear ?? '10000000000000000000',
        opts.multiplierPerYear ?? '60000000000000000000'
      ],
    log: log,
  }, verify);
  
  // 价格预言机
  const priceOrace = await _deploy('SimplePriceOracle', {
    from: deployer,
    // 10% 60%
    args: [opts.baseSymbol ?? 'USDT'],
    log: log,
  }, verify);

  // LErc20Delegate erc20 implement
  let lerc20Implement = await _deploy('LErc20Delegate', {
    from: deployer,
    // 
    args: [],
    log: log,
  }, verify);

  let lercFactoryDeployed = await _deploy('LErc20DelegatorFactory', {
    from: deployer,
    // 
    args: [lerc20Implement.address, unitroller.address, interest.address],
    log: log,
  }, verify);

  // mdex pair
  const mdexFactory = await _deploy('MdexFactory', {
    from: deployer,
    // 10% 60%
    args: [namedSigners[0].address, lercFactoryDeployed.address],
    log: log,
  }, verify);

  if (log) {
    console.log('deploy comptroller at: ', comp.address)
    console.log('deploy unitroller at: ', uni.address)
    console.log('deploy interest at: ', interest.address)
    console.log('deploy priceOrace at: ', priceOrace.address)
    console.log('deploy mdexFactory at: ', mdexFactory.address)
    console.log('deploy lerc20Implement at: ', lerc20Implement.address)
    console.log('deploy lerc20DelegatorFactory at: ', lercFactoryDeployed.address)
  }

  return {
    comptroller: { address: comp.address, abi: await getAbiByContractName('Comptroller') },
    unitroller: { address: uni.address, abi: await getAbiByContractName('Unitroller') },
    interest: { address: interest.address, abi: await getAbiByContractName('WhitePaperInterestRateModel') },
    priceOracle: { address: priceOrace.address, abi: await getAbiByContractName('SimplePriceOracle') },
    mdexFactory: { address: mdexFactory.address, abi: await getAbiByContractName('MdexFactory') },
    lErc20Delegate: { address: lerc20Implement.address, abi: await getAbiByContractName('LErc20Delegate') },
    lErc20DelegatorFactory: { address: lercFactoryDeployed.address, abi: await getAbiByContractName('LErc20DelegatorFactory') },
  }
}

// 测试 token USDT, SEA, DOGE, SHIB
export interface Tokens {
  addresses: Map<string, string>
  abi: any
}

// 获取 usdt sea doge 的合约
export async function getTokenContract(addr: string, _signer?: Signer) {
  const signer = await ethers.getSigners()
  const deployer = signer[0].address
  const tokenArt = await hre.artifacts.readArtifact('contracts/common/Token.sol:Token')
  // const factory = await ethers.getContractFactory('Token')
  return ethers.getContractAt(tokenArt.abi, addr, _signer ?? deployer)
}

// ctoken 合约
export async function getCTokenContract(addr: string, _signer?: Signer) {
  const signer = await ethers.getSigners()
  const deployer = signer[0].address
  const tokenArt = await hre.artifacts.readArtifact('contracts/compound/LErc20Delegator.sol:LErc20Delegator')
  // const factory = await ethers.getContractFactory('Token')
  return ethers.getContractAt(tokenArt.abi, addr, _signer ?? deployer)
}

// 部署或查找合约, 返回合约地址
export async function deployTokens(newly = false): Promise<Tokens> {
  // contract info not exist
  const network = hre.network.name
  const tokenArt = await hre.artifacts.readArtifact('contracts/common/Token.sol:Token')
  console.log('deploy tokens to network:', hre.network.name)

  let address: Map<string, string> = new Map();
  if (network === 'hecotest' && newly === false) {
    address.set('USDT', '0x129d417609e58760f5dC16b1fbA54c9CcF2116b6')
    address.set('SEA', '0xEe798D153F3de181dE16DedA318266EE8Ad56dEA')
    address.set('DOGE', '0xA323120A386558ac95203019881C739D3c0A1346')
    address.set('SHIB', '0xf2b80eff2A06f46cA839CA77cCaf32aa820e78D1')
    return {
      addresses: address,
      abi: tokenArt.abi
    }
  }

  const signer = await ethers.getSigners()
  const deployer = signer[0].address
  const factory = await ethers.getContractFactory('Token')
  const supply = '10000000000000000000000000000'

  for (let name of ['USDT', 'SEA', 'DOGE', 'SHIB']) {
    let deployed = await factory.deploy(name, name, supply, deployer)
    address.set(name, deployed.address)
    console.log('deploy ERC20 token: %s %s', name, deployed.address)
    
    if (network === 'hecotest') {
      await sleep(6000)
      await hre.run("verify:verify", {
        address: deployed.address,
        constructorArguments: [name, name, supply, deployer]
      })
    }
  }

  // console.log('token artifacts:', tokenArt.abi)
  return {
    addresses: address,
    abi: tokenArt.abi
  }
}

/*
  let lercFactory = new ethers.Contract(lercFactoryDeployed.address, lercFactoryDeployed.abi, namedSigners[0])

  let usdt = await deploy('Token', {
    from: deployer,
    args: ['USDT', 'USDT', '100000000000000000000000000', deployer]
  })
  console.log('deploy USDT at:', usdt.address)
  let tx = await lercFactory.getCTokenAddress(usdt.address)
  let receipt = await tx.wait(1)
  // 通过 event 来获取得到的地址, 这个只有在 js evm 中才能成功，因为此时每次都会创建, 有对应的evm事件
  // console.log('receipt', tx, receipt)
  const events = receipt.events
  let cUsdt
  if (events[0]) {
    // console.log('events: ', events
    cUsdt = events[0].address
    console.log('createCTokenAddress cUSDT:', cUsdt)
  } else {
    cUsdt = await lercFactory.getCTokenAddressPure(usdt.address)
    console.info('getCTokenAddress cUSDT:', cUsdt)
  }

  let ctoken = await ethers.getContractAt(lerc20Implement.abi, cUsdt, namedSigners[0])
  const total = await ctoken.totalSupply()
  console.log('ctoken totalsupply:', total)
  console.log('mint')
  // evm_mine()
  tx = await ctoken.mint(100000)
  // console.log('mint tx:', tx)
  await tx.wait(1)
*/