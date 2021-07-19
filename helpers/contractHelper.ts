import { Contract, Signer, Wallet, providers } from 'ethers'
import {  Provider } from '@ethersproject/abstract-provider'
import 'dotenv/config';

import { abi as ctokenABI } from './abi/CToken.json'
import { abi as tokenABI } from './abi/Token.json'
import { abi as orderBookABI } from './abi/OrderBook.json'
import { abi as ctokenFactoryABI } from './abi/LErc20DelegatorFactory.json'

let contractAddress: { [index: string]: { [index: string]: string } } = {
    'hecotest': {
        'USDT': '0x04F535663110A392A6504839BEeD34E019FdB4E0',
        'SEA': '0xEe798D153F3de181dE16DedA318266EE8Ad56dEA',
        'WETH': '',
        'CETH': '',
        'comptroller': '',
        'ctokenFactory': '0xC65d5ea738F466FEb518b6079732C7b03eE04CF0',
        'Factory': '',
        'Router': '',
        'OrderBook': '0x6545A6C3B6f28121CC7c65882b49023eE27Eaef0',
    },
    'hardhat' : {
        'USDT': '',
        'SEA': '',
        'WETH': '',
        'CETH': '',
        'comptroller': '',
        'ctokenFactory': '',
        'Factory': '',
        'Router': '',
        'OrderBook': '',
    }
}

const endpoints: { [index: string]: string } = {
    'hecotest': 'https://http-testnet.hecochain.com'
}

let NETWORK: string = 'hecotest'

type NetworkType = 'hardhat' | 'hecotest'
type ContractName = 'USDT' 
                    | 'SEA'
                    | 'WETH'
                    | 'CETH'
                    | 'comptroller'
                    | 'ctokenFactory'
                    | 'Factory'
                    | 'Router'
                    | 'OrderBook'

function setNetwork(n: NetworkType) {
    NETWORK = n
}

function setContractAddress(name: ContractName, addr: string) {
    contractAddress[NETWORK][name] = addr
}

function addressOf(name: 'USDT' 
                        | 'SEA'
                        | 'WETH'
                        | 'CETH'
                        | 'comptroller'
                        | 'ctokenFactory'
                        | 'Factory'
                        | 'Router'
                        | 'OrderBook'
                    ): string {
    return contractAddress[NETWORK][name]
}

function getProvider() {
    return new providers.JsonRpcProvider(endpoints[NETWORK])
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

// 获取 eToken 对应的 token 地址
async function getTokenAddress(factory: string, etoken: string) {
    let ctokenFactory = getCTokenFactoryContract(factory) // addressOf('ctokenFactory'))
    return ctokenFactory.getTokenAddress(etoken)
}

// 获取 token 对应的 etoken 地址
async function getETokenAddress(factory: string, token: string) {
    let ctokenFactory = getCTokenFactoryContract(factory) // addressOf('ctokenFactory'))
    return ctokenFactory.getCTokenAddressPure(token)
}

function getOrderbookContract(address = contractAddress[NETWORK]['OrderBook'], signerOrProvider?: Signer | Provider) {
    return new Contract(address, orderBookABI, signerOrProvider)
}

export {
    NETWORK,
    addressOf,
    // contractAddress,
    getProvider,
    getSigner,
    getTokenAddress,
    getETokenAddress,
    getTakerSigner,
    getTokenContract,
    getCTokenContract,
    getOrderbookContract,
    getCTokenFactoryContract
}
