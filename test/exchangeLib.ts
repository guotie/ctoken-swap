const { expect } = require("chai");

import { Contract } from 'ethers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
// import sleep from '../utils/sleep';
const hre = require('hardhat')
const ethers = hre.ethers
// const network = hre.network

// 测试 swap pair
describe("swap路径计算测试", function() {
    let namedSigners: SignerWithAddress[]

    // let pairABI: any
    let deployer: string

    let usdt: string = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'
        , sea: string = '0x5FbDB2315678afecb367f032d93F642f64180aa3'
        , dog = '0xE4b2704895fbD5668f73Aa2C2517270c423aB730'
        , ht  = '0x0000000000000000000000000000000000000000'
        , eth = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
        , btc = '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
        , exLibC: Contract

    const deploy = hre.deployments.deploy
    before(async () => {
        namedSigners = await ethers.getSigners()
        deployer = namedSigners[0].address

        await deployStepSwap()
    })
    
    const deployStepSwap = async () => {
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

        exLibC = new ethers.Contract(e.address, e.abi, namedSigners[0])
    }

    it('simple-path', async () => {
        let paths = await exLibC.allPaths(usdt, sea, [], 1)
        expect(paths.length).to.eq(1)
        // console.log('paths:', paths)
        paths = await exLibC.allPaths(sea, usdt, [], 1)
        // console.log('reverse paths:', paths)
        expect(paths.length).to.eq(1)
    })

    it('1-midtoken-path', async () => {
        let midTokens = [ht]
        let paths = await exLibC.allPaths(usdt, sea, midTokens, 1)
        // console.log('paths:', paths)
        expect(paths.length).to.eq(2)
    })

    it('multi-midtokens-path', async () => {
        let midTokens = [ht, usdt, eth, btc]
        let paths = await exLibC.allPaths(dog, sea, midTokens, 1)
        // console.log('paths:', paths)
        expect(paths.length).to.eq(1 + midTokens.length)
    })

    it('multi-midtokens-complex-path', async () => {
        let midTokens = [ht, usdt, eth, btc]
        let paths = await exLibC.allPaths(dog, sea, midTokens, 2)
        // console.log('paths with complex 2:', paths) // 1 + 4 + 4*3
        expect(paths.length).to.eq(17)

        paths = await exLibC.allPaths(dog, sea, midTokens, 3)
        // console.log('paths with complex 3:', paths) // 1+ 4 + 4*3 + 4*3*2
        expect(paths.length).to.eq(41)
    })
})