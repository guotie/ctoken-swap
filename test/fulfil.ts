const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'


import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { addressOf, getBalance, getBalances, getOrderbookContract, getTokenContract } from '../helpers/contractHelper'
import { IToken, getMockToken, HTToken, readableTokenAmount, deadlineTs, getPairToken } from '../helpers/token';
import { callWithEstimateGas } from '../helpers/estimateGas';
import { deployMockContracts } from '../helpers/mock';
import { getCTokenContract } from '../deployments/deploys';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

// 测试 swap router
describe("限价单 fulfil 测试", function() {
    // let deployContracts: DeployContracts
    let namedSigners: SignerWithAddress[]
    // let unitroller: Contract
    let orderbookc: Contract

    let maker: SignerWithAddress
        , taker: SignerWithAddress
        , feeTo: string

    let usdt: IToken
        , sea: IToken
        , wht: IToken
        , eusdt: IToken
        , eSea: IToken
        , eWht: IToken
        , ht = HTToken

    const logHr = (s: string) => console.log('--------------------------  ' + s + '  --------------------------')
  
    // e18 是 18位数
    const e18 = BigNumber.from('1000000000000000000')
    
    this.timeout(60000000);
  
    before(async () => {
        if (network.name === 'hecotest') {
            // throw new Error('should test in hecotest')
            console.info('network hecotest ....')
        } else if (network.name === 'hardhat') {
            // deploy all contracts here
            await deployMockContracts()
        } else {
            throw new Error('invalid network: ' + network.name)
        }

        let namedSigners = await ethers.getSigners()
        maker = namedSigners[0]
        taker = namedSigners[1]
        console.log('maker address: %s taker address: %s', maker.address, taker.address)

        orderbookc = getOrderbookContract('', maker)
    })

    const printBalances = async (title: string, owner: string, tokens: IToken[] | string[]) => {
        console.info(title)
        let balances = await getBalances(tokens, owner)
        for (let i = 0; i < tokens.length; i ++) {
            let token = tokens[i]
            console.info('    %s balance: %s', typeof token === 'string' ? token : token.name, balances[i].toString())
        }
    }

    const printBalance = async (title: string, owner: string, token: IToken | string) => {
        console.info(title, ' owner: ', owner)
        let balance = await getBalance(token, owner)
        console.info('    %s balance: %s', typeof token === 'string' ? token : token.name, balance.toString())
    }

    const printOrder = (order: any) => {
        let tokenAmt = order.tokenAmt
        console.info('    orderId=%d srcToken=%s dstToken=%s srcEToken=%s dstEToken=%s\n    amountIn=%s amountInMinted=%s fulfiled=%s expectOut=%s\n',
            order.orderId, tokenAmt.srcToken, tokenAmt.destToken, tokenAmt.srcEToken, tokenAmt.destEToken,
            tokenAmt.amountIn.toString(), tokenAmt.amountInMint.toString(), tokenAmt.fulfiled.toString(), tokenAmt.guaranteeAmountIn.toString())
    }
    const fulfilOrder = async (orderId: number, amtIn: BigNumberish) => {
        let order = await orderbookc.orders(orderId)
            , dstToken = order.tokenAmt.destToken  // 我付出的币
            , srcToken = order.tokenAmt.srcToken   // 我得到的币
            , srcEToken = order.tokenAmt.srcEToken
            , cDstToken = getTokenContract(dstToken, maker)
            , to = maker.address

        printOrder(order)

        await printBalance('src token balance before fulfil', to, srcToken)
        await printBalance('dst token balance before fulfil', to, dstToken)
        await (await cDstToken.approve(orderbookc.address, amtIn)).wait()
        await (await orderbookc.fulfilOrder(orderId, amtIn, to, true, true, [])).wait()
        await printBalance('src token balance after fulfil', to, srcToken)
        await printBalance('dst token balance after fulfil', to, dstToken)

        let srcBalance = await orderbookc.balanceOf(srcEToken, to)
        console.log('srcEtoken balance of %s: %s', to, srcBalance)
    }

    it('fulfil', async () => {
        await fulfilOrder(7, '5000000')
    })

})

