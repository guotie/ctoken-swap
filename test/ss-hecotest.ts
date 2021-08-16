const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'
import { getContractAt, getContractBy } from '../utils/contracts'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { AbiCoder } from 'ethers/lib/utils';
import { assert } from 'console';

import { DeployContracts, deployAll, deployTokens, Tokens, zeroAddress, deployStepSwap } from '../deployments/deploys'
import { logHr } from '../helpers/logHr'
import createCToken from './shared/ctoken'
import { getTokenContract, getStepSwapContract, getMdexFactoryContract, getMdexRouterContract } from '../helpers/contractHelper'
import { buildAggressiveSwapTx } from '../helpers/aggressive';
import { deadlineTs, getMockToken, HTToken, IToken, readableTokenAmount } from '../helpers/token';
import { deployMockContracts } from '../helpers/mock';

const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

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

    let usdt: IToken
        , sea: IToken
        , doge: IToken
        , hbtc: IToken
        , ht = HTToken

    let wht: string
        , whtC: Contract
        , ceth: string
        , ctokenFactory: string
        , ctokenFactoryC: Contract
    let s1: Swap = {fa: '0xa61cF1DC3a9D4AE282D7ca60b24B26fd36B7FbeA', fc: undefined, ra: '0x7cE170c33c1D68F564301Fb122946464E9480864', rc: undefined}
        , s2: Swap = {fa: '0x062594B0489F1371F2B5fCde89377A45a0d82308', fc: undefined, ra: '0xadbc10AD6647b9AFc3510B190876cE5a7e1AfFdA', rc: undefined}
    
    let stepSwapC: Contract
        , stepSwapAddr: string
        , stepSwapAbi: any
        // , exLibC: Contract
  
    // e18 是 18位数
    const deploy = hre.deployments.deploy

    this.timeout(60000000);
    before(async () => {
        namedSigners = await ethers.getSigners()
        deployer = namedSigners[0].address
        buyer = namedSigners[1]
        let signer = namedSigners[0]

        usdt = await getMockToken('USDT')
        sea = await getMockToken('SEA')
        doge = await getMockToken('DOGE')
        hbtc = await getMockToken('HBTC')

        s1.fc = getMdexFactoryContract(s1.fa, signer)
        s1.rc = getMdexRouterContract(s1.ra, signer)
        s2.fc = getMdexFactoryContract(s2.fa, signer)
        s2.rc = getMdexRouterContract(s2.ra, signer)

        if (network.name === 'hardhat') {
            await deployMockContracts()
        }
        stepSwapC = getStepSwapContract()
    })

    // it('add liquidity', async () => {
    //     let amt1 = readableTokenAmount(usdt, 1)
    //         , amt2 = readableTokenAmount(sea, 10)
    //     await usdt.contract!.approve(s2.ra, amt1)
    //     await sea.contract!.approve(s2.ra, amt2)
    //     let tx = await s2.rc!.addLiquidity(
    //         usdt.address,
    //         sea.address,
    //         amt1,
    //         amt2,
    //         0,
    //         0,
    //         deployer,
    //         deadlineTs(100),
    //         {gasLimit: 8000000}
    //     )
    //     await tx.wait(1)
    // })

    it('print selector', async () => {
        let selector = stepSwapC.functions['buildSwapRouteSteps']
        console.log(selector)
    })
    // it('add liquidity usdt-hbtc', async () => {
    //     let amt1 = readableTokenAmount(usdt, 1)
    //         , amt2 = readableTokenAmount(hbtc, 10)
    //     await usdt.contract!.approve(s2.ra, amt1)
    //     await hbtc.contract!.approve(s2.ra, amt2)
    //     let tx = await s2.rc!.addLiquidity(
    //         usdt.address,
    //         hbtc.address,
    //         amt1,
    //         amt2,
    //         0,
    //         0,
    //         deployer,
    //         deadlineTs(100),
    //         {gasLimit: 5000000}
    //     )
    //     await tx.wait(1)
    // })
})
