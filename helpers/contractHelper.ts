import { BigNumber, Contract, Signer, Wallet, providers } from 'ethers'
import {  Provider } from '@ethersproject/abstract-provider'
import 'dotenv/config';

import { abi as ctokenABI } from './abi/CToken.json'
import { abi as tokenABI } from './abi/Token.json'
import { abi as routerABI } from './abi/DeBankRouter.json'
import { abi as factoryABI } from './abi/DeBankFactory.json'
import { abi as pairABI } from './abi/DeBankPair.json'
import { abi as orderBookABI } from './abi/OrderBook.json'
import { abi as ctokenFactoryABI } from './abi/LErc20DelegatorFactory.json'
import { zeroAddress } from '../deployments/deploys';
import { IToken } from './token';
import { boolean } from 'hardhat/internal/core/params/argumentTypes';

const hre = require('hardhat')

type TokenContractName = 'USDT' 
                    | 'SEA'
                    | 'DOGE'
                    | 'SHIB'
                    | 'WETH'
                    | 'WHT'
                    | 'CETH'
                    | 'Comptroller'
                    | 'ComptrollerV2'
                    | 'Unitroller'
                    | 'LErc20Delegate'
                    | 'CtokenFactory'
                    | 'Factory'
                    | 'Router'
                    | 'SwapMining'
                    | 'SwapPool'
                    | 'OrderBook'
                    | 'StepSwap'
                    | 'InterestRateModel'

