const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'

import { getContractAt, getContractBy, getContractByNameAddr } from '../utils/contracts'

import { DeployContracts, deployAll, deployTokens, Tokens, getTokenContract, getCTokenContract, deployWHT } from '../deployments/deploys'
import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { assert } from 'console';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

// 测试 ctoken mint
describe("ctoken mint 测试", function() {
  const logHr = (s: string) => console.log('--------------------------  ' + s + '  --------------------------')

  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')
  
  this.timeout(600000);

  before(async () => {
    expect(network.name).to.eq('hecotest')
  })

  it('mint', async () => {
    expect(network.name).to.eq('hecotest')

  })
})