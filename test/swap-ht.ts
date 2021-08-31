const { expect } = require("chai");
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, Contract } from 'ethers'
import { getEbankFactory, getEbankRouter, getCTokenFactoryContract, getSwapExchangeRateContract, addressOf } from '../helpers/contractHelper';
import { deployMockContracts } from '../helpers/mock';

// 测试 swap pair
describe("swap ht 测试", function() {
  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')
  let fc: Contract
    , rc: Contract
    , hc: Contract
    , ctokenFc: Contract
    , owner: SignerWithAddress

  before(async () => {
        const namedSigners = await hre.ethers.getSigners()
        owner = namedSigners[0]
        if (hre.network.name === 'hardhat') {
            await deployMockContracts()
        }

        fc = getEbankFactory(undefined, owner)
        rc = getEbankRouter(undefined, owner)
        hc = getSwapExchangeRateContract(undefined, owner)
        ctokenFc = getCTokenFactoryContract(undefined, owner)
  })

  it('getAmountOutMin', async ()=> {
      let amtIn = '1000000000000000'
        , wht = addressOf('WHT')   // 0x7af326b6351c8a9b8fb8cd205cbe11d4ac5fa836
        , usdt = addressOf('USDT') // 0x04f535663110a392a6504839beed34e019fdb4e0
        , feeRate = 30

        let { amountOut } = await hc.getAmountsOutUnderlying(fc.address, ctokenFc.address, amtIn, [wht, usdt], owner.address)
        console.log('amtOut:', amountOut.toString())

        let rateA = await hc.getCurrentExchangeRate(addressOf('CETH'))
        console.log('rate wht: %s', rateA.toString())

        let {reserveA, reserveB} = await fc.getReserves(wht, usdt)
        console.log('pair wht/usdt reserves: %s %s', reserveA.toString(), reserveB.toString())

        let out1 = await fc.getAmountOutFeeRate(amtIn, reserveA, reserveB, feeRate)
            , out2 = await fc.getAmountOutFeeRateAnchorToken(amtIn, reserveA, reserveB, feeRate)

        console.log('out1: %s out2: %s', out1.toString(), out2.toString())
  })
})
