const { expect } = require("chai");
// import { ethers } from 'hardhat'

import { BigNumber, BigNumberish, Contract } from 'ethers'

import contracts, { getContractAt, getContractBy } from '../utils/contracts'
import { getCreate2Address } from '@ethersproject/address'
import { pack, keccak256 } from '@ethersproject/solidity'

import { DeployContracts, deployAll, deployTokens, Tokens, getTokenContract, getCTokenContract } from '../deployments/deploys'
import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { getEbankPair } from '../helpers/contractHelper'

const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

// 测试 create mdex pair
describe("MdexPair 测试", function() {
  let tokens: Tokens
  let namedSigners: SignerWithAddress[]
  let deployer: string
  let buyer: SignerWithAddress

  before(async () => {
    namedSigners = await ethers.getSigners()
    deployer = namedSigners[0].address
    // buyer = namedSigners[1]

    console.log('deployer: %s', deployer)

    if (network.name !== 'hecotest') {
      throw new Error('invalid network, should be hecotest')
    }
  })

  it('mintRewardOf', async () => {
    let pair = '0x91FAB46Fb53E2284978886f0567eD2BF18D9772b'
      , margin = '0x8BDF7Df4b94052aB1c568546f1a303430Dd12ecb'
      , pairc = getEbankPair(pair, namedSigners[0])
      , liquidity = await pairc.balanceOf(margin)
      , lpMinted = await pairc.mintRewardOf(margin)

    console.log('liquidity[%s]: %s', margin, liquidity.toString())
    console.log('mintRewardOf[%s]: %s', margin, lpMinted.toString())
  }) 
})
