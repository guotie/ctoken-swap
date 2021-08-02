import { BigNumber, BigNumberish, Contract } from 'ethers'

interface Swap {
    fa: string   // factory address
    fc?: Contract // factory contract
    ra: string   // router address
    rc?: Contract // router contract
}

