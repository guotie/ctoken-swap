const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'
import { getContractAt, getContractBy } from '../utils/contracts'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { AbiCoder } from 'ethers/lib/utils';
import { assert } from 'console';

import { DeployContracts, deployAll, deployTokens, Tokens, zeroAddress, deployStepSwap } from '../deployments/deploys'
import { logHr } from '../helpers/logHr'
import createCToken from './shared/ctoken'
import { getTokenContract, getCTokenContract, getProvider, getContractByAddressName, getStepSwapContract } from '../helpers/contractHelper'
import { buildAggressiveSwapTx } from '../helpers/aggressive';

const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network
const ht = zeroAddress

// console.log('provider:', ethers.provider)

const e18 = BigNumber.from('1000000000000000000')

interface Swap {
    fa: string   // factory address
    fc?: Contract // factory contract
    ra: string   // router address
    rc?: Contract // router contract
}

// 测试 swap pair
describe("聚合交易测试", function() {

    let tokens: Tokens
    let deployContracts: DeployContracts
    let namedSigners: SignerWithAddress[]
    let unitroller: Contract
    let delegatorFactory: Contract
    let ebankFactory: Contract
    let ebankRouter: Contract
    // let pairABI: any
    let deployer: string
    let buyer: SignerWithAddress

    let wht: string
        , whtC: Contract
        , ceth: string
        , ctokenFactory: string
        , ctokenFactoryC: Contract
    let s1: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
        , s2: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
        , s3: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
    
    let stepSwapC: Contract
  
    // e18 是 18位数
    const e18 = BigNumber.from('1000000000000000000')

    const SwapReserveRates = [
          {
            "internalType": "bool",
            "name": "isEToken",
            "type": "bool"
          },
          {
            "internalType": "bool",
            "name": "allowBurnchi",
            "type": "bool"
          },
          {
            "internalType": "bool",
            "name": "allEbank",
            "type": "bool"
          },
          {
            "internalType": "uint256",
            "name": "ebankAmt",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "amountIn",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "swapRoutes",
            "type": "uint256"
          },
          {
            "internalType": "address",
            "name": "tokenIn",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "tokenOut",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "etokenIn",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "etokenOut",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "routes",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "rateIn",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "rateOut",
            "type": "uint256"
          },
          {
            "internalType": "uint256[]",
            "name": "fees",
            "type": "uint256[]"
          },
          {
            "components": [
              {
                "internalType": "uint256",
                "name": "exFlag",
                "type": "uint256"
              },
              {
                "internalType": "address",
                "name": "contractAddr",
                "type": "address"
              }
            ],
            "internalType": "struct DataTypes.Exchange[]",
            "name": "exchanges",
            "type": "tuple[]"
          },
          {
            "internalType": "address[][]",
            "name": "paths",
            "type": "address[][]"
          },
          {
            "internalType": "address[][]",
            "name": "cpaths",
            "type": "address[][]"
          },
          {
            "internalType": "uint256[][][]",
            "name": "reserves",
            "type": "uint256[][][]"
          },
          {
            "internalType": "uint256[]",
            "name": "distributes",
            "type": "uint256[]"
          }
        ]
    //     "internalType": "struct DataTypes.SwapReserveRates",
    //     "name": "params",
    //     "type": "tuple"
    //   }
    // ]

    before(async () => {
      stepSwapC = getStepSwapContract(undefined, namedSigners[0])
      const abi = new AbiCoder()
      abi.encode(SwapReserveRates, [])
    })
})
