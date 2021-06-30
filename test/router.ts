const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'

import { getContractAt, getContractBy, getContractByNameAddr } from '../utils/contracts'

import { DeployContracts, deployAll, deployTokens, Tokens, getTokenContract, getCTokenContract, deployWHT } from '../deployments/deploys'
import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { assert } from 'console';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

const e18 = BigNumber.from('1000000000000000000')

// 测试 swap router
describe("ctoken router 测试", function() {
  let tokens: Tokens
  // let deployContracts: DeployContracts
  let namedSigners: SignerWithAddress[]
  // let unitroller: Contract
  let delegatorFactory: Contract
  let mdexFactory: Contract
  let router: Contract
  let pairABI: any
  let deployer: string
  let buyer: SignerWithAddress
  let usdt: string
  let sea: string
  let doge: string
  let cusdt: string
  let csea: string
  // let cdoge: string
  let cWHT: string
  let cwhtCT: Contract
  let wht: Contract
  const skipDeploy = false;  // 如果合约没有发生改变，不需要重新部署, 节省测试时间
  const logHr = (s: string) => console.log('--------------------------  ' + s + '  --------------------------')

  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')
  
  this.timeout(6000000);

  before(async () => {
    namedSigners = await ethers.getSigners()
    deployer = namedSigners[0].address
    buyer = namedSigners[1]

    console.log('deployer: %s buyer: %s', deployer, buyer.address)

    tokens = await deployTokens(false)
    let addresses: string[] = []
    for (let key of tokens.addresses.keys()) {
      addresses.push(tokens.addresses.get(key)!)
    }

    const pairArt = await hre.artifacts.readArtifact('DeBankPair')
    pairABI = pairArt.abi
    // create ctoken
    usdt = tokens.addresses.get('USDT')!
    sea = tokens.addresses.get('SEA')!
    doge = tokens.addresses.get('DOGE')!

    if (skipDeploy && network.name === 'hecotest') {
      // mdex anchor token: 0x04F535663110A392A6504839BEeD34E019FdB4E0
      // contract WHT at: 0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836
      // deploy comptroller at:  0x605E6d6C23c287D49A79ee373a1c41a95fDc7325
      // deploy unitroller at:  0x1D52AB58B603c4549a7648ff81E9F7D8c80cD728
      // deploy interest at:  0x713e4f086A0D024460Bb2A0De4594A3d0b0FfaDF
      // deploy priceOrace at:  0x45Dfea132Da141E22116d328DEB804E0820241C8
      // deploy mdexFactory at:  0xE4b2704895fbD5668f73Aa2C2517270c423aB730
      // deploy lerc20Implement at:  0x04C95aD982e21E24E8b96b00453325502CcfC10f
      // deploy lerc20DelegatorFactory at:  0x6A99b227A40C7a145Dd782Ba21b839133ad19380
      // deploy router at:  0xe1AD4142582af95A8Adb2739A026310E2F8D0173
      delegatorFactory = await getContractByNameAddr('lErc20DelegatorFactory', '0x6A99b227A40C7a145Dd782Ba21b839133ad19380')
      mdexFactory = await getContractByNameAddr('DeBankFactory', '0xE4b2704895fbD5668f73Aa2C2517270c423aB730')
      router = await getContractByNameAddr('DeBankRouter', '0xe1AD4142582af95A8Adb2739A026310E2F8D0173')

      cusdt = await delegatorFactory.getCTokenAddressPure(usdt)
      console.log('cusdt address:', cusdt)
      csea = await delegatorFactory.getCTokenAddressPure(sea)
      console.log('csea address:', csea)
      
      // create pair
      await createPair(usdt, sea)
      await createPair(doge, sea)
      wht = await deployWHT(namedSigners[0], true, true)
      // wht = await getContractAt(whtInfo)

      return
    }

    console.log('deploy contracts ....')
    let deployContracts = await deployAll({log: true, anchorToken: tokens.addresses.get('USDT'), addresses: addresses}, true)
    // console.log('deploy contracts', deployTokens())
    await getContractAt(deployContracts.unitroller)
    delegatorFactory = await getContractAt(deployContracts.lErc20DelegatorFactory)
    mdexFactory = await getContractAt(deployContracts.mdexFactory)
    router = await getContractAt(deployContracts.router)
    wht = await getContractAt(deployContracts.WHT)
    cWHT = deployContracts.cWHT.address
    cwhtCT = await getContractByNameAddr('LHT', cWHT)

    console.info('USDT:', usdt, 'SEA:', sea)
    expect(usdt).to.not.be.empty
    expect(sea).to.not.be.empty
    await expect(createCToken(deployContracts.lErc20DelegatorFactory, usdt))
    await sleep(6000)
      // .to.emit(delegatorFactory, 'NewDelegator').withArgs(delegatorFactory, '0x340d6d7ea30fb8fcc82d906d0232eb65243b0b87')
      // .to.emit(unitroller, 'MarketListed') //.withArgs(usdt, '')
    let tx = await createCToken(deployContracts.lErc20DelegatorFactory, sea)

    // const delegatorFactoryContract = await getCon
    cusdt = await delegatorFactory.getCTokenAddressPure(usdt)
    console.log('cusdt address:', cusdt)
    csea = await delegatorFactory.getCTokenAddressPure(sea)
    console.log('csea address:', csea)

    await tx.wait(2)

    // create pair
    await createPair(usdt, sea)
    await createPair(doge, sea)
    await createPair(usdt, wht.address)
    await createPair(doge, wht.address)
  })

  // create pair
  const createPair = async (tokenA: string, tokenB: string) => {
    let pair = await mdexFactory.pairFor(tokenA, tokenB)
    console.log('create pair for: %s %s, pair: %s', tokenA, tokenB, pair)
    if (pair !== '0x0000000000000000000000000000000000000000') {
      // alreday exist
      return pair
    }
    let tx = await mdexFactory.createPair(tokenA, tokenB)
    await tx.wait(2)
    pair = await mdexFactory.pairFor(tokenA, tokenB)
    console.log('create pair: tokenA: %s tokenB: %s', tokenA, tokenB, pair)
    // await tx.wait(2)
  }

  // getPairContract 获取 tokenA tokenB 对应的交易对
  const getPairContract = async (tokenA: string, tokenB: string) => {
    let pair = await mdexFactory.pairFor(tokenA, tokenB)
    assert(pair !== '0x0000000000000000000000000000000000000000')
    return getContractBy(pairABI, pair)
  }

  // 存 token mint cToken
  const depositToken = async (token: Contract, ctoken: Contract, amount: BigNumberish) => {
    console.log('deposit %s', token.address, ctoken.address)
    await token.approve(ctoken.address, amount)
    console.log('mint %s ...', ctoken.address)
    let tx
    if (token.address === wht.address) {
      console.log('mint wht .....', amount.toString())
      let overrides = {value: amount.toString()}
      tx = await cwhtCT.functions.mint(overrides)
    } else {
      let gas = await ctoken.estimateGas.mint(amount)
      // 在 hecotest 上会失败， 为什么??? 2021/06/25
      console.log('ctoken mint estimate gas:', gas.toString())
      tx = await ctoken.functions.mint(amount, {gasLimit: gas})
    }
    await token.approve(ctoken.address, 0)
    await tx.wait(2)
    console.log('mint %s %s success, amount: %s', token.address, await token.name(), amount.toString())
  }

  const transfer = async (token: Contract, to: string, amount: BigNumberish) => {
    await expect(token.transfer(to, amount)).to.emit(token, 'Transfer')
    // await tx.wait(2)
  }

  const deadlineTs = (second: number) => {
    return (new Date()).getTime() + second * 1000
  }

  const getCtokenContractByToken = async (token: string): Promise<Contract> => {
    let ctoken = await delegatorFactory.getCTokenAddressPure(token)
    if (ctoken === cWHT) {
        console.log('got cWHT !!!')
        return cwhtCT
    }

    return getCTokenContract(ctoken)
  }

  const getTokenContractByCtoken = async (ctoken: string): Promise<Contract> => {
    let token = await delegatorFactory.getTokenAddress(ctoken)
    return getTokenContract(token)
  }

  const getBlockNumber = async () => {
    return ethers.provider.getBlockNumber()
  }

  // 计算 ctoken 当前的 exchangeRate
  const getCTokenRate = async (ctoken: Contract) => {
    let rate = await ctoken.exchangeRateStored()
    let supplyRate = await ctoken.supplyRatePerBlock();
    let lastBlock = await ctoken.accrualBlockNumber();
    let block = await getBlockNumber()
    // console.log(block, lastBlock.toString())
    let blocks = BigNumber.from(block).sub(lastBlock)
    let inc =  rate.mul(supplyRate).mul(blocks);
    rate = rate.add(inc);
    console.log('ctoken exchange rate: %s', rate.toString())
    return rate
  }

  const camtToAmount = async (ctoken: Contract, camt: BigNumberish): Promise<BigNumber> => {
    let rate = await getCTokenRate(ctoken)

    let amt = BigNumber.from(camt).mul(rate).div(e18) // .add(1)
    console.log('camtToAmount: camt=%s amt=%s', camt.toString(), amt.toString())
    return amt
  }

  const amountToCAmount = async (ctoken: Contract, amt: BigNumberish): Promise<BigNumber> => {
    let rate = await getCTokenRate(ctoken)

    let camt = BigNumber.from(amt).mul(e18).div(rate)
    console.log('amountToCAmount: amt=%s camt=%s', amt.toString(), camt.toString())
    return camt
  }

  const swapRouterMintCtoken = async (token0: string, token1: string,
      amt0Desired: BigNumberish, amt1Desired: BigNumberish,
      amt0Min: BigNumberish, amt1Min: BigNumberish) => {
    logHr('swapRouterMintCtoken')
    
    console.log('swapRouterMint ...', token0, token1)
    // const _ctoken0 = await getCtokenContractByToken(token0)
    //   , _ctoken1 = await getCtokenContractByToken(token1)
    
    //   console.log('swapRouterMint ctoken:', _ctoken0, _ctoken1)

    const token0C = await getTokenContract(token0)
      , token1C = await getTokenContract(token1)

    const ctoken0 = await getCtokenContractByToken(token0)
      , ctoken1 = await getCtokenContractByToken(token1)

    // console.log('get ctoken success')
    // const rate0 = await getCTokenRate(ctoken0)
      // , rate1 = await getCTokenRate(ctoken1)
    const amt0 = await camtToAmount(ctoken0, amt0Desired)
      , amt1 = await camtToAmount(ctoken1, amt1Desired)
    
    await depositToken(token0C, ctoken0, amt0)
    await depositToken(token1C, ctoken1, amt1)

    await ctoken0.approve(router.address, amt0Desired)
    await ctoken1.approve(router.address, amt1Desired)

    // console.log('get ctoken approve success')
    // console.log('router addLiquidity:', ctoken0.address, ctoken1.address, amt0Desired.toString(), amt1Desired.toString(), amt0Min.toString(), amt1Min.toString())
    // console.log('router:', router.address)

    const pair = await getPairContract(ctoken0.address, ctoken1.address)
    const b0 = await pair.balanceOf(deployer)
    console.log('before mint, LP %s balance: %s', pair.address, b0.toString())
    let gas = await router.estimateGas.addLiquidity(ctoken0.address, ctoken1.address, amt0Desired, amt1Desired, amt0Min, amt1Min, deployer, deadlineTs(60))
    console.log('addLiquidity estimate gas:', gas.toString())
    const tx = await router.addLiquidity(ctoken0.address, ctoken1.address, amt0Desired, amt1Desired, amt0Min, amt1Min, deployer, deadlineTs(60), {gasLimit: gas})
    await tx.wait(1);
    const b1 = await pair.balanceOf(deployer)
    console.log('after mint, LP %s balance: %s', pair.address, b1.toString())
  }

  const swapRouterMintToken = async (token0: string, token1: string,
          amt0Desired: BigNumberish, amt1Desired: BigNumberish,
          amt0Min: BigNumberish, amt1Min: BigNumberish) => {

    logHr('swapRouterMintToken')

    const tokenC0 = await getTokenContract(token0)
    await tokenC0.approve(router.address, amt0Desired)

    const tokenC1 = await getTokenContract(token1)
    await tokenC1.approve(router.address, amt1Desired)

    const pair = await getPairContract(token0, token1)
    const b0 = await pair.balanceOf(deployer)
    console.log('before mint, LP %s balance: %s', pair.address, b0.toString())
    if (token1 !== wht.address) {
      const tx = await router.addLiquidityUnderlying(token0, token1, amt0Desired, amt1Desired, amt0Min, amt1Min, deployer, deadlineTs(6))
      await tx.wait(1);
    } else {
      console.log('!!!token1 is wETH!!!')
      let gas = await router.estimateGas.addLiquidityETHUnderlying(token0, amt0Desired, amt0Min, amt1Min, deployer, deadlineTs(6))
      console.log('addLiquidityETHUnderlying estimate gas:', gas.toString())
      let overrides = {value: amt1Desired, gasLimit: gas}
      const tx = await router.addLiquidityETHUnderlying(token0, amt0Desired, amt0Min, amt1Min, deployer, deadlineTs(6), overrides)
      await tx.wait(1);
    }
    const b1 = await pair.balanceOf(deployer)
    console.log('after mint, LP %s balance: %s', pair.address, b1.toString())
  }

  const printBalance = async (s: string, token0: string, token1: string, pair: string, owner: string) => {
    const ctoken0 = await getTokenContract(token0)
    const ctoken1 = await getTokenContract(token1)
    const cpair = await getTokenContract(pair)
  
    const b0 = await ctoken0.balanceOf(owner)
    const b1 = await ctoken1.balanceOf(owner)
    const b2 = await cpair.balanceOf(owner)

    console.log('%s: token0 amount: %s, token1 amount: %s, pairLP amount: %s', s, b0.toString(), b1.toString(), b2.toString())
  }

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

  // swapExactTokensForTokens: amountOut 确定, 求最大 amountIn  
  const swapTokensForExactTokensUnderlying = async (token0: string, token1: string, amtOut: BigNumberish) => {
    logHr('swapTokensForExactTokensUnderlying')

    const ctoken0CT = await getCtokenContractByToken(token0)
      , token0CT = await getTokenContract(token0)
      , ctoken1CT = await getCtokenContractByToken(token1)

    let camtOut = await amountToCAmount(ctoken1CT, amtOut)
    camtOut = camtOut.add(1)
    // 根据 amountOut 计算 amountIn
    let {reserveA, reserveB} = await mdexFactory.getReserves(token0, token1)
    console.log('reserves:', reserveA.toString(), reserveB.toString())
    let camtIn = await router.getAmountIn(camtOut, reserveA, reserveB)
    // camtIn = camtIn.add(1)
    console.log('camoutOut: %s  camtIn: %s', camtOut.toString(), camtIn.toString())
    let amtIn = await camtToAmount(ctoken0CT, camtIn)
    amtIn = amtIn.add(1)
    console.log('amtIn:', amtIn.toString())
    
    let pair = await mdexFactory.pairFor(token0, token1)

    await printBalance('before swapTokensForExactTokensUnderlying ctoken', token0, token1, pair, deployer);
    console.log('calling swapTokensForExactTokensUnderlying ....')
    await token0CT.approve(router.address, amtIn)
    if (token0 === wht.address) {
        console.log('ETH in for exact token')
        let tx = await router.functions.swapETHForExactTokensUnderlying(amtOut, [token0, token1], deployer, deadlineTs(10), {value: amtIn})
        await tx.wait(1)
    } else {
        if (token1 === wht.address) {
            console.log('exact ETH out', amtOut.toString(), 'camount:', camtOut.toString())
            let tx = await router.functions.swapTokensForExactETHUnderlying(amtOut, amtIn, [token0, token1], deployer, deadlineTs(10))
            await tx.wait(1)
        } else {
            let tx = await router.functions.swapTokensForExactTokensUnderlying(amtOut, amtIn, [token0, token1], deployer, deadlineTs(10))
            await tx.wait(1)
        }
    }
    await printBalance('after swapTokensForExactTokensUnderlying ctoken', token0, token1, pair, deployer);
  }

  // 计算需要多少 amountIn
  const calcCAmountIn = async (token0: string, token1: string, cAmtOut: BigNumberish): Promise<BigNumberish> => {
    let {reserveA, reserveB} = await mdexFactory.getReserves(token0, token1)
    return router.getAmountIn(cAmtOut, reserveA, reserveB)
    // return 0
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

  
  // // 将字符串转换为 BigNumebr
  // const humanAmount = (amt: string, token = '') => {

  // }

  it('router-addLiquidity', async () => {
    console.log('---------------------------------------------------------------------')
    let amt0 =  '1000000'
    let amt1 =  '5000000'

    // await swapRouterMintCtoken(usdt, sea, amt0, amt1, amt0, amt1)
    // await swapRouterMintCtoken(sea, usdt, amt1, amt0, amt1, amt0)

    // const pair = await mdexFactory.pairFor(usdt, sea)
    amt0 = '100000000'
    amt1 = '500000000'
    await swapRouterMintToken(usdt, sea, amt0, amt1, 0, 0)
    await swapRouterMintToken(sea, usdt, amt1, amt0, 0, 0)
  })

  // it('router-removeLiquidity', async () => {
  //   // await swapBurnCToken(cusdt, csea, '10000', true)
  //   // await swapBurnCToken(usdt, sea,   '10000', false)
  //   await swapBurnCToken(cusdt, csea,   null, true)
  //   // await swapBurnCToken(usdt, sea,   null, false)
  // })
  

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
  //   await swapExactTokensForTokens(cusdt, csea, '1000')
  //   await swapExactTokensForTokens(cusdt, csea, '1000')
  //   await swapExactTokensForTokens(csea, cusdt, '5000')
  //   await swapExactTokensForTokens(csea, cusdt, '5000')
  //   await swapExactTokensForTokens(csea, cusdt, '5000')
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
  //   await swapExactTokensForTokensUnderlying(usdt, sea, '10000', 0)
  //   await swapExactTokensForTokensUnderlying(usdt, sea, '10000', 0)
  //   await swapExactTokensForTokensUnderlying(sea, usdt, '50000', 0)
  //   await swapExactTokensForTokensUnderlying(sea, usdt, '50000', 0)
  //   await swapExactTokensForTokensUnderlying(sea, usdt, '50000', 0)
  // })
  // it('swapTokensForExactTokensUnderlying', async () => {
  //   await swapTokensForExactTokensUnderlying(usdt, sea, '10000')
  //   await swapTokensForExactTokensUnderlying(usdt, sea, '10000')
  //   await swapTokensForExactTokensUnderlying(usdt, sea, '10000')
  //   await swapTokensForExactTokensUnderlying(sea, usdt, '50000')
  //   await swapTokensForExactTokensUnderlying(sea, usdt, '50000')
  //   await swapTokensForExactTokensUnderlying(sea, usdt, '50000')
  // })

    // it('swapExactETHForTokensUnderlying', async () => {
    //     await swapExactTokensForTokensUnderlying(wht.address, usdt, '10000', 0)
    //     await swapExactTokensForTokensUnderlying(wht.address, usdt, '200000', 0)
    //     await swapExactTokensForTokensUnderlying(wht.address, usdt, '300000', 0)

    //     await swapExactTokensForTokensUnderlying(usdt, wht.address, '250000', 0)
    //     await swapExactTokensForTokensUnderlying(usdt, wht.address, '100000', 0)
    //     await swapExactTokensForTokensUnderlying(usdt, wht.address, '123456', 0)
    // })

    // it('swapETHForExactTokensUnderlying', async () => {
    //     // await swapTokensForExactTokensUnderlying(wht.address, usdt, '10000')
    //     // await swapTokensForExactTokensUnderlying(wht.address, usdt, '10000')
    //     // await swapTokensForExactTokensUnderlying(wht.address, usdt, '10000')

    //     await swapTokensForExactTokensUnderlying(usdt, wht.address, '10000')
    //     await swapTokensForExactTokensUnderlying(usdt, wht.address, '10000')
    //     await swapTokensForExactTokensUnderlying(usdt, wht.address, '10000')
    // })
});
