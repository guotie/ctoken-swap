import { BigNumber, BigNumberish, Contract } from 'ethers'

interface ISwap {
    fa: string   // factory address
    fc?: Contract // factory contract
    ra: string   // router address
    rc?: Contract // router contract
}

export {
    ISwap
}
