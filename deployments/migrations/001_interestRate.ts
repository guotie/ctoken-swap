import { HardhatRuntimeEnvironment } from 'hardhat/types';

export default async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  // console.info('hre:', hre)
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  await deploy('WhitePaperInterestRateModel', {
    from: deployer,
    args: ['10000000000000000000', '60000000000000000000'],
    log: true,
  });
}
