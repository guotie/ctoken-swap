import { BigNumber, Contract, BigNumberish } from 'ethers'
import { getProvider } from './contractHelper'
// import { BigNumber, BigNumberish, Contract } from 'ethers'

const e18 = BigNumber.from('1000000000000000000')

export const getBlockNumber = async () => {
    return getProvider().getBlockNumber()
}

// 计算 ctoken 当前的 exchangeRate
export const getCTokenRate = async (ctoken: Contract) => {
    let rate = await ctoken.exchangeRateStored()
    let supplyRate = await ctoken.supplyRatePerBlock();
    let lastBlock = await ctoken.accrualBlockNumber();
    let block = await getBlockNumber()
    // console.log(block, lastBlock.toString())
    let blocks = BigNumber.from(block).sub(lastBlock)
    let inc =  rate.mul(supplyRate).mul(blocks);
    rate = rate.add(inc);
    console.log('ctoken exchange rate: %s', rate.toString())
    return rate
}

// ctoken 数量转换为对应的 token 数量
// amt = camt * exchangeRate
export const camtToAmount = async (ctoken: Contract, camt: BigNumberish) => {
    let rate = await getCTokenRate(ctoken)

    let amt = BigNumber.from(camt).mul(rate).div(e18) // .add(1)
    console.log('camtToAmount: camt=%s amt=%s', camt.toString(), amt.toString())
    return amt
}

// token 数量转换为对应的 ctoken 数量
// camt = amt / exchangeRate
export const amountToCAmount = async (ctoken: Contract, amt: BigNumberish) => {
    let rate = await getCTokenRate(ctoken)

    let camt = BigNumber.from(amt).mul(e18).div(rate)
    console.log('amountToCAmount: amt=%s camt=%s', amt.toString(), camt.toString())
    return camt
}
