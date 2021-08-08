const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'

import { deployUniswap, zeroAddress } from '../deployments/deploys'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { assert } from 'console';
import { getMockToken, HTToken, IToken, readableTokenAmount } from '../helpers/token';
import { ISwap } from '../helpers/swap';
import { _deployWHT, deployTokens } from '../helpers/mock';
import { getBalance, getEbankPair } from '../helpers/contractHelper';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

// 测试 swap router
describe("uniswap 测试", function() {
  // let deployContracts: DeployContracts
  let namedSigners: SignerWithAddress[]
  // let unitroller: Contract
  let deployer: string
  let buyer: SignerWithAddress
  let swap1: ISwap
    , swap2: ISwap
  let usdt: IToken
    , sea: IToken
    , ht = HTToken
    , wht: IToken

  const logHr = (s: string) => console.log('--------------------------  ' + s + '  --------------------------')

  this.timeout(60000000);

  before(async () => {
    namedSigners = await ethers.getSigners()
    deployer = namedSigners[0].address
    buyer = namedSigners[1]

    await deployTokens()
    await _deployWHT()
    wht = await getMockToken('WHT')
    usdt = await getMockToken('USDT')
    sea = await getMockToken('SEA')

    swap1 = await deployUniswap('0x10')
    swap2 = await deployUniswap('0x20')
    console.log('deployer: %s buyer: %s', deployer, buyer.address)
  })


  const transfer = async (token: Contract, to: string, amount: BigNumberish) => {
    await expect(token.transfer(to, amount)).to.emit(token, 'Transfer')
    // await tx.wait(2)
  }

  const deadlineTs = (second: number) => {
    return (new Date()).getTime() + second * 1000
  }

  const addLiquidity = async (
            swap: ISwap,
            token0: IToken,
            token1: IToken,
            amt0Desired: BigNumberish,
            amt1Desired: BigNumberish,
            signer: SignerWithAddress
        ) => {
        let to = signer.address
            , amt0 = readableTokenAmount(token0, amt0Desired)
            , amt1 = readableTokenAmount(token1, amt1Desired)
            , rc = swap.rc!
            , fc = swap.fc!

        if (token0.address === zeroAddress || token1.address == zeroAddress) {
            // token -> eth or eth -> token
            if (token0.address === zeroAddress) {
                await token1.contract!.approve(rc.address, amt1)

                await rc.addLiquidityETH(token1.address, amt1, 0, 0, to, deadlineTs(600), {value: amt0})
            } else {
                await token0.contract!.approve(rc.address, amt0)
                await rc.addLiquidityETH(token0.address, amt0, 0, 0, to, deadlineTs(600), {value: amt1})
            }
        } else {
            // token <-> token
            await token0.contract!.approve(rc.address, amt0)
            await token1.contract!.approve(rc.address, amt1)
            
                await rc.addLiquidity(token0.address, token1.address, amt0, amt1, 0, 0, to, deadlineTs(600))
            
        }
        
        let t0 = token0.address === zeroAddress ? wht.address : token0.address
          , t1 = token1.address === zeroAddress ? wht.address : token1.address
        let pair = await fc.pairFor(t0, t1)
            // , pairc = getEbankPair(pair, signer)
            , reserve = await fc.getReserves(t0, t1)
    
        console.log('add liquidity: pair=%s %s(%s) %s(%s)', pair, token0.name, token0.address, token1.name, token1.address)
        console.log('reserves:', reserve[0].toString(), reserve[1].toString())
        await printBalance('after add LP', token0, token1, pair, signer)
  }


  const printBalance = async (s: string, token0: IToken, token1: IToken, pair: string, signer: SignerWithAddress) => {
    const owner = signer.address
    const b0 = await getBalance(token0, owner)
      , b1 = await getBalance(token1, owner)
    
    const pairc = getEbankPair(pair, signer)
      , b2 = await pairc.balanceOf(owner)

    console.log('%s: token0 amount: %s, token1 amount: %s, pairLP amount: %s', s, b0.toString(), b1.toString(), b2.toString())
  }
/*
  // 提取流动性代币
  const swapBurnCToken = async (ctoken0: string, ctoken1: string, amt: BigNumberish | undefined | null, isCtoken: boolean) => {
    logHr('swapBurnCToken')

    let addr = await mdexFactory.pairFor(ctoken0, ctoken1)
    let pair = await getContractBy(pairABI, addr)

    let b = await pair.balanceOf(deployer)
    console.log('lp %s balanceOf %s: %s', addr, deployer, b.toString())
    if (!amt) {
      amt = b
    }
    if (isCtoken) {
      await printBalance('before burn ctoken', ctoken0, ctoken1, pair.address, deployer);
    } else {
      await printBalance('before burn token', ctoken0, ctoken1, pair.address, deployer);
    }
    
    console.log('to burn LP:', addr, amt?.toString())
    // approve
    await pair.approve(router.address, amt)
    if (isCtoken) {
      const tx = await router.removeLiquidity(ctoken0, ctoken1, amt, 0, 0, deployer, deadlineTs(6))
      await tx.wait(1)
      await printBalance('after burn ctoken', ctoken0, ctoken1, pair.address, deployer);
    } else {
      if (ctoken1 === wht.address) {
        const tx = await router.removeLiquidityETHUnderlying(ctoken0, amt, 0, 0, deployer, deadlineTs(6))
        await tx.wait(1)
      } else {
        const tx = await router.removeLiquidityUnderlying(ctoken0, ctoken1, amt, 0, 0, deployer, deadlineTs(6))
        await tx.wait(1)
      }
      await printBalance('after burn token', ctoken0, ctoken1, pair.address, deployer);
    }
  }

  // swapExactTokensForTokens: amountIn 确定, 求最低 amountOut  
  const swapExactTokensForTokens = async (ctoken0: string, ctoken1: string, camt0In: BigNumberish) => {
    logHr('swapExactTokensForTokens')
    let amt1Min = 0

    const ctoken0CT = await getCTokenContract(ctoken0)
      , token0CT = await getTokenContractByCtoken(ctoken0)

    const amt0In = await camtToAmount(ctoken0CT, camt0In)
    
    let pair = await mdexFactory.pairFor(ctoken0, ctoken1)
    // mint ctoken0
    await depositToken(token0CT, ctoken0CT, amt0In)
    await ctoken0CT.approve(router.address, camt0In)

    await printBalance('before swapExactTokensForTokens ctoken', ctoken0, ctoken1, pair, deployer);
    console.log('calling swapExactTokensForTokens ....')
    let tx = await router.functions.swapExactTokensForTokens(camt0In, amt1Min, [ctoken0, ctoken1], deployer, deadlineTs(10))
    await tx.wait(1)
    await printBalance('after swapExactTokensForTokens ctoken', ctoken0, ctoken1, pair, deployer);
  }

  // swapExactTokensForTokens: amountIn 确定, 求最低amountOut  
  const swapExactTokensForTokensUnderlying = async (token0: string, token1: string, amt0In: BigNumberish, amtOutMin: BigNumberish) => {
    logHr('swapExactTokensForTokensUnderlying')
    console.log('wht: %s cwht: %s', wht.address, cWHT)

    console.log('token0: %s  token1: %s  amtIn: %s', token0, token1, amt0In.toString())

    const ctoken0CT = await getCtokenContractByToken(token0)
      , token0CT = await getTokenContract(token0)

    console.log('ctoken0: %s ', ctoken0CT.address)

    const camt0In = await amountToCAmount(ctoken0CT, amt0In)
    
    let pair = await mdexFactory.pairFor(token0, token1)
    console.log('pair: %s', pair)
    // mint ctoken0
    // await depositToken(token0CT, ctoken0CT, amt0In)
    // await ctoken0CT.approve(router.address, camt0In)

    await printBalance('before swapExactTokensForTokensUnderlying ctoken', token0, token1, pair, deployer);
    console.log('calling swapExactTokensForTokensUnderlying ....')
    await token0CT.approve(router.address, amt0In)
    if (token0 === wht.address) {
        console.log('tokenIn is ETH')
        let tx = await router.functions.swapExactETHForTokensUnderlying(amtOutMin, [token0, token1], deployer, deadlineTs(10), {value: amt0In})
        await tx.wait(1)
    } else {
        if (token1 === wht.address) {
            console.log('tokenOut is ETH')
            let tx = await router.functions.swapExactTokensForETHUnderlying(amt0In, amtOutMin, [token0, token1], deployer, deadlineTs(10))
            await tx.wait(1)
        } else {
            let tx = await router.functions.swapExactTokensForTokensUnderlying(amt0In, amtOutMin, [token0, token1], deployer, deadlineTs(10))
            await tx.wait(1)
        }
    }
    await printBalance('after swapExactTokensForTokensUnderlying ctoken', token0, token1, pair, deployer);
  }


  // 精确兑换多少个 token out
  const swapTokensForExactTokens = async (ctoken0: string, ctoken1: string, camt1Out: BigNumberish) => {
    const ctoken0CT = await getCTokenContract(ctoken0)
      // , ctoken1CT = await getCTokenContract(ctoken1)
      , token0CT = await getTokenContractByCtoken(ctoken0)
      , token1CT = await getTokenContractByCtoken(ctoken1)
      , pairCT = await getPairContract(ctoken0, ctoken1)
    
    // 计算需要多少 camountIn
    let camtInMax = await calcCAmountIn(token0CT.address, token1CT.address, camt1Out)
    let amtInMax = await camtToAmount(ctoken0CT, camtInMax)

    console.log('camtInMax: %s amtInMax: %s', camtInMax.toString(), amtInMax.toString())

    await depositToken(token0CT, ctoken0CT, amtInMax)
    await ctoken0CT.approve(router.address, camtInMax)

    await printBalance('before swapTokensForExactTokens ctoken', ctoken0, ctoken1, pairCT.address, deployer);
    console.log('calling swapTokensForExactTokens ....')
    let tx = await router.functions.swapTokensForExactTokens(camt1Out, camtInMax, [ctoken0, ctoken1], deployer, deadlineTs(10))
    await tx.wait(1)
    await printBalance('after swapTokensForExactTokens ctoken', ctoken0, ctoken1, pairCT.address, deployer);
  }
  */

  it('router-addLiquidity', async () => {
    logHr('addLiquidity')
    let amt0 =  '10000000'
      ,  amt1 =  '50000000'
      , signer = namedSigners[0]

    await addLiquidity(swap1, usdt, sea, amt0, amt1, signer)
    await addLiquidity(swap2, usdt, sea, amt0, amt1, signer)

    await addLiquidity(swap1, usdt, sea, amt0, amt1, signer)
    await addLiquidity(swap2, usdt, sea, amt0, amt1, signer)
  })


  // it('router-addETHLiquidity', async () => {
  //   logHr('addETHLiquidity')

  //   let amt0 =  '10000000'
  //   let amt1 =  '50000000'

  //   await swapRouterMintCtoken(usdt, wht.address, amt0, amt1, amt0, amt1)
  //   await swapRouterMintCtoken(usdt, wht.address, amt0, amt1, amt0, amt1)
  //   await swapRouterMintCtoken(wht.address, usdt, amt1, amt0, amt1, amt0)
  //   // await swapRouterMintCtoken(usdt, wht.address, amt0, amt1, amt0, amt1)

  //   amt0 = '200000000'
  //   amt1 = '750000000'
  //   await swapRouterMintToken(usdt, wht.address, amt0, amt1, amt0, amt1)
  // })

  // it('router-removeETHLiquidity', async () => {
  //   // await swapBurnCToken(cusdt, csea, '10000', true)
  //   // await swapBurnCToken(usdt, sea,   '10000', false)
  //   // await swapBurnCToken(cusdt, cWHT, null, true)
  //   await swapBurnCToken(usdt, wht.address, null, false)
  //   // await swapBurnCToken(usdt, sea,   null, false)
  // })

  // it('swapExactTokensForTokens', async () => {
  //   await swapExactTokensForTokens(cusdt, csea, '1000')
  //   await swapExactTokensForTokens(cusdt, csea, '1500')
  //   await swapExactTokensForTokens(cusdt, csea, '2000')
  //   await swapExactTokensForTokens(csea, cusdt, '5000')
  //   await swapExactTokensForTokens(csea, cusdt, '4000')
  //   await swapExactTokensForTokens(csea, cusdt, '3000')
  // })

  // it('swapTokensForExactTokens', async () => {
  //   await swapTokensForExactTokens(cusdt, csea, '10000')
  //   await swapTokensForExactTokens(cusdt, csea, '10000')
  //   await swapTokensForExactTokens(cusdt, csea, '10000')
  //   await swapTokensForExactTokens(csea, cusdt, '50000')
  //   await swapTokensForExactTokens(csea, cusdt, '50000')
  //   await swapTokensForExactTokens(csea, cusdt, '50000')
  // })
  // it('swapExactTokensForTokensUnderlying', async () => {
  //   await swapExactTokensForTokensUnderlying(usdt, sea, '10000', 0)
  //   await swapExactTokensForTokensUnderlying(usdt, sea, '15000', 0)
  //   await swapExactTokensForTokensUnderlying(usdt, sea, '20000', 0)
  //   await swapExactTokensForTokensUnderlying(sea, usdt, '50000', 0)
  //   await swapExactTokensForTokensUnderlying(sea, usdt, '40000', 0)
  //   await swapExactTokensForTokensUnderlying(sea, usdt, '30000', 0)
  // })
  // it('swapTokensForExactTokensUnderlying', async () => {
  //   await swapTokensForExactTokensUnderlying(usdt, sea, '10000')
  //   await swapTokensForExactTokensUnderlying(usdt, sea, '10000')
  //   await swapTokensForExactTokensUnderlying(usdt, sea, '10000')
  //   await swapTokensForExactTokensUnderlying(sea, usdt, '50000')
  //   await swapTokensForExactTokensUnderlying(sea, usdt, '50000')
  //   await swapTokensForExactTokensUnderlying(sea, usdt, '50000')
  // })


  // it('router-removeLiquidity', async () => {
  //   await swapBurnCToken(cusdt, csea, '10000', true)
  //   // await swapBurnCToken(usdt, sea,   '10000', false)
  //   await swapBurnCToken(cusdt, csea,   null, true)
  //   // await swapBurnCToken(usdt, sea,   null, false)
  // })
  
});
