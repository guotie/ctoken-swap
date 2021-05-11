import { HardhatRuntimeEnvironment } from 'hardhat/types';
// import { ethers } from 'ethers'

export default async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer, admin } = await getNamedAccounts();
  // const { deployer, admin } = namedAccounts
  console.info('deployer admin:', deployer, admin)

  await deploy('Token', {
    from: deployer,
    args: ['SEA', 'SEA', '50000000000000000000000000', deployer],
    log: true,
  });
}
