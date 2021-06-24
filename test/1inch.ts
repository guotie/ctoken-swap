const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'

import { deployAll, getAbiByContractName, deployTokens, getTokenContract, setWEth, deployWHT, getWETH } from '../deployments/deploys'
import { getContractAt, getContractBy, getContractByNameAddr } from '../utils/contracts'
import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import sleep from '../utils/sleep';
import { AbiCoder } from '@ethersproject/abi';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

const e18 = BigNumber.from('100000000000000000')

// 测试 swap pair
describe("1inch", function() {
  // e18 是 18位数
  const e18 = BigNumber.from('1000000000000000000')
  // let data = '0x2e95b6c80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002386f26fc1000000000000000000000000000000000000000000000000000064d497d1e6e81c470000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000180000000000000003b6d034086f518368e0d49d5916e2bd9eb162e9952b7b04d'
  // let data = '0x7c025200000000000000000000000000fd3dfb524b2da40c8a6d703c62be36b5d854062600000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000226f7b842e0f0120b7e194d05432b3fd14773a9d000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000007f1da3697236d4a5e0efd2a99de5d9c0769378560000000000000000000000006a316f344bda31e6687173c97c839c7160dd2cd1000000000000000000000000000000000000000000013da329b633647180000000000000000000000000000000000000000000000000000000000006777f99ac0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f400000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000068000000000000000000000000000000000000000000000000000000000000009800000000000000000000000000000000000000000000000000000000000000ca0800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a4b757fed60000000000000000000000007f1da3697236d4a5e0efd2a99de5d9c076937856000000000000000000000000226f7b842e0f0120b7e194d05432b3fd14773a9d000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000002dc6c0fd3dfb524b2da40c8a6d703c62be36b5d8540626000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000003c483f1291f00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000360000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000020000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000064eb5625d9000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000080466c64868e1ab14a1ddf27a676c3fcbe638fe500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000080466c64868e1ab14a1ddf27a676c3fcbe638fe500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a4394747c500000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000004480000000000000000000000000000000000000000000000000000000000000440000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000244b3af37c000000000000000000000000000000000000000000000000000000000000000808000000000000000000000000000000000000000000000000000000000000044000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000260000000000000000000000000000002680000000000000000000000011b815efb8f581194ae79006d24e0d814b7697f60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000104128acb08000000000000000000000000fd3dfb524b2da40c8a6d703c62be36b5d85406260000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000001000276a400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000002647f8fe7a000000000000000000000000000000000000000000000000000000000000000808000000000000000000000000000000000000000000000000000000000000044000000000000000000000000fd3dfb524b2da40c8a6d703c62be36b5d854062600000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a405971224000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000010000000000000000000000000000000100000000000000000000000000000000000000000000000000000000007a120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004470bdb947000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000006cea143720000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000001a4b3af37c000000000000000000000000000000000000000000000000000000000000000808000000000000000000000000000000000000000000000000000000000000044000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000010000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000064d1660f99000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006a316f344bda31e6687173c97c839c7160dd2cd100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  let inch: Contract
  let wht: Contract
  let inchAddr: string = '0x434D7b6719Eb2Ed10724410186101fA972A0bE82' // '0xfB46aD8aBD6B23ccc8313CE97d30698107eca861'

  const deploy = hre.deployments.deploy
  let admin: string
  let sea: string;  // = '0x592285ed98ee14f947a9f27c121c8c95897615e4'
  let usdt: string; // = '0x810fa002935933f33de2cd8653b46668397dc3e1'
  let csea: Contract
  let cusdt: Contract
  let cunoswap: Contract

  this.timeout(600000);
  const deployFactory = async (deployer: any, salt: string, _wht: string) => {
      // let salt = new Date().getTime()
      let dr = await deploy('MdexFactory', {
        from: deployer,
        args: [deployer],
        log: true,
        deterministicDeployment: salt + '', //
      })
      let router = await deploy('MdexRouter', {
        from: deployer,
        args: [dr.address, _wht],
        log: true,
        deterministicDeployment: salt + '', //
      })
      console.log('factory/router address:', dr.address, router.address, salt)

      return { factory: dr.address, router: router.address }
      // newlyDeployed 是否是新部署
  }

  const deployUnoswap = async (deployer: any, wethAddr: string, _ctokenFactory: string) => {
    return deploy('UnoswapRouter', {
      from: deployer,
      args: [wethAddr, _ctokenFactory],
      log: true,
    })
  }

  const deployOneSplit = async (deployer: any, wethAddr: string, _ctokenFactory: string) => {
    let args = [wethAddr, _ctokenFactory]
    let result = await deploy('OneSplit', {
      from: deployer,
      args: args,
      log: true,
      deterministicDeployment: false, // new Date().toString()
      })

      // if (result.newlyDeployed) {
      //     await sleep(6500)
      //     console.log('verify contract ....')
      //     await hre.run('verify:verify', {
      //       address: result.address,
      //       constructorArguments: args
      //     })
      // }
      inchAddr = result.address
      console.log('deploy oneSplit:', result.address)
  }

  const depositWHT = async (value: BigNumberish) => {
      await wht.deposit({value: value})
  }

  const logHr = (s: string) => console.log('--------------------------  ' + s + '  --------------------------')
  before(async () => {
    // 
    const namedSigners = await ethers.getSigners()
    const deployer = namedSigners[0].address
    // const whtABI = await getAbiByContractName('WHT')

    let dcs = await deployAll()

    wht = getWETH() //await deployWHT(namedSigners[0], true, true)
    console.log('wht address:', wht.address);

    await depositWHT(BigNumber.from(10).mul(e18))
    // wht = await getContractBy(whtABI, '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836')
    // setWEth(wht)

    await deploy('MdexPair', {
      from: deployer,
      args: [],
      log: true,
    })
    admin = deployer

    let fr1 = await deployFactory(deployer, '0x10', wht.address)
    let fr2 = await deployFactory(deployer, '0x20', wht.address)
    let f1 = fr1.factory
      , f2 = fr2.factory
      , r1 = fr1.router
      , r2 = fr2.router

    await deployOneSplit(deployer, wht.address, dcs.lErc20DelegatorFactory.address)

    inch = await getContractByNameAddr('OneSplit', inchAddr) // '0xe8a1620429b7752484239b54f9f30e73ea634a33')

    console.log('reset factories')
    // await inch.resetFactories([f1, f2])
    await inch.addUniswap(r1, 0)
    await inch.addUniswap(r2, '0x0200000000000000000000000000000000000000000000000000000000000000')
    await inch.addCompoundSwap(dcs.router.address, dcs.lErc20DelegatorFactory.address, '0x0200000000000000000000000000000000000000000000000000000000000000')

    // let fs0 = await inch.factories(0)
    // let fs1 = await inch.factories(1)
    // console.log('factories: ', fs0, fs1)
    // await depositWHT('2000000000000000000')
    let fc0 = await getContractByNameAddr('MdexFactory', f1)
    let fc1 = await getContractByNameAddr('MdexFactory', f2)

    
    let tokens = await deployTokens(false)
    let addresses: string[] = []

    // create ctoken
    usdt = tokens.addresses.get('USDT')!
    sea = tokens.addresses.get('SEA')!

    cusdt = await getTokenContract(usdt)
    csea = await getTokenContract(sea)

    await addLiquidity(fc0, cusdt, csea, '200', '1000')
    await addLiquidity(fc0, cusdt, wht, '2000', '2')
    await addLiquidity(fc0, csea, wht, '2000', '2')
    await addLiquidity(fc1, cusdt, csea, '1000', '5000')
    await addLiquidity(fc1, cusdt, wht, '1000', '1')
    await addLiquidity(fc1, csea, wht, '1000', '1')

    const router = new ethers.Contract(dcs.router.address, dcs.router.abi, namedSigners[0])
    await addLiquidityUnderlying(router, cusdt, csea, '2000', '10000', deployer)
    await addLiquidityUnderlying(router, cusdt, wht, '2000', '2', deployer)
    await addLiquidityUnderlying(router, csea, wht, '2000', '2', deployer)

    let dr = await deployUnoswap(deployer, wht.address, dcs.lErc20DelegatorFactory.address)
    cunoswap = new ethers.Contract(dr.address, dr.abi, namedSigners[0])

    logHr('done')
  })

  const deadlineTs = (second: number) => {
    return (new Date()).getTime() + second * 1000
  }
    // compound
    const addLiquidityUnderlying = async (router: Contract, token0: Contract, token1: Contract, amt0: BigNumberish, amt1: BigNumberish, deployer: string) => {
      amt0 = BigNumber.from(amt0).mul(e18)
      amt1 = BigNumber.from(amt1).mul(e18)

      if (token0.address === wht.address) {
        await token1.approve(router.address, amt1)
        await router.addLiquidityETHUnderlying(token1.address, amt1, 0, 0, deployer, deadlineTs(60), {value: amt0})
      } else if (token1.address === wht.address) {
        await token0.approve(router.address, amt0)
        await router.addLiquidityETHUnderlying(token0.address, amt0, 0, 0, deployer, deadlineTs(60), {value: amt1})
      } else {
        console.log('addLiquidityUnderlying:', token0.address, token1.address)
        await token0.approve(router.address, amt0)
        await token1.approve(router.address, amt1)
        console.log('addLiquidityUnderlying....')
        await router.addLiquidityUnderlying(token0.address, token1.address, amt0, amt1, 0, 0, deployer, deadlineTs(60))
      }
    }

    const addLiquidity = async (factory: Contract, token0: Contract, token1: Contract, amt0: BigNumberish, amt1: BigNumberish) => {
      console.log('token0: %s token1: %s', token0.address, token1.address)
      // console.log(factory)
      await factory.createPair(token0.address, token1.address)
      let pair = await factory.getPair(token0.address, token1.address)
      console.log('pair of factory %s: %s', factory.address, pair)

      await token0.transfer(pair, BigNumber.from(amt0).mul(e18))
      await token1.transfer(pair, BigNumber.from(amt1).mul(e18))

      let cpair = await getContractByNameAddr('MdexPair', pair)
      await cpair.mint(admin)
      let ts = await cpair.balanceOf(admin)
      console.log('add Liquidity: ', ts.toString())
    }


    /*
    it('inch-ht-token', async () => {
      let amt = BigNumber.from('1000000000000000')
      let args = {
        fromToken: '0x0000000000000000000000000000000000000000',
        destToken: sea,
        midTokens: [],
        amount: amt,
        parts: 50,
        flags: 0,
        slip: 1,
        destTokenEthPriceTimesGasPrice: 0,
      }
      let tx = await inch.getExpectedReturnWithGas(args)
      console.log('tx: returnAmt=%s estimateGas=%s', tx.returnAmount.toString(), tx.estimateGasAmount.toString())
      for (let i = 0; i < tx.distribution.length; i ++) {
        console.log('tx distribution %d: %s', i, tx.distribution[i].toString())
      }
      let data = tx.data.slice(2)
      console.log(data)

      // await cusdt.approve(cunoswap.address, amt)
      // await csea.permit(cunoswap.address, amt)
      await cunoswap.unoswapAll(tx.data, {value: amt})
    })

    
    it('inch-token-ht', async () => {
      let amt = BigNumber.from('1000000000000000')
      let args = {
        fromToken: sea,
        destToken: '0x0000000000000000000000000000000000000000',
        midTokens: [],
        amount: amt,
        parts: 50,
        flags: 0,
        slip: 1,
        destTokenEthPriceTimesGasPrice: 0,
      }
      let tx = await inch.getExpectedReturnWithGas(args)
      console.log('tx: returnAmt=%s estimateGas=%s', tx.returnAmount.toString(), tx.estimateGasAmount.toString())
      for (let i = 0; i < tx.distribution.length; i ++) {
        console.log('tx distribution %d: %s', i, tx.distribution[i].toString())
      }
      let data = tx.data.slice(2)
      console.log(data)

      // await cusdt.approve(cunoswap.address, amt)
      await csea.approve(cunoswap.address, amt)
      await cunoswap.unoswapAll(tx.data, {value: amt})
    })
    

    it('inch-token-token', async () => {
        let amt = BigNumber.from('1000000000000000')
        let args = {
          fromToken: usdt,
          destToken: sea,
          midTokens: [wht.address],
          amount: amt,
          parts: 50,
          flags: 0,
          slip: 0,
          destTokenEthPriceTimesGasPrice: 0,
        }
        let tx = await inch.getExpectedReturnWithGas(args)
        console.log('tx: returnAmt=%s estimateGas=%s', tx.returnAmount.toString(), tx.estimateGasAmount.toString())
        for (let i = 0; i < tx.distribution.length; i ++) {
          console.log('tx distribution %d: %s', i, tx.distribution[i].toString())
        }
        let data = tx.data.slice(2)
        console.log(data)

        await cusdt.approve(cunoswap.address, amt)
        // await csea.permit(cunoswap.address, amt)
        await cunoswap.unoswapAll(tx.data)
    })
    */
    
    it('inch-token-token-midtoken', async () => {
        let amt = BigNumber.from('1000000000000000')
        let args = {
          fromToken: sea,
          destToken: usdt,
          midTokens: [], // [wht.address],
          amount: amt,
          parts: 50,
          flags: 0,
          slip: 0,
          destTokenEthPriceTimesGasPrice: 0,
        }
        let tx = await inch.getExpectedReturnWithGas(args)
        console.log('tx: returnAmt=%s estimateGas=%s', tx.returnAmount.toString(), tx.estimateGasAmount.toString())
        for (let i = 0; i < tx.distribution.length; i ++) {
          console.log('tx distribution %d: %s', i, tx.distribution[i].toString())
        }
        let data = tx.data.slice(2)
        console.log(data)

        // await cusdt.approve(cunoswap.address, amt)
        await csea.approve(cunoswap.address, amt)
        await cunoswap.unoswapAll(tx.data)
    })
    
});