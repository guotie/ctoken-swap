import { HardhatRuntimeEnvironment } from 'hardhat/types';

export default async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  // console.info('hre:', hre)
  const { deploy } = deployments;

//   const namedAccounts = await getNamedAccounts();
//   const { deployer, admin } = namedAccounts
//   console.info('deployer admin:', deployer, admin)
  const namedSigners = await hre.ethers.getSigners()
    , deployer = namedSigners[0].address
  console.info('deployer:', deployer)

  await deploy('contracts/flatten/Router.sol:SwapExchangeRate', {
    from: deployer,
    args: [],
    log: true,
  });

}


// verify
// npx hardhat verify --network hecotest 0xE6bAb8701d48Fe85Ec5B8a0FCe45AF98b1442965 0x49d531908840FDDaC744543d57CB21B91c3D9094