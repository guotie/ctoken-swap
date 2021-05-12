const { expect } = require("chai");
import { ethers } from 'hardhat'

import contracts from '../utils/contracts'
import { deployTokens, Tokens } from './shared/fixtures'
import { DeployContracts, deployAll } from '../deployments/deploys'
import createCToken from './shared/ctoken'
// const hre = require('hardhat')

// 测试 create mdex pair
describe("MdexPair", function() {
  let tokens: Tokens
  let deployContracts: DeployContracts

  before(async () => {
    deployContracts = await deployAll()
    tokens = await deployTokens()
    // console.log('deploy contracts', deployTokens())
  })

  it("create mdex pair", async function() {
    const namedSigners = await ethers.getSigners()
    // let {address, abi} = contracts.getDeployedContractInfoByName('hecotest', 'MdexFactory')
    // let pairContract = contracts.getDeployedContractInfoByName('hecotest', 'MdexFactory')
    const deployedFactory = deployContracts.mdexFactory
    // console.info('deployedFactory:', deployedFactory)
    const factory = await ethers.getContractAt(deployedFactory.abi, deployedFactory.address, namedSigners[0])
    // const pair = await ethers.getContractAt(pairContract.abi, '0x521BA82F08D7e68D594E4359bFB3cabC8b351e41', namedSigners[0])

    // const Token = await ethers.getContractFactory('Token')
    // const usdt = await Token.deploy('USDT', 'USDT', '100000000000000000000000000', namedSigners[0].address)
    // await usdt.deployed();
    // const sea = await Token.deploy('SEA', 'SEA', '100000000000000000000000000', namedSigners[0].address)
    // await sea.deployed();

    const usdt = tokens.addresses.get('USDT')
      , sea = tokens.addresses.get('SEA')

    console.info('USDT:', usdt, 'SEA:', sea)
    expect(usdt).to.not.be.empty
    await createCToken(deployContracts.lErc20DelegatorFactory, usdt!)
    await createCToken(deployContracts.lErc20DelegatorFactory, sea!)

    // await factory.createPair('0x810Fa002935933f33De2Cd8653b46668397Dc3e1', '0x592285ED98eE14F947A9f27C121c8c95897615e4')
    let addr = await factory.pairFor(usdt, sea)
    console.info('pair for address:', addr)
    // pair.mint(namedSigners[0].address)
    // await greeter.setGreeting("Hola, mundo!");
    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });

  it('mint', async () => {

  });
});
