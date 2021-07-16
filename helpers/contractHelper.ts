import { Contract, Signer } from 'ethers'
import {  Provider } from '@ethersproject/abstract-provider'

import { abi as ctokenABI } from './abis/CToken.json'
import { abi as tokenABI } from './abis/Token.json'

function getTokenContract(address: string, signerOrProvider?: Signer | Provider) {
    return new Contract(address, tokenABI, signerOrProvider)
}

function getCTokenContract(address: string, signerOrProvider?: Signer | Provider) {
    return new Contract(address, ctokenABI, signerOrProvider)
}

export {
    getTokenContract,
    getCTokenContract
}
