const { expect } = require("chai");

import { BigNumber, Contract } from 'ethers'

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { addressOf, getBalance, getBalances, getCTokenFactoryContract, getEbankFactory, getEbankRouter, getEbeTokenContract, getHecoPollContract, getTokenContract, setContractAddress } from '../helpers/contractHelper'
import { IToken, getMockToken, HTToken, readableTokenAmount } from '../helpers/token';

import { deployHecoPool, deployEbe } from '../deployments/deploys';
import { deployMockContracts, addLiquidityUnderlying } from '../helpers/mock';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

// 测试 swap router
describe("heco pool 测试", function() {
    // let deployContracts: DeployContracts
    let namedSigners: SignerWithAddress[]
    // let unitroller: Contract
    let hecopoolC: Contract
        , ebeC: Contract
    
    let maker: SignerWithAddress
        , taker: SignerWithAddress
    let usdt: IToken
        , sea: IToken
        , wht: IToken
        , ebe: IToken
        , ht = HTToken

    const logHr = (s: string) => console.log('--------------------------  ' + s + '  --------------------------')
  
    this.timeout(60000000);
  
    before(async () => {
        namedSigners = await ethers.getSigners()
        maker = namedSigners[0]
        taker = namedSigners[1]

        await deployMockContracts()

        usdt = await getMockToken('USDT')
        sea = await getMockToken('SEA')
        wht = await getMockToken('WHT')

        hecopoolC = getHecoPollContract(undefined, maker)
        ebeC = getEbeTokenContract(undefined, maker)

        console.log('ebe address:', ebeC.address)
        ebe = {
            address: ebeC.address,
            name: 'EBE',
            symbol: 'EBE',
            totalSupply: BigNumber.from(0),
            decimals: 18,
            contract: ebeC
        }

        // await hecopoolC.add(10, sea.address, true)   // 1
    })

    // it('deposit/withdraw 单币', async () => {
            // await hecopoolC.add(10, usdt.address, true)  // 0
    //     await usdt.contract!.approve(hecopoolC.address, '100000000000000000000000000000')
    //     let tx = await hecopoolC.deposit(0, readableTokenAmount(usdt, 100))
    //     console.log('deposit tx:', tx.blockNumber)
    //     await tx.wait(5)

    //     tx = await hecopoolC.withdraw(0, 100)
    //     console.log('withdraw tx:', tx.blockNumber)
    //     await tx.wait()
    //     let ebeBalance = await getBalance(ebe, maker.address)
    //     console.log('got ebe:', ebeBalance.toString())
    // })

    const getUserPendReward = async (hecopool: string, pid: number, user: string) => {
        let pool = await hecopoolC.poolInfo(pid)
            , lpTokenC = getTokenContract(pool.lpToken, namedSigners[0])
            , lpSupply = await lpTokenC.balanceOf(hecopool)
        let totalAllocPoint = await hecopoolC.totalAllocPoint()
            , blockReward = await hecopoolC.getEbeBlockReward(pool.lastRewardBlock)
            , ebeReward = blockReward.mul(pool.allocPoint).div(totalAllocPoint)
            , accEbePerShare = pool.accEbePerShare.add(ebeReward.mul(1e12).div(lpSupply))
            , userInfo = await hecopoolC.userInfo(pid, user)

        let pendingAmount = userInfo.amount.mul(accEbePerShare).div(1e12).sub(userInfo.rewardDebt);
        return pendingAmount
    }

    it('deposit/withdraw LP', async () => {
        logHr('deposit/withdraw LP')
        let router = getEbankRouter(undefined, namedSigners[0])

        await addLiquidityUnderlying(
                router,
                usdt,
                sea,
                '100',
                '100',
                namedSigners[0].address
            )
        
        let pair = await router.pairFor(usdt.address, sea.address)
        await hecopoolC.add(10, pair, true)  // 1
        let pid = 0

        let ebeBalance = await getBalance(ebe, maker.address)
        console.log('before deposit, ebe:', ebeBalance.toString())

        console.log('LP address:', pair)
        // approve
        let pairc = getTokenContract(pair, namedSigners[0])
        await pairc.approve(hecopoolC.address, '10000000000000000000000000000000')
        let bal = await pairc.balanceOf(namedSigners[0].address)
        console.log('pair LP balance:', bal.toString())
        let tx = await hecopoolC.deposit(pid, bal)
        console.log('deposit tx:', tx.blockNumber)
        await tx.wait(5)

        let amt = await getUserPendReward(hecopoolC.address, 0, namedSigners[0].address)
        console.log('pending reward:', amt.toString())

        tx = await hecopoolC.withdraw(pid, 100)
        console.log('withdraw tx:', tx.blockNumber)
        await tx.wait()
        ebeBalance = await getBalance(ebe, maker.address)
        console.log('got ebe:', ebeBalance.toString())
    })

})
