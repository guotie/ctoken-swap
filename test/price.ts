const { expect } = require("chai");
import { ethers } from 'hardhat'

import contracts from '../utils/contracts'
import sleep from '../utils/sleep';

// 每次都部署一次合约
// describe("SimplePriceOracle", function() {
  // it("Should return the new price which is set by setDirectPrice", async function() {
  //   // const Greeter = await ethers.getContractFactory("SimplePriceOracle");
  //   // const greeter = await Greeter.deploy("USDT");
    
  //   // await greeter.deployed();
  //   // const priceOracle = '0x265d834016a67ffcb7390ee90c6620a3ba5201ec';
  //   const namedSigners = await ethers.getSigners()
  //   let {address, abi} = contracts.getDeployedContractInfoByName('hecotest', 'SimplePriceOracle')
  //   const greeter = await ethers.getContractAt(abi, address, namedSigners[0])
  //   const priceNew = '511'
  //   await greeter.setDirectPrice('0x49d531908840FDDaC744543d57CB21B91c3D9094', priceNew)

  //   // await sleep(6000)
  //   // 奇怪的问题 每次获取的价格是上一次设置的价格!!! 当 sleep 足够长的时间时, 可以获取到设置的价格
  //   let price = await greeter.assetPrices('0x49d531908840FDDaC744543d57CB21B91c3D9094')
  //   console.log('price.eq 1: ', price.eq(ethers.BigNumber.from(150000001)), price.eq(ethers.BigNumber.from(priceNew)))
  //   expect(price).to.eq(ethers.BigNumber.from(priceNew))
  //   // expect(false).to.be.true
  //   console.info('get price:', price.toString())
  //   // expect(await greeter.greet()).to.equal("Hello, world!");

  //   // await greeter.setGreeting("Hola, mundo!");
  //   // expect(await greeter.greet()).to.equal("Hola, mundo!");
  // });
// });
