// import { ethers } from 'hardhat'
const hre = require('hardhat')
const ethers = hre.ethers

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

// deploy: hardhat deploy 函数
// verify: 是否需要 verify 合约
export async function deployAll(opts: DeployParams = {}, verify = false): Promise<DeployContracts> {
  const namedSigners = await ethers.getSigners()
  const deployer = namedSigners[0].address
  const log = opts.log === true ? true : false
  const deploy = hre.deployments.deploy

  let comp = await deploy('Comptroller', {
    from: deployer,
    args: [],
    log: log,
  });

  let uni = await deploy('Unitroller', {
    from: deployer,
    args: [],
    log: log,
  });

  // 设置 unitroller 的 implement 为 comp.address
  let unitroller = new ethers.Contract(uni.address, uni.abi, namedSigners[0])
  let comptroller = new ethers.Contract(comp.address, comp.abi, namedSigners[0])

  let comptrollerImplementation = await unitroller.comptrollerImplementation()
  if (comptrollerImplementation !== comp.address) {
    console.log('comptroller implemention is %s, set to %s ...', comptrollerImplementation, comp.address)
    await unitroller.functions._setPendingImplementation(comp.address)
    // 必须要从 comptroller 中调用 !!!
    // await unitroller.functions._acceptImplementation()
    await comptroller.functions._become(uni.address)
  }

  // 利率合约
  const interest = await deploy('WhitePaperInterestRateModel', {
    from: deployer,
    // 10% 60%
    args: [
        opts.baseRatePerYear ?? '10000000000000000000',
        opts.multiplierPerYear ?? '60000000000000000000'
      ],
    log: log,
  });
  
  // 价格预言机
  const priceOrace = await deploy('SimplePriceOracle', {
    from: deployer,
    // 10% 60%
    args: [opts.baseSymbol ?? 'USDT'],
    log: log,
  });

  // LErc20Delegate erc20 implement
  let lerc20Implement = await deploy('LErc20Delegate', {
    from: deployer,
    // 
    args: [],
    log: log,
  });

  let lercFactoryDeployed = await deploy('LErc20DelegatorFactory', {
    from: deployer,
    // 
    args: [lerc20Implement.address, unitroller.address, interest.address],
    log: true,
  });

  // mdex pair
  const mdexFactory = await deploy('MdexFactory', {
    from: deployer,
    // 10% 60%
    args: [namedSigners[0].address, lercFactoryDeployed.address],
    log: log,
  });
  // todo verify contract

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