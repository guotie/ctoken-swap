import { BigNumber, Contract } from "ethers";

interface IToken {
    name: string
    symbol: string
    decimals: number
    totalSupply: BigNumber
    address: string
    contract?: Contract
}