let contractAddress: { [index: string]: { [index: string]: string } } = {
    'hecotest': {
        'USDT': '0x04F535663110A392A6504839BEeD34E019FdB4E0',
        'SEA': '0xEe798D153F3de181dE16DedA318266EE8Ad56dEA',
        'DOGE': '0xA323120A386558ac95203019881C739D3c0A1346',
        'SHIB': '0xf2b80eff2A06f46cA839CA77cCaf32aa820e78D1',
        'WETH': '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836',
        'WHT':  '0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836',
        'CETH': '0x042f1249297EF180f33d166828AC43e401E0FecA',
        // 0xa5142692F4B9ffa9FcC328aB92cFAb06C889f89F 不限制 router 地址
        'CtokenFactory': '0xF4CfC260cA8F68f3069FbEc534afbA21E0903b4b', // '0xbf7c839DFf6e849C742b33c676B2BfAF11a6a36c',
        'Comptroller': '0xc16BB0ea6817BdC592a525208c19a9Aa43FdC0d1',
        'ComptrollerV2': '0x36a20ae2C88Fe9A946C61Cbf78Ec4be102558E57',
        'Unitroller': '0xcc968c5367EE946e4C73A90D2841C0Ec5D9ED10D',
        'LErc20Delegate': '0xF10e746138b93A1c07de20306C2e94E1EBFEB655',
        'InterestRateModel': '0x85C1740414A26655054946e78BEE75fC27707542',
        'Factory': '0x3182528c58c54DE504cE45B21c15e47f73d58F09',
        'Router': '0xb18911609A5b9C7abDc7DBdA585Ae83F01ced0C5', // '0x9f186BC496e62dBd41d845f188eA1eA28C6EEF71', //'0xB83181Fca94A3aeE1B832A4EeF50f232D2AbE054', // '0xD70C027A1893f4A0fe3002c56AB63137942B5D6B',
        'SwapPool': '',
        'SwapMining': '',
        'OrderBook': '0x4639F9a380D37E491a84D751F086a70FBC6D395E',
        'StepSwap': '0xDe95a996c3f8Cc48E9F73A5efcBA8026D1585ae6',
    },
    'hardhat' : {
        'USDT': '',
        'SEA': '',
        'DOGE': '',
        'SHIB': '',
        'WETH': '',
        'WHT':  '',
        'CETH': '',
        'Comptroller': '',
        'ComptrollerV2': '',
        'Unitroller': '',
        'LErc20Delegate': '',
        'InterestRateModel': '',
        'CtokenFactory': '',
        'Factory': '',
        'Router': '',
        'OrderBook': '',
        'SwapPool': '',
        'SwapMining': '',
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

const e18 = BigNumber.from('1000000000000000000')

let NETWORK: string = hre.network.name


function setContractAddress(name: TokenContractName, addr: string) {
    contractAddress[NETWORK][name] = addr
}

function tokenHasExist(name: TokenContractName): boolean {
    return !!contractAddress[NETWORK][name]
}

function addressOf(name: TokenContractName): string {
    let addr =  contractAddress[NETWORK][name]
    if (!addr) {
        throw new Error('not found contract ' + name)
    }

    return addr
}

function dumpAddresses() {
    return contractAddress[NETWORK]
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

function getTokenContract(address: string, signer?: Signer | Provider) {
    return new Contract(address, tokenABI, signer ?? getProvider())
}

function getCTokenContract(address: string, signer?: Signer | Provider) {
    return new Contract(address, ctokenABI, signer ?? getProvider())
}

async function getTokenPair(factory: string, token: string, signer?: Signer | Provider): Promise<ITokenPair> {
    let etoken = await getETokenAddress(factory, token)
        , tokenc = getTokenContract(token, signer)
        , etokenc = getCTokenContract(etoken, signer)

    return {token: token, tokenc: tokenc, etoken: etoken, etokenc: etokenc}
}

function getCTokenFactoryContract(address?: string, signer?: Signer | Provider) {
    return new Contract(address ?? addressOf('CtokenFactory'), ctokenFactoryABI, signer ?? getProvider())
}

// 获取 eToken 对应的 token 地址
async function getTokenAddress(factory: string, etoken: string) {
    let ctokenFactory = getCTokenFactoryContract(factory) // addressOf('ctokenFactory'))
    return ctokenFactory.getTokenAddress(etoken)
}

// 获取 token 对应的 etoken 地址
async function getETokenAddress(factory: string | Contract, token: string, signer?: Signer | Provider): Promise<string> {
    if (typeof factory === 'string') {
        let ctokenFactory = getCTokenFactoryContract(factory, signer) // addressOf('ctokenFactory'))
        return ctokenFactory.getCTokenAddressPure(token)
    } else {
        return factory.getCTokenAddressPure(token)
    }
}

// 
function getEbankRouter(address = contractAddress[NETWORK]['Router'], signer?: Signer | Provider) {
    if (!address) {
        address = contractAddress[NETWORK]['Router']
    }
    return new Contract(address, routerABI, signer ?? getProvider())
}
// 
function getEbankFactory(address = contractAddress[NETWORK]['Factory'], signer?: Signer | Provider) {
    return new Contract(address, factoryABI, signer ?? getProvider())
}

function getEbankPair(address: string, signer?: Signer | Provider) {
    return new Contract(address, pairABI, signer ?? getProvider())
}

function getOrderbookContract(address = contractAddress[NETWORK]['OrderBook'], signer?: Signer | Provider) {
    return new Contract(address, orderBookABI, signer ?? getProvider())
}

// 根据 abi 地址获取 Contract
function getContractByAddressABI(addr: string, abi: string, signer?: Signer | Provider) {
    return new Contract(addr, abi, signer ?? getProvider())
}

// 根据 abi 地址获取 Contract
async function getContractByAddressName(addr: string, name: string, signer?: Signer | Provider) {
    const art = await hre.artifacts.readArtifact(name)
    return new Contract(addr, art.abi, signer ?? getProvider())
}

async function getBalance(token: IToken, owner: string): Promise<BigNumber> {
    let balance
        , provider = getProvider()
    if (token.address === zeroAddress) {
        balance = await provider.getBalance(owner)
    } else {
        balance = await token.contract!.balanceOf(owner)
    }

    return balance
}

async function getBalances(tokens: IToken[], owner: string): Promise<BigNumber[]> {
    let balances: BigNumber[] = []
        , provider = getProvider()

    for (let token of tokens) {
        let balance: BigNumber

        if (token.address === zeroAddress) {
            balance = await provider.getBalance(owner)
        } else {
            balance = await token.contract!.balanceOf(owner)
        }
        balances.push(balance)
    }
    return balances
}

export {
    e18,
    NETWORK,
    TokenContractName,
    setContractAddress,
    addressOf,
    dumpAddresses,
    tokenHasExist,
    // contractAddress,
    getProvider,
    getBalance,
    getBalances,
    getSigner,
    getTokenPair,
    getTokenAddress,
    getETokenAddress,
    getEbankRouter,
    getEbankFactory,
    getEbankPair,
    getTakerSigner,
    getTokenContract,
    getCTokenContract,
    getOrderbookContract,
    getCTokenFactoryContract,
    getContractByAddressABI,
    getContractByAddressName
}
