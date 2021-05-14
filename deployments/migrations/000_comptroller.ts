import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ethers } from 'ethers'

import { DeployParams, deployAll, deployTokens } from '../deploys'
import { getContractAt, getContractBy } from '../../utils/contracts'

export default async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  // console.info('hre:', hre)
  const { deploy } = deployments;

  const namedAccounts = await getNamedAccounts();
  const { deployer } = namedAccounts

  const param: DeployParams = {
    log: false,
    baseRatePerYear:   '10000000000000000000',    // 基础利率 10% APY
    multiplierPerYear: '60000000000000000000',  // 利率乘数 60%
    baseSymbol: 'USDT',
  }

  let result = await deployAll(param, false)
  const tokens = await deployTokens()
  const usdt = tokens.addresses.get('USDT')
  console.log('deploy USDT at:', usdt)
  
  let lercFactory = await getContractAt(result.lErc20DelegatorFactory)

  console.log('create cToken for usdt ...')
  let tx = await lercFactory.getCTokenAddress(usdt)
  let receipt = await tx.wait(1)
  const events = receipt.events
  let cUsdt
  if (events[0]) {
    // console.log('events: ', events
    cUsdt = events[0].address
    console.log('createCTokenAddress cUSDT:', cUsdt)
  } else {
    cUsdt = await lercFactory.getCTokenAddressPure(usdt)
    console.info('getCTokenAddress cUSDT:', cUsdt)
  }

  const usdtToken = await getContractBy(tokens.abi, usdt!)
  let ctoken = await getContractBy(result.lErc20Delegate.abi, cUsdt)
  const total = await ctoken.totalSupply()
  console.log('ctoken totalsupply:', total)
  console.log('mint')
  // evm_mine()
  await usdtToken.approve(cUsdt, 100000)
  tx = await ctoken.mint(100000)
  // console.log('mint tx:', tx)
  receipt = await tx.wait(1)
  console.log(receipt.emit())

  /*
  const namedAccounts = await getNamedAccounts();
  const { deployer, admin } = namedAccounts
  console.info('deployer admin:', deployer, admin)
  const namedSigners = await ethers.getSigners()
  // console.info('deployer admin:', deployer, admin)

  let comp = await deploy('Comptroller', {
    from: deployer,
    args: [],
    log: true,
  });

  let uni = await deploy('Unitroller', {
    from: deployer,
    args: [],
    log: true,
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
    args: ['10000000000000000000', '60000000000000000000'],
    log: true,
  });
  
  // 价格预言机
  await deploy('SimplePriceOracle', {
    from: deployer,
    // 10% 60%
    args: ['USDT'],
    log: true,
  });

  // mdex pair
  await deploy('MdexFactory', {
    from: deployer,
    // 10% 60%
    args: [namedSigners[0].address, unitroller.address],
    log: true,
  });

  // LErc20Delegate erc20 implement
  let lerc20Implement = await deploy('LErc20Delegate', {
    from: deployer,
    // 
    args: [],
    log: true,
  });

  let lercFactoryDeployed = await deploy('LErc20DelegatorFactory', {
    from: deployer,
    // 
    args: [lerc20Implement.address, unitroller.address, interest.address],
    log: true,
  });
  */

  // let lercFactory = await getContractAt(result.lErc20DelegatorFactory)

  // let usdt = await deploy('Token', {
  //   from: deployer,
  //   args: ['USDT', 'USDT', '100000000000000000000000000', deployer]
  // })
  // console.log('deploy USDT at:', usdt.address)
  // let tx = await lercFactory.getCTokenAddress(usdt.address)
  // let receipt = await tx.wait(1)
  // 通过 event 来获取得到的地址, 这个只有在 js evm 中才能成功，因为此时每次都会创建, 有对应的evm事件
  // console.log('receipt', tx, receipt)
  // const events = receipt.events
  // let cUsdt
  // if (events[0]) {
  //   // console.log('events: ', events
  //   cUsdt = events[0].address
  //   console.log('createCTokenAddress cUSDT:', cUsdt)
  // } else {
  //   cUsdt = await lercFactory.getCTokenAddressPure(usdt.address)
  //   console.info('getCTokenAddress cUSDT:', cUsdt)
  // }

  // let ctoken = await getContractBy(result.lErc20Delegate.abi, cUsdt)
  // const total = await ctoken.totalSupply()
  // console.log('ctoken totalsupply:', total)
  // console.log('mint')
  // // evm_mine()
  // tx = await ctoken.mint(100000)
  // // console.log('mint tx:', tx)
  // await tx.wait(1)
  
  // console.log('mint receipt:', receipt)
  // await lercFactory.functions.getCTokenAddress('0x592285ED98eE14F947A9f27C121c8c95897615e4')
}

