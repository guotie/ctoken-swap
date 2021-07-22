const { expect } = require("chai");

import { BigNumber, BigNumberish, Contract } from 'ethers'

import { getContractAt, getContractBy } from '../utils/contracts'
import { setNetwork, getContractByAddressABI, getContractByAddressName, getTokenContract, getCTokenContract } from '../helpers/contractHelper'
// import { getCreate2Address } from '@ethersproject/address'
// import { pack, keccak256 } from '@ethersproject/solidity'

import { DeployContracts, deployAll, deployTokens, Tokens } from '../deployments/deploys'

import createCToken from './shared/ctoken'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
// import sleep from '../utils/sleep';
// import { deployContract } from 'ethereum-waffle';
const hre = require('hardhat')
const ethers = hre.ethers
const network = hre.network

setNetwork(network.name)

const e18 = BigNumber.from('100000000000000000')

interface Swap {
    fa: string   // factory address
    fc?: Contract // factory contract
    ra: string   // router address
    rc?: Contract // router contract
}

// 测试 swap pair
describe("聚合交易测试", function() {

    let tokens: Tokens
    let deployContracts: DeployContracts
    let namedSigners: SignerWithAddress[]
    let unitroller: Contract
    let delegatorFactory: Contract
    let mdexFactory: Contract
    let router: Contract
    // let pairABI: any
    let deployer: string
    let buyer: SignerWithAddress

    let usdt: string
        , sea: string
        , doge: string
        , cusdt: string
        , csea: string
        , cdoge: string
        , usdtc: Contract
        , seac: Contract
        , dogec: Contract

    let wht: string
        , whtC: Contract
        , ceth: string
        , ctokenFactory: string
        , ctokenFactoryC: Contract
    let s1: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
        , s2: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
        , s3: Swap = {fa: '', fc: undefined, ra: '', rc: undefined}
    
    let stepSwapC: Contract
  
    // e18 是 18位数
    const e18 = BigNumber.from('1000000000000000000')
    const deploy = hre.deployments.deploy

    before(async () => {
        namedSigners = await ethers.getSigners()
        deployer = namedSigners[0].address
        buyer = namedSigners[1]
        let signer = namedSigners[0]
    
        console.log('deployer: %s buyer: %s', deployer, buyer.address)
    
        tokens = await deployTokens()
        let addresses: string[] = []
        for (let key of tokens.addresses.keys()) {
          addresses.push(tokens.addresses.get(key)!)
        }
    
        deployContracts = await deployAll({log: true, anchorToken: tokens.addresses.get('USDT'), addresses: addresses})
        // console.log('deploy contracts', deployTokens())
        unitroller = await getContractAt(deployContracts.unitroller)
        delegatorFactory = await getContractAt(deployContracts.lErc20DelegatorFactory)
        mdexFactory = await getContractAt(deployContracts.mdexFactory)
        router = await getContractAt(deployContracts.router)
    
        // const pairArt = await hre.artifacts.readArtifact('contracts/swap/heco/Factory.sol:MdexPair')
        // pairABI = pairArt.abi
    
        // create ctoken
        usdt = tokens.addresses.get('USDT')!
        sea = tokens.addresses.get('SEA')!
        doge = tokens.addresses.get('DOGE')!
        usdtc = getTokenContract(usdt, signer)
        seac = getTokenContract(sea, signer)
        dogec = getTokenContract(doge, signer)
    
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
    
        await tx.wait(1)
    
        wht = deployContracts.WHT.address
        whtC = new ethers.Contract(wht, deployContracts.WHT.abi, namedSigners[0])
        ceth = deployContracts.cWHT.address
        ctokenFactory = deployContracts.lErc20DelegatorFactory.address
        ctokenFactoryC = new ethers.Contract(ctokenFactory, deployContracts.lErc20DelegatorFactory.abi, namedSigners[0])

        // create pair
        await createPair(usdt, sea)
        await createPair(doge, sea)

        await deployTestFixture(wht, ceth, ctokenFactory)

      })

    // normal mdex factory
    const deployFactoryRouter = async (
                    salt: string,
                    _wht: string,
                    s: Swap
                ) => {
        let signer = namedSigners[0]
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

        s.fa = dr.address
        s.fc = new ethers.Contract(dr.address, dr.abi, signer)
        let initHash = await s.fc!.getInitCodeHash()
        console.log('initHash:', initHash)
        await s.fc!.setInitCodeHash(initHash)
        s.ra = router.address
        s.rc = new ethers.Contract(router.address, router.abi, signer)
    }

    const deployTestFixture = async (_wht: string, _ceth: string, _ctokenFactory: string) => {
        await deployFactoryRouter('0x10', _wht, s1)
        await deployFactoryRouter('0x20', _wht, s2)
        await deployFactoryRouter('0x30', _wht, s3)

        await deployStepSwap(_wht, _ceth, _ctokenFactory)
    }

    const deadlineTs = (second: number) => {
        return (new Date()).getTime() + second * 1000
    }

    const addTestLiquidityByFactory = async (
                    rc: Contract,
                    fc: Contract,
                    token0: Contract,
                    token1: Contract,
                    amt0: BigNumberish,
                    amt1: BigNumberish,
                    to: string
                ) => {
        await fc.createPair(token0.address, token1.address)
        let pair = await fc.getPair(token0.address, token1.address)
        console.log('pair of factory %s: %s', fc.address, pair)
        
        await token0.transfer(pair, BigNumber.from(amt0))
        await token1.transfer(pair, BigNumber.from(amt1))

        let pairc = await getContractByAddressName(pair, 'MdexPair', namedSigners[0])
        await pairc.mint(to)
        let ts = await pairc.balanceOf(to)
        console.log('add Liquidity: ', ts.toString())
        // await token0.approve(rc.address, amt0)
        // await token1.approve(rc.address, amt1)
        // console.log('approve success')
        // await rc.addLiquidity(token0.address, token1.address, amt0, amt1, 0, 0, to, deadlineTs(600))
        // console.log('addTestLiquidity: token0=%s token1=%s amt0=%s amt1=%s', token0.address, token1.address, amt0.toString(), amt1.toString())
    }

    const addTestLiquidity = async (rc: Contract, fc: Contract, token0: Contract, token1: Contract, amt0: BigNumberish, amt1: BigNumberish, to: string) => {
        // await fc.createPair(token0.address, token1.address)

        await token0.approve(rc.address, amt0)
        await token1.approve(rc.address, amt1)
        // console.log('approve success')
        await rc.addLiquidity(token0.address, token1.address, BigNumber.from(amt0), BigNumber.from(amt1), 0, 0, to, deadlineTs(600))
        let pair = await fc.getPair(token0.address, token1.address)
        console.log('addTestLiquidity: pair of factory %s: %s', fc.address, pair)
        console.log('addTestLiquidity: token0=%s token1=%s amt0=%s amt1=%s', token0.address, token1.address, amt0.toString(), amt1.toString())
    }

    // 移除所有流动性
    const removeAllLiquidity = async (rc: Contract, fc: Contract, token0: string, token1: string, owner: string) => {
        let pair = await fc.pairFor(token0, token1)
            , pairc = getTokenContract(pair)
            , amt = await pairc.balanceOf(owner)
        rc.removeLiquidity(token0, token1, amt, 0, 0, owner, deadlineTs(600))
    }

    const deployStepSwap = async (wethAddr: string, ceth: string, _ctokenFactory: string) => {
        // let d = await deploy('contracts/swap/aggressive2/library/DataTypes', {
        //             from: deployer,
        //             args: [],
        //             log: true,
        //         }, false)
        let e = await deploy('Exchanges', {
                    from: deployer,
                    args: [],
                    log: true,
                }, false)

        let p = await deploy('PathFinder', {
                    from: deployer,
                    args: [],
                    log: true,
                }, false)

        let s = await deploy('SwapFlag', {
                    from: deployer,
                    args: [],
                    log: true
                }, false)
        let result = await deploy('StepSwap', {
            from: deployer,
            args: [wethAddr, ceth, _ctokenFactory],
            log: true,
            libraries: {
                // DataTypes: d.address,
                Exchanges: e.address,
                PathFinder: p.address,
                SwapFlag: s.address,
            },
            deterministicDeployment: false, // new Date().toString()
          })

        stepSwapC = new ethers.Contract(result.address, result.abi, namedSigners[0])
        console.log('deploy StepSwap:', result.address)
    }
    
    // create pair
    const createPair = async (tokenA: string, tokenB: string) => {
        await ctokenFactoryC.getCTokenAddress(tokenA)
        await ctokenFactoryC.getCTokenAddress(tokenB)
        let etokenA = await ctokenFactoryC.getCTokenAddressPure(tokenA)
            , etokenB = await ctokenFactoryC.getCTokenAddressPure(tokenB)

        let tx = await mdexFactory.createPair(tokenA, tokenB, etokenA, etokenB)
        console.log('create pair: tokenA: %s(%s) tokenB: %s(%s)', tokenA, etokenA, tokenB, etokenB, await mdexFactory.pairFor(tokenA, tokenB))
        await tx.wait(1)
    }

    it('no-middle-token', async () => {
        // await addTestLiquidityByFactory(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '20000000', deployer)
        await addTestLiquidity(s1.rc!, s1.fc!, seac, usdtc, '1000000000000000000000', '20000000', deployer)
        await addTestLiquidity(s2.rc!, s2.fc!, seac, usdtc, '2000000000000000000000', '40000000', deployer)
        await addTestLiquidity(s3.rc!, s3.fc!, seac, usdtc, '4000000000000000000000', '80000000', deployer)

        let res = await stepSwapC.getExpectedReturnWithGas({
            to: deployer,
            tokenIn: sea,
            tokenOut: usdt,
            amountIn: BigNumber.from('30000000000000000000'),
            tokenPriceGWei: 0,
            fromAddress: deployer,
            dstReceiver: deployer,
            midTokens: [],
            flag: { data: 0 },
        })

        console.log('res:', res)
    })
})
