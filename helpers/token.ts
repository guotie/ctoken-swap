import { assert } from "console";
import { BigNumber, BigNumberish, Contract, Signer } from "ethers";
import { deployToken, zeroAddress } from "../deployments/deploys";
import { getTokenContract, addressOf, TokenContractName, getEbankPair, setContractAddress, tokenHasExist } from './contractHelper'

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

const HTToken: IToken = {
    name: 'HT',
    symbol: 'HT',
    decimals: 18,
    totalSupply: BigNumber.from('1000000000000000000000000000'), // 10亿
    address: zeroAddress,
}

function setTokenAddress(token: IToken) {
    setContractAddress(token.name as TokenContractName, token.address)
}

async function getMockToken(tokenName: string, total?: BigNumberish, decimals = 18): Promise<IToken> {
    const networkName: string = hre.network.name
    const signer = await ethers.getSigners()

    if (networkName === 'hardhat') {
        if (!tokenHasExist(tokenName as TokenContractName)) {
            let token = await deployToken(tokenName, BigNumber.from(total!), decimals)
            setTokenAddress(token)
            return token
        }
        // got exist token
        // console.info('maybe token %s has deployed: ', tokenName, addressOf(tokenName as TokenContractName))
    } else {
        assert(networkName === 'hecotest', "invalid network name")
    }

    let addr = addressOf(tokenName as TokenContractName)
    if (!addr) {
        throw new Error('token not found:' + tokenName)
    }
    const c = getTokenContract(addr, signer[0])
    let supply = await c.totalSupply()
        , _decimals = await c.decimals()
    console.info('got Token %s at %s, totalSupply: %s decimals: %s', tokenName, c.address, supply.toString(), _decimals.toString())
    let token = {
        name: tokenName,
        symbol: tokenName,
        decimals: _decimals,
        totalSupply: supply,
        address: addr,
        contract: c,
    }
    if (networkName === 'hecotest') {
        setTokenAddress(token)
    }
    return token
}

// 交易对 token
async function getPairToken(address: string, signer?: Signer): Promise<IToken> {
    let pairc = await getEbankPair(address, signer)
        , totalSupply = await pairc.totalSupply()

    return {
        name: 'Pair',
        symbol: 'Pair eToken',
        decimals: 18,
        totalSupply: totalSupply,
        contract: pairc,
        address: address
    }
}

function decimalsToBignumber(decimals: number): BigNumber {
    let base = BigNumber.from(1)
        , ten = BigNumber.from(10)

    for (let i = 0; i < decimals; i ++) {
        base = base.mul(ten)
    }

    return base
}


const readableTokenAmount = (token: IToken, amt: BigNumberish) => {
    return BigNumber.from(amt).mul(decimalsToBignumber(token.decimals))        
}

const deadlineTs = (second: number) => {
    return (new Date()).getTime() + second * 1000
}

export {
    IToken,
    HTToken,
    getMockToken,
    deadlineTs,
    getPairToken,
    readableTokenAmount,
}
