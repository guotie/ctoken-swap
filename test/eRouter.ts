const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'


import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { addressOf, getBalances, getCTokenFactoryContract, getEbankFactory, getEbankRouter } from '../helpers/contractHelper'
import { IToken, getMockToken, HTToken, readableTokenAmount, deadlineTs, getPairToken } from '../helpers/token';
import { callWithEstimateGas } from '../helpers/estimateGas';
import { deployMockContracts } from '../helpers/mock';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

// 测试 swap router
describe("Router 测试", function() {
    // let deployContracts: DeployContracts
    let namedSigners: SignerWithAddress[]
    // let unitroller: Contract
    let delegatorFactory: Contract
        , mdexFactory: Contract
        , router: Contract
        , factory: Contract
    let maker: SignerWithAddress
        , taker: SignerWithAddress
    let usdt: IToken
        , sea: IToken
        , wht: IToken
        , eUsdt: IToken
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
        delegatorFactory = getCTokenFactoryContract(addressOf('CtokenFactory'), maker)
        router = getEbankRouter(undefined, maker)

        let cfactory = await router.ctokenFactory()
        factory = getEbankFactory()

        usdt = await getMockToken('USDT')
        sea = await getMockToken('SEA')
        wht = await getMockToken('WHT')

        console.info('contracts: router=%s factory=%s', router.address, factory.address)
    })

    const printBalance = async (title: string, owner: string, tokens: IToken[]) => {
        console.info(title)
        let balances = await getBalances(tokens, owner)
        for (let i = 0; i < tokens.length; i ++) {
            let token = tokens[i]
            console.info('    %s balance: %s', token.name, balances[i].toString())
        }
    }

    it('add Liquidity underlying: usdt/sea', async () => {
        await printBalance('Balance ' + maker.address + ' before add liquidity', maker.address, [usdt, sea])
        await usdt.contract!.approve(router.address, BigNumber.from('10000000000000000000000000000'))
        await sea.contract!.approve(router.address, BigNumber.from('10000000000000000000000000000'))
        let tx = await callWithEstimateGas(
                router,
                'addLiquidityUnderlying',
                // tokenA,
                // address tokenB,
                // uint amountADesired,
                // uint amountBDesired,
                // uint amountAMin,
                // uint amountBMin,
                // address to,
                // uint deadline
                [
                    usdt.address,
                    sea.address,
                    readableTokenAmount(usdt, 3),
                    readableTokenAmount(sea, 200),
                    0,
                    0,
                    maker.address,
                    deadlineTs(100)
                ],
                true
            )
        // console.log('tx:', tx)
        await tx.wait(0)
        let pair = await factory.pairFor(usdt.address, sea.address)
            , pairToken = await getPairToken(pair)
        await printBalance('Balance ' + maker.address + ' after add liquidity', maker.address, [usdt, sea, pairToken])
    })
})

