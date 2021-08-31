const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'

import { getContractAt, getContractBy } from '../utils/contracts'
// import { getCreate2Address } from '@ethersproject/address'
// import { pack, keccak256 } from '@ethersproject/solidity'

// import { DeployContracts, deployAll, deployTokens, Tokens, getTokenContract, getCTokenContract } from '../deployments/deploys'
import { deployMockContracts } from '../helpers/mock'
import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { getMockToken, HTToken, IToken } from '../helpers/token';
import { getEbankFactory, getEbankRouter } from '../helpers/contractHelper';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

const e18 = BigNumber.from('1000000000000000000')

// 测试 swap pair
describe("ctoken swap 测试", function() {
  // let tokens: Tokens
  // let deployContracts: DeployContracts
  let namedSigners: SignerWithAddress[]
  // let unitroller: Contract
  // let delegatorFactory: Contract
  let mdexFactory: Contract
  let router: Contract
  let pairABI: any
  let deployer: string
  let buyer: SignerWithAddress
  let usdt: IToken
    , sea: IToken
    , doge: IToken
    , ht = HTToken

  // let cusdt: string
  // let csea: string
  // let cdoge: string

  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')

  before(async () => {
    namedSigners = await ethers.getSigners()
    deployer = namedSigners[0].address
    buyer = namedSigners[1]

    console.log('deployer: %s buyer: %s', deployer, buyer.address)

    await deployMockContracts()
    usdt = await getMockToken('USDT')
    sea = await getMockToken('SEA')
    doge = await getMockToken('DOGE')

    mdexFactory = getEbankFactory(undefined, namedSigners[0])
    router = getEbankRouter('', namedSigners[0])
    // const pairArt = await hre.artifacts.readArtifact('contracts/swap/heco/Factory.sol:MdexPair')
    // pairABI = pairArt.abi

    // create ctoken
    // usdt = tokens.addresses.get('USDT')!
    // sea = tokens.addresses.get('SEA')!
    // doge = tokens.addresses.get('DOGE')!

    console.info('USDT:', usdt.address, 'SEA:', sea.address)
    expect(usdt).to.not.be.empty
    expect(sea).to.not.be.empty
    // await expect(createCToken(deployContracts.lErc20DelegatorFactory, usdt))
      // .to.emit(delegatorFactory, 'NewDelegator').withArgs(delegatorFactory, '0x340d6d7ea30fb8fcc82d906d0232eb65243b0b87')
      // .to.emit(unitroller, 'MarketListed') //.withArgs(usdt, '')
    // let tx = await createCToken(deployContracts.lErc20DelegatorFactory, sea)

    // const delegatorFactoryContract = await getCon
    // cusdt = await delegatorFactory.getCTokenAddressPure(usdt)
    // console.log('cusdt address:', cusdt)
    // csea = await delegatorFactory.getCTokenAddressPure(sea)
    // console.log('csea address:', csea)

    // await tx.wait(2)

    // create pair
    // await createPair(usdt, sea)
    // await createPair(doge, sea)
  })

  // create pair
  const createPair = async (tokenA: string, tokenB: string) => {
    let tx = await mdexFactory.createPair(tokenA, tokenB)
    console.log('create pair: tokenA: %s tokenB: %s', tokenA, tokenB, await mdexFactory.pairFor(tokenA, tokenB))
    await tx.wait(2)
  }

  // getPairContract 获取 tokenA tokenB 对应的交易对
  const getPairContract = async (tokenA: string, tokenB: string) => {
    let pair = await mdexFactory.pairFor(tokenA, tokenB)
    return getContractBy(pairABI, pair)
  }

  // 存 token mint cToken
  const depositToken = async (token: Contract, ctoken: Contract, amount: BigNumberish) => {
    await token.approve(ctoken.address, amount)
    let tx = await ctoken.functions.mint(amount)
    await token.approve(ctoken.address, 0)
    await tx.wait(2)
  }

  const transfer = async (token: Contract, to: string, amount: BigNumberish) => {
    await expect(token.transfer(to, amount)).to.emit(token, 'Transfer')
    // await tx.wait(2)
  }

  // mint 流动性代币
  const swapMint = async () => {
    const usdtc = usdt.contract! // await getTokenContract(usdt)
      , seac = sea.contract! //  await getTokenContract(sea)
      , cusdtCt = await getCTokenContract(cusdt)
      , cseaCt = await getCTokenContract(csea)
      , mintAmt = '2500000000000000000000'
      , amount =  '10000000000000000000'

    let addr = await mdexFactory.pairFor(usdt, sea)
    let pair = await getContractBy(pairABI, addr)

    await depositToken(usdtc, cusdtCt, mintAmt)
    await depositToken(seac, cseaCt, mintAmt)

    console.log('transfer to %s before mint LP ...', addr)
    // await usdtc.approve(usdt, amount)
    // await seac.approve(sea, amount)
    await transfer(cusdtCt, addr, amount)
    await transfer(cseaCt, addr, amount)
    // await (await cusdtCt.transfer(addr, amount)).wait(1)
    // await (await cseaCt.transfer(addr, amount)).wait(1)

    console.log('mint ...')
    let tx = await pair.mint(deployer)
    let receipt = await tx.wait(2)
    console.log('mint receipt events:', receipt.events.length)
    console.log('minted LP:', (await pair.balanceOf(deployer)).toString())
  }

  const deadlineTs = (second: number) => {
    return (new Date()).getTime() + second * 1000
  }

  const getCtokenContractByToken = async (token: string) => {
    return delegatorFactory.getCTokenAddressPure(token)
  }

  const swapRouterMint = async (token0: string, token1: string, amt0Desired: BigNumberish, amt1Desired: BigNumberish, amt0Min: BigNumberish, amt1Min: BigNumberish) => {
    const _ctoken0 = await getCtokenContractByToken(token0)
      , _ctoken1 = await getCtokenContractByToken(token1)
    
      , ctoken0 = await getCTokenContract(_ctoken0)
      , ctoken1 = await getCTokenContract(_ctoken1)
    
    await ctoken0.approve(router.address, amt0Desired)
    await ctoken1.approve(router.address, amt1Desired)
    await router.addLiquidity(token0, token1, amt0Desired, amt1Desired, amt0Min, amt1Min, deployer, deadlineTs(6))
  }

  // 提取流动性代币
  const swapBurn = async (lp?: any) => {
    let addr = await mdexFactory.pairFor(usdt, sea)
    let pair = await getContractBy(pairABI, addr)
    if (lp === undefined || lp === null) {
      lp = await pair.balanceOf(deployer)
    }
    console.log('to burn LP:', lp.toString())
    // 将LP 转入 pair
    await (await pair.transfer(addr, lp)).wait(2);
    let tx = await pair.burn(deployer)
    let receipt = await tx.wait(2)
    console.log('swap burn events:', receipt.events.length)
  }

  // 根据 x * y = K 计算swap amount out
  // idx: 0: amountIn 为 ctoken0; 1: amountIn 为 ctoken1
  const calcAmountOut = async (pair: Contract, amountIn: BigNumberish, idx: 0 | 1) => {
    // let amount0Out: BigNumberish, amount1Out: BigNumberish
    // let reserves = await pair.getReserves()
    // console.log('reserves:', reserves)
    let [reserve0, reserve1] = await pair.getReserves()
    let amtIn = BigNumber.from(amountIn)
        , reserveOut, reserveIn

    console.log('calcAmountOut amountIn:', amountIn.toString())
    console.log( reserve0.toString(), reserve1.toString())
    let amountInWithFee = amtIn.mul(997);
    if (idx === 0) {
      reserveIn = reserve0
      reserveOut = reserve1
    } else {
      reserveIn = reserve1
      reserveOut = reserve0
    }
    let numerator = amountInWithFee.mul(reserveOut);
    let denominator = reserveIn.mul(1000).add(amountInWithFee);
    const out = numerator.div(denominator);
    console.log('+++++++++++++++numerator=%s denominator=%s out=%s', numerator.toString(), denominator.toString(), out.toString())
    return out;
  }

  // 输入为 token 的 amountIn, 输出为 token 的 amountOut, 均已完成转换
  // 根据 x * y = K 计算swap amount out
  // idx: 0: amountIn 为 token0; 1: amountIn 为 token
  const calcAmountOutWithToken = async (factory: Contract, pair: Contract, amountIn: BigNumberish, idx: 0 | 1) => {

  }

  // 根据 exchangeRate 的换算关系, 将 token 转为为 ctoken
  // ctoken = token / exchangeRate
  const toCAmount = async (ctoken: Contract, amt: BigNumberish) => {
    await ctoken.exchangeRateCurrent() // 确保计算得到最新的 exchangeRate
    const er = await ctoken.exchangeRateStored()
    const camt = BigNumber.from(amt).mul(e18).div(er)

    console.log('exchangeRate: %s amt: %s camount: %s', er.toString(), amt.toString(), camt.toString())
    return camt
  }

  const toAmount = async (ctoken: Contract, camt: BigNumberish) => {
    await ctoken.exchangeRateCurrent() // 确保计算得到最新的 exchangeRate
    const er = await ctoken.exchangeRateStored()
    return BigNumber.from(camt).mul(er).div(e18)
    // return amt
  }

  // swapExactTokensForTokens: amountIn 确定, 求最低amountOut  
  const swapExactTokensForTokens = async (token0: string, token1: string, amt0In: BigNumberish) => {
    let amt1Min = 0

    // 求解 amt1Min

    // 转 ctoken 到 pair 合约
    const _ctoken0 = await getCtokenContractByToken(token0)
      , _ctoken1 = await getCtokenContractByToken(token1)
    
      , ctoken0 = await getCTokenContract(_ctoken0)
      , ctoken1 = await getCTokenContract(_ctoken1)

    const pair = await getPairContract(token0, token1)
    await ctoken0.approve(router.address, amt0In);
    // await transfer(ctoken0, pair.address, amtIn)
    // await transfer(ctoken1, pair.address, amt1Min)

    console.log('calling swapExactTokensForTokens ....')
    let tx = await router.functions.swapExactTokensForTokens(amt0In, amt1Min, [token0, token1], deployer, deadlineTs(10))
    await tx.wait(2)
  }

  const swapTokensForExactTokens = async (token0: string, token1: string, amt1Out: BigNumberish) => {
    let amtInMax = BigNumber.from(5000000).mul(e18)
    // amtInMax = amtInMax
    const _ctoken0 = await getCtokenContractByToken(token0)
      , _ctoken1 = await getCtokenContractByToken(token1)
    
      , ctoken0 = await getCTokenContract(_ctoken0)
      , ctoken1 = await getCTokenContract(_ctoken1)

    // const pair = await getPairContract(token0, token1)
    await ctoken0.approve(router.address, amtInMax);
    // await transfer(ctoken0, pair.address, amtIn)
    // await transfer(ctoken1, pair.address, amt1Min)

    console.log('calling swapTokensForExactTokens ....')
    let tx = await router.functions.swapTokensForExactTokens(amt1Out, amtInMax, [token0, token1], deployer, deadlineTs(10))
    await tx.wait(2)
  }

  // 交换
  const swapSwap = async (amt: any = '200000000000000000') => {
    console.log('swap: ------------------------------------------------------------------------------')
    console.log('amt=%s', amt)
    let addr = await mdexFactory.pairFor(usdt, sea)
    let pair = await getContractBy(pairABI, addr)
    const usdtc = await getTokenContract(usdt)
    const seac = await getTokenContract(sea)
    const usdtBuyer = await getTokenContract(usdt, buyer)
    const cusdtCt = await getCTokenContract(cusdt)
    const cseaCt = await getCTokenContract(csea)

    let balance = await usdtc.balanceOf(buyer.address)
    console.log('buyer:', buyer.address)
    console.log('buyer usdt balance before transfer:', balance.toString())
    await (await usdtc.transfer(buyer.address, amt)).wait(2)
    balance = await usdtc.balanceOf(buyer.address)
    console.log('buyer usdt balance:', balance.toString())

    // await usdtBuyer.approve(usdt, amt)
    await usdtBuyer.approve(deployer, amt)
    let tx = await usdtc.transferFrom(buyer.address, addr, amt)
    // expect(tx).to.emit(usdt, 'Transfer')
    await tx.wait(1)
    balance = await usdtc.balanceOf(buyer.address)
    console.log('buyer usdt balance after transfre to:', balance.toString())
    // console.log('buyer transfer usdt to contract:', receipt.events.length)
    
    let amountOut0, amountOut1
    let idx: 0 | 1 = usdt === pair.token0 ? 0 : 1 // 输入 usdt 的位置是 0 还是 1
    // let amtIn = BigNumber.from(amt)
    if (idx === 0) {
      amountOut0 = 0
      const camt = await toCAmount(cusdtCt, amt)
      const camountOut1 = await calcAmountOut(pair, camt, idx)
      amountOut1 = await toAmount(cseaCt, camountOut1)
    } else {
      const camt = await toCAmount(cseaCt, amt)
      const camountOut0 = await calcAmountOut(pair, camt, idx)
      amountOut0 = await toAmount(cusdtCt, camountOut0)
      amountOut1 = 0
    }
    console.log('amtIn=%s idx=%d amountOut0=%s amountOut1=%s', amt, idx, amountOut0, amountOut1)
    tx = await pair.swap(amountOut0, amountOut1, buyer.address, [])
    let receipt = await tx.wait(2)
    console.log('pair swap receipt:', receipt.events.length)
    // pair.swap()
    console.log('after pair swap, balance:')
    let bUsdt = await usdtc.balanceOf(buyer.address)
    let bSea = await seac.balanceOf(buyer.address)
    console.log('usdt: %s sea: %s', bUsdt.toString(), bSea.toString())
  }

  // it('swap-mint', async () => {
  //   // pair = 
  //   await swapMint()
  // })

  it('router-mint', async () => {
    // pair = 
    const usdtc = await getTokenContract(usdt)
    , seac = await getTokenContract(sea)
    , cusdtCt = await getCTokenContract(cusdt)
    , cseaCt = await getCTokenContract(csea)
    , mintAmt = '2500000000000000000000'

    const amt0 =  '10000000000000000000'
    const amt1 =  '5000000000000000000'

    await depositToken(usdtc, cusdtCt, mintAmt)
    await depositToken(seac, cseaCt, mintAmt)
    
    await swapRouterMint(usdt, sea, amt0, amt1, amt0, amt1)
  })

  it('swapExactTokensForTokens', async () => {

    const usdtc = await getTokenContract(usdt)
    , cusdtCt = await getCTokenContract(cusdt)
    , seac = await getTokenContract(sea)
    , cseaCt = await getCTokenContract(csea)
    , mintAmt = '4000000000000000'

    await depositToken(usdtc, cusdtCt, mintAmt)

    // const er = await cusdtCt.exchangeRateStored()
    let balBefore = await cseaCt.balanceOf(deployer)
    let amtIn = await toCAmount(cusdtCt, mintAmt)
    await swapExactTokensForTokens(usdt, sea, amtIn)
    let balAfter = await cseaCt.balanceOf(deployer)
    console.log('swap out csea:', balBefore.toString(), balAfter.toString())
  })

  it('swapTokensForExactTokens', async () => {

    const usdtc = await getTokenContract(usdt)
    , cusdtCt = await getCTokenContract(cusdt)
    , seac = await getTokenContract(sea)
    , cseaCt = await getCTokenContract(csea)
    , mintAmt = '5000000000000000'

    await depositToken(usdtc, cusdtCt, mintAmt)

    // const er = await cusdtCt.exchangeRateStored()
    let balBefore = await cseaCt.balanceOf(deployer)
    let amtIn = await toCAmount(cusdtCt, mintAmt)
    await swapTokensForExactTokens(usdt, sea, '100000000000000')
    let balAfter = await cseaCt.balanceOf(deployer)
    console.log('swap out csea:', balBefore.toString(), balAfter.toString())
  })

  // it('token->ctoken', async () => {
  //   const cusdtCt = await getCTokenContract(cusdt)
  //     , cseaCt = await getCTokenContract(csea)

  //   const erCusdt = await cusdtCt.exchangeRateStored()
  //     , erCsea = await cseaCt.exchangeRateStored()
  //   console.log(erCusdt)
  //   console.log('exchage rate cusdt: %s sea: %s', erCusdt.toString(), erCsea.toString())
  // })

  // it('swap-swap', async () => {
  //   // transfer usdt to buyer

  //   console.log('buyer:', buyer.address)
  //   await swapSwap()
  // })

});
