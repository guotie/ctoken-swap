import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ethers } from 'ethers'

export default async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts, ethers } = hre;
  // console.info('hre:', hre)
  const { deploy } = deployments;

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
  await unitroller.functions._setPendingImplementation(comp.address)
  // 必须要从 comptroller 中调用
  // await unitroller.functions._acceptImplementation()
  await comptroller.functions._become(uni.address)

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

  let lercFactory = new ethers.Contract(lercFactoryDeployed.address, lercFactoryDeployed.abi, namedSigners[0])

  let usdt = await deploy('Token', {
    from: deployer,
    args: ['USDT', 'USDT', '100000000000000000000000000', deployer]
  })
  console.log('deploy USDT at:', usdt.address)
  let cUsdt = await lercFactory.functions.getCTokenAddress(usdt.address)
  console.log('deploy cUSDT at:', cUsdt.to)
  // await lercFactory.functions.getCTokenAddress('0x592285ED98eE14F947A9f27C121c8c95897615e4')
}
