import { assert } from "console";
import { BigNumber, BigNumberish, Contract } from "ethers";
import { _deploy, deployToken } from "../deployments/deploys";
import { getTokenContract, addressOf, TokenContractName } from './contractHelper'

const hre = require('hardhat')
const ethers = hre.ethers

interface IToken {
    name: string
    symbol: string
    decimals: number
    totalSupply: BigNumber
    address: string
    contract?: Contract
}

async function getMockToken(tokenName: string, total: BigNumberish, decimals = 18): Promise<IToken>  {
    const networkName: string = hre.network.name
    const signer = await ethers.getSigners()

    if (networkName === 'hardhat') {
        return deployToken(tokenName, BigNumber.from(total), decimals)
    }

    assert(networkName === 'hecotest', "invalid network name")
    let addr = addressOf(tokenName as TokenContractName)
    if (!addr) {
        throw new Error('token not found')
    }
    const c = getTokenContract(addr, signer[0])
    return {
        name: tokenName,
        symbol: tokenName,
        decimals: decimals,
        totalSupply: BigNumber.from(total),
        address: addr,
        contract: c,
    }
}

export {
    IToken,
    getMockToken,
}
