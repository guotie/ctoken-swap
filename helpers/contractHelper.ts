import { BigNumber, Contract, Signer, Wallet, providers } from 'ethers'
import {  Provider } from '@ethersproject/abstract-provider'
import 'dotenv/config';

import { abi as ctokenABI } from './abi/CToken.json'
import { abi as tokenABI } from './abi/Token.json'
import { abi as orderBookABI } from './abi/OrderBook.json'
import { abi as ctokenFactoryABI } from './abi/LErc20DelegatorFactory.json'

const hre = require('hardhat')

let contractAddress: { [index: string]: { [index: string]: string } } = {
    'hecotest': {
        'USDT': '0x04F535663110A392A6504839BEeD34E019FdB4E0',
        'SEA': '0xEe798D153F3de181dE16DedA318266EE8Ad56dEA',
        'DOGE': '0xA323120A386558ac95203019881C739D3c0A1346',
        'SHIB': '0xf2b80eff2A06f46cA839CA77cCaf32aa820e78D1',
        'WETH': '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836',
        'CETH': '',
        'Comptroller': '',
        'CtokenFactory': '0xbf7c839DFf6e849C742b33c676B2BfAF11a6a36c',
        'Factory': '',
        'Router': '',
        'SwapPool': '',
        'SwapMining': '',
        'OrderBook': '0x6545A6C3B6f28121CC7c65882b49023eE27Eaef0',
    },
    'hardhat' : {
        'USDT': '',
        'SEA': '',
        'WETH': '',
        'CETH': '',
        'Comptroller': '',
        'CtokenFactory': '',
        'Factory': '',
        'Router': '',
        'OrderBook': '',
    }
}

interface ISwap {
    fa: string     // factory address
    fc?: Contract  // factory contract
    ra: string     // router address
    rc?: Contract  // router contract
}

interface ITokenPair {
    token:  string
    etoken: string
    tokenc?:  Contract
    etokenc?: Contract
}

const endpoints: { [index: string]: string } = {
    'hecotest': 'https://http-testnet.hecochain.com'
}

const e18 = BigNumber.from('1000000000000000000')

let NETWORK: string = hre.network.name

type TokenContractName = 'USDT' 
                    | 'SEA'
                    | 'DOGE'
                    | 'SHIB'
                    | 'WETH'
                    | 'CETH'
                    | 'Comptroller'
                    | 'CtokenFactory'
                    | 'Factory'
                    | 'Router'
                    | 'SwapMining'
                    | 'SwapPool'
                    | 'OrderBook'

function setContractAddress(name: TokenContractName, addr: string) {
    contractAddress[NETWORK][name] = addr
}

function addressOf(name: TokenContractName): string {
    return contractAddress[NETWORK][name]
}

function getProvider() {
    return hre.ethers.provider
    // return new providers.JsonRpcProvider(endpoints[NETWORK])
}

// 根据环境变量生成 Signer, 私钥在 .env 文件中
function getSigner(addressOrIndex?: string | number): Signer {
    return new Wallet(process.env.PRIVATE_KEY!, getProvider())
}

// 根据环境变量生成 Signer, 私钥在 .env 文件中
function getTakerSigner(addressOrIndex?: string | number): Signer {
    return new Wallet(process.env.TAKER_PRIVATE_KEY!, getProvider())
}

function getTokenContract(address: string, signerOrProvider?: Signer | Provider) {
    return new Contract(address, tokenABI, signerOrProvider)
}

function getCTokenContract(address: string, signerOrProvider?: Signer | Provider) {
    return new Contract(address, ctokenABI, signerOrProvider)
}

function getCTokenFactoryContract(address: string, signerOrProvider?: Signer | Provider) {
    return new Contract(address, ctokenFactoryABI, signerOrProvider ?? getProvider())
}

async function getTokenPair(factory: string, token: string, signerOrProvider?: Signer | Provider): Promise<ITokenPair> {
    let etoken = await getETokenAddress(factory, token)
        , tokenc = getTokenContract(token, signerOrProvider)
        , etokenc = getCTokenContract(etoken, signerOrProvider)

    return {token: token, tokenc: tokenc, etoken: etoken, etokenc: etokenc}
}

// 获取 eToken 对应的 token 地址
async function getTokenAddress(factory: string, etoken: string) {
    let ctokenFactory = getCTokenFactoryContract(factory) // addressOf('ctokenFactory'))
    return ctokenFactory.getTokenAddress(etoken)
}

// 获取 token 对应的 etoken 地址
async function getETokenAddress(factory: string | Contract, token: string, signerOrProvider?: Signer | Provider): Promise<string> {
    if (typeof factory === 'string') {
        let ctokenFactory = getCTokenFactoryContract(factory, signerOrProvider) // addressOf('ctokenFactory'))
        return ctokenFactory.getCTokenAddressPure(token)
    } else {
        return factory.getCTokenAddressPure(token)
    }
}

function getOrderbookContract(address = contractAddress[NETWORK]['OrderBook'], signerOrProvider?: Signer | Provider) {
    return new Contract(address, orderBookABI, signerOrProvider ?? getProvider())
}

// 根据 abi 地址获取 Contract
function getContractByAddressABI(addr: string, abi: string, signerOrProvider?: Signer | Provider) {
    return new Contract(addr, abi, signerOrProvider ?? getProvider())
}
// 根据 abi 地址获取 Contract
async function getContractByAddressName(addr: string, name: string, signerOrProvider?: Signer | Provider) {
    const art = await hre.artifacts.readArtifact(name)
    return new Contract(addr, art.abi, signerOrProvider ?? getProvider())
}

export {
    e18,
    NETWORK,
    TokenContractName,
    setContractAddress,
    addressOf,
    // contractAddress,
    getProvider,
    getSigner,
    getTokenPair,
    getTokenAddress,
    getETokenAddress,
    getTakerSigner,
    getTokenContract,
    getCTokenContract,
    getOrderbookContract,
    getCTokenFactoryContract,
    getContractByAddressABI,
    getContractByAddressName
}
