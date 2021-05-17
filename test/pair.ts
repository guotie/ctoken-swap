const { expect } = require("chai");
// import { ethers } from 'hardhat'

import { BigNumber, BigNumberish, Contract } from 'ethers'

// import contracts from '../utils/contracts'
// import { deployTokens, Tokens  } from './shared/fixtures'
import getLErc20DelegatorContract from './shared/mint'
import contracts, { getContractAt, getContractBy } from '../utils/contracts'
import { getCreate2Address } from '@ethersproject/address'
import { pack, keccak256 } from '@ethersproject/solidity'

import { DeployContracts, deployAll, deployTokens, Tokens, getTokenContract, getCTokenContract } from '../deployments/deploys'
import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

// 测试 create mdex pair
describe("MdexPair 测试", function() {
  let tokens: Tokens
  let deployContracts: DeployContracts
  let namedSigners: SignerWithAddress[]
  let unitroller: Contract
  let delegatorFactory: Contract
  let mdexFactory: Contract
  let pairABI: any
  let deployer: string
  let buyer: SignerWithAddress
  let usdt: string
  let sea: string
  let cusdt: string
  let csea: string

  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')

  before(async () => {
    namedSigners = await ethers.getSigners()
    deployer = namedSigners[0].address
    buyer = namedSigners[1]

    console.log('deployer: %s buyer: %s', deployer, buyer.address)

    deployContracts = await deployAll({log: true})
    tokens = await deployTokens()
    // console.log('deploy contracts', deployTokens())
    unitroller = await getContractAt(deployContracts.unitroller)
    delegatorFactory = await getContractAt(deployContracts.lErc20DelegatorFactory)
    mdexFactory = await getContractAt(deployContracts.mdexFactory)

    const pairArt = await hre.artifacts.readArtifact('contracts/swap/heco/Factory.sol:MdexPair')
    pairABI = pairArt.abi

    // create ctoken
    usdt = tokens.addresses.get('USDT')!
    sea = tokens.addresses.get('SEA')!

    console.info('USDT:', usdt, 'SEA:', sea)
    expect(usdt).to.not.be.empty
    expect(sea).to.not.be.empty
    await expect(createCToken(deployContracts.lErc20DelegatorFactory, usdt))
      // .to.emit(delegatorFactory, 'NewDelegator').withArgs(delegatorFactory, '0x340d6d7ea30fb8fcc82d906d0232eb65243b0b87')
      // .to.emit(unitroller, 'MarketListed') //.withArgs(usdt, '')
    let tx = await createCToken(deployContracts.lErc20DelegatorFactory, sea)

    // const delegatorFactoryContract = await getCon
    cusdt = await delegatorFactory.getCTokenAddressPure(usdt)
    console.log('cusdt address:', cusdt)
    csea = await delegatorFactory.getCTokenAddressPure(sea)
    console.log('csea address:', csea)

    await tx.wait(2)
  })

  // it('block mine', async () => {
  //   let block = await network.provider.send('eth_blockNumber', [])
  //   console.log('block:', block)

  //   await network.provider.send('evm_mine', [])
    
  //   block = await network.provider.send('eth_blockNumber', [])
  //   console.log('block:', block)
  // })

  it('transfer', async() => {
    if (network === 'hecotest') {
      await sleep(5000)
    }
    const usdt = tokens.addresses.get('USDT')

    const usdtContract = await getContractBy(tokens.abi, usdt!)
    const toAddr = '0x9769713AA909C73914DaC551C8D434ad84DB9410', amount = 200000000000000
    // 测试 emit 函数
    await expect(usdtContract.transfer(toAddr, amount))
      .to.emit(usdtContract, 'Transfer').withArgs(namedSigners[0].address, toAddr, amount)
      // .to.wait(1)

    // await sleep(3000)
    console.log('transfer testcase end')
  })

  it('getCreate2Address of LErc20Token', async() => {
    const INIT_CODE_HASH = '0x71a762e9b044ae662a0d792ceaa9aaa4bf09c9ecdd90967035ae11e75f841390'
      , factoryAddress = deployContracts.lErc20DelegatorFactory.address
    const addr = getCreate2Address(
      factoryAddress,
      keccak256(['bytes'], [pack(['address'], [usdt])]),
      INIT_CODE_HASH
    )

    console.log('cusdt contract address computed:', addr)
  })

  it("create mdex pair", async function() {
    if (network === 'hecotest') {
      await sleep(5000)
    }
    // let {address, abi} = contracts.getDeployedContractInfoByName('hecotest', 'MdexFactory')
    // let pairContract = contracts.getDeployedContractInfoByName('hecotest', 'MdexFactory')
    // const deployedFactory = deployContracts.mdexFactory
    // console.info('deployedFactory:', deployedFactory)
    // const factory = await ethers.getContractAt(deployedFactory.abi, deployedFactory.address, namedSigners[0])
    // const pair = await ethers.getContractAt(pairContract.abi, '0x521BA82F08D7e68D594E4359bFB3cabC8b351e41', namedSigners[0])

    // const Token = await ethers.getContractFactory('Token')
    // const usdt = await Token.deploy('USDT', 'USDT', '100000000000000000000000000', namedSigners[0].address)
    // await usdt.deployed();
    // const sea = await Token.deploy('SEA', 'SEA', '100000000000000000000000000', namedSigners[0].address)
    // await sea.deployed();

    // console.info('USDT:', usdt, 'SEA:', sea)
    // expect(usdt).to.not.be.empty
    // await expect(createCToken(deployContracts.lErc20DelegatorFactory, usdt!))
    //   // .to.emit(delegatorFactory, 'NewDelegator').withArgs(delegatorFactory, '0x340d6d7ea30fb8fcc82d906d0232eb65243b0b87')
    //   // .to.emit(unitroller, 'MarketListed') //.withArgs(usdt, '')
    // let tx = await createCToken(deployContracts.lErc20DelegatorFactory, sea!)
    // let receipt = await tx.wait(1)
    // console.log('receipt:', receipt)

    await expect(mdexFactory.createPair(usdt, sea))
      .to.emit(mdexFactory, 'PairCreated')

    let addr = await mdexFactory.pairFor(usdt, sea)
    console.info('pair for address:', addr)
    // pair.mint(namedSigners[0].address)
    // await greeter.setGreeting("Hola, mundo!");
    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });

  // it('mint', async () => {
  //   // const delegatorFactory = deployContracts.lErc20DelegatorFactory
  //   // const factory = await ethers.getContractAt(delegatorFactory.abi, delegatorFactory.address, namedSigners[0])
  //   const usdt = tokens.addresses.get('USDT')
  //   const cont = await getContractBy(tokens.abi, usdt!)
  //   const amount = '10000000000000000000'
  //   const cUsdtAddress = await delegatorFactory.getCTokenAddressPure(usdt!)
  //   const cusdt = await getLErc20DelegatorContract(deployContracts.lErc20Delegate, cUsdtAddress)
    
  //   await (await cont.approve(cUsdtAddress, amount)).wait(1)
  //   const tx = await cusdt.mint(amount)
  //   await tx.wait(1)
  //   // const receipt = await tx.wait(1)
  //   // console.log(receipt)
  // });

  // mint 流动性代币
  const swapMint = async () => {
    const usdtc = await getTokenContract(usdt)
      , seac = await getTokenContract(sea)
      , amount = '10000000000000000000'

    let addr = await mdexFactory.pairFor(usdt, sea)
    let pair = await getContractBy(pairABI, addr)

    console.log('transfer to %s before mint LP ...', addr)
    // await usdtc.approve(usdt, amount)
    // await seac.approve(sea, amount)
    await (await usdtc.transfer(addr, amount)).wait(1)
    await (await seac.transfer(addr, amount)).wait(1)

    let tx = await pair.mint(deployer)
    let receipt = await tx.wait(2)
    console.log('mint receipt events:', receipt.events.length)
    console.log('minted LP:', (await pair.balanceOf(deployer)).toString())
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

    // mul exchangeRate
    // return cAmtOut;
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
    const amt = BigNumber.from(camt).mul(er).div(e18)

    return amt
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
    tx = await pair.swap2x(amountOut0, amountOut1, buyer.address, [])
    let receipt = await tx.wait(2)
    console.log('pair swap receipt:', receipt.events.length)
    // pair.swap()
    console.log('after pair swap, balance:')
    let bUsdt = await usdtc.balanceOf(buyer.address)
    let bSea = await seac.balanceOf(buyer.address)
    console.log('usdt: %s sea: %s', bUsdt.toString(), bSea.toString())
  }

  it('swap-mint', async () => {
    // pair = 
    await swapMint()
  })

  it('token->ctoken', async () => {
    const cusdtCt = await getCTokenContract(cusdt)
      , cseaCt = await getCTokenContract(csea)

    const erCusdt = await cusdtCt.exchangeRateStored()
      , erCsea = await cseaCt.exchangeRateStored()
    console.log(erCusdt)
    console.log('exchage rate cusdt: %s sea: %s', erCusdt.toString(), erCsea.toString())
  })

  it('swap-swap', async () => {
    // transfer usdt to buyer

    console.log('buyer:', buyer.address)
    await swapSwap()
  })

  // it('swap-burn', async () => {
  //   await swapBurn()
  // })

  // it('swap-mint again', async () => {
  //   // pair = 
  //   await swapMint()
  // })

  // it('swap-burn again', async () => {
  //   await swapBurn()
  // })
});
