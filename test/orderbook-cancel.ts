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
describe("限价单 cancel order 测试", function() {
    // let deployContracts: DeployContracts
    let namedSigners: SignerWithAddress[]
    // let unitroller: Contract
    let orderbookc: Contract

    let maker: SignerWithAddress
        , taker: SignerWithAddress
        , feeTo: string

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
        orderbookc = getOrderbookContract('', maker)
        console.log('maker address: %s taker address: %s orderbook: %s', maker.address, taker.address, orderbookc.address)
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
            tokenAmt.amountOut.toString(), tokenAmt.amountOutMint.toString(), tokenAmt.fulfiled.toString(), tokenAmt.guaranteeAmountIn.toString())
    }

    const cancelOrder = async (orderId: number) => {
        let order = await orderbookc.orders(orderId)
            , dstToken = order.tokenAmt.destToken  // 我付出的币
            , srcToken = order.tokenAmt.srcToken   // 我得到的币
            , srcEToken = order.tokenAmt.srcEToken
            , to = maker.address

        printOrder(order)

        await printBalance('src token balance before cancel', to, srcToken)
        await printBalance('dst token balance before cancel', to, dstToken)
        await (await orderbookc.cancelOrder(orderId, {gasLimit: 3000000})).wait()
        await printBalance('src token balance after cancel', to, srcToken)
        await printBalance('dst token balance after cancel', to, dstToken)

        let srcBalance = await orderbookc.balanceOf(srcEToken, to)
        console.log('srcEtoken balance of %s: %s', to, srcBalance)
    }

    it('cancel', async () => {
        await cancelOrder(2)
    })

})

