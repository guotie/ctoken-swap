const { expect } = require("chai");
import { ethers } from 'hardhat'

import contracts from '../utils/contracts'
import sleep from '../utils/sleep';

// 测试 create mdex pair
describe("CreateMdexPair", function() {
  it("Should create mdex pair", async function() {
    const namedSigners = await ethers.getSigners()
    let {address, abi} = contracts.getDeployedContractInfoByName('hecotest', 'MdexFactory')
    let pairContract = contracts.getDeployedContractInfoByName('hecotest', 'MdexFactory')
    const factory = await ethers.getContractAt(abi, address, namedSigners[0])
    // const pair = await ethers.getContractAt(pairContract.abi, '0x521BA82F08D7e68D594E4359bFB3cabC8b351e41', namedSigners[0])

    const Token = await ethers.getContractFactory('Token')
    const usdt = await Token.deploy('USDT', 'USDT', '100000000000000000000000000', namedSigners[0].address)
    await usdt.deployed();
    const sea = await Token.deploy('SEA', 'SEA', '100000000000000000000000000', namedSigners[0].address)
    await sea.deployed();

    console.info('USDT:', usdt.address, 'SEA:', sea.address)
    // await factory.createPair('0x810Fa002935933f33De2Cd8653b46668397Dc3e1', '0x592285ED98eE14F947A9f27C121c8c95897615e4')
    let addr = await factory.pairFor(usdt.address, '0x592285ED98eE14F947A9f27C121c8c95897615e4')
    console.info('pair for address:', addr)
    // pair.mint(namedSigners[0].address)
    // await greeter.setGreeting("Hola, mundo!");
    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});
