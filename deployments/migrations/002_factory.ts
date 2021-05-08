import { HardhatRuntimeEnvironment } from 'hardhat/types';
// import { ethers } from 'ethers'

export default async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  // console.info('hre:', hre)
  const { deploy } = deployments;

  const namedAccounts = await getNamedAccounts();
  const { deployer, admin } = namedAccounts
  console.info('deployer admin:', deployer, admin)
  // const namedSigners = await ethers.getSigners()
  // console.info('deployer admin:', deployer, admin)

  await deploy('MdexFactory', {
    from: deployer,
    args: [deployer, ''],
    log: true,
  });

  // let uni = await deploy('Unitroller', {
  //   from: deployer,
  //   args: [],
  //   log: true,
  // });

  // // 设置 unitroller 的 implement 为 comp.address
  // let unitroller = new ethers.Contract(uni.address, uni.abi, namedSigners[0])
  // await unitroller.functions._setPendingImplementation(comp.address)
  // await unitroller.functions._acceptImplementation()
}


// verify
// npx hardhat verify --network hecotest 0xE6bAb8701d48Fe85Ec5B8a0FCe45AF98b1442965 0x49d531908840FDDaC744543d57CB21B91c3D9094