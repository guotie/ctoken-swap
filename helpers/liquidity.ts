import { IToken, printBalance, deadlineTs } from "./token"
import { BigNumberish, Contract } from "ethers"
import { getPairToken } from "./token"
import { callWithEstimateGas } from "./estimateGas"
import { getEbankRouter, getTokenContract } from "./contractHelper"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"


const addLiquidityWithSigner = async (maker: SignerWithAddress, router: string, t0: string, t1: string, amt0: BigNumberish, amt1: BigNumberish) => {
    const routerC = getEbankRouter(undefined, maker)
        , t0c = getTokenContract(t0, maker)
        , t1c = getTokenContract(t1, maker)
        , to = maker.address
        , b0 = await t0c.balanceOf(to)
        , b1 = await t1c.balanceOf(to)
    
    if (b0.lt(amt0)) {
        throw new Error('not enought asset: ' + t0 + ' balance: ' + b0.toString() + ' expect: ' + amt0.toString())
    }
    if (b1.lt(amt1)) {
        throw new Error('not enought asset: ' + t1 + ' balance: ' + b1.toString() + ' expect: ' + amt1.toString())
    }
    
    await t0c.approve(router, amt0)
    await t1c.approve(router, amt1)
    let tx = await callWithEstimateGas(
            routerC,
            'addLiquidityUnderlying',
            [
                t0,
                t1,
                amt0,
                amt1,
                0,
                0,
                to,
                deadlineTs(100)
            ],
            true
        )
    await tx.wait(0)
}

const addLiquidity = async (router: Contract, t0: IToken, t1: IToken, amt0: BigNumberish, amt1: BigNumberish, to: string) => {
    await printBalance('Balance ' + to + ' before add liquidity', to, [t0, t1])
    await t0.contract!.approve(router.address, amt0)
    await t1.contract!.approve(router.address, amt1)
    let tx = await callWithEstimateGas(
            router,
            'addLiquidityUnderlying',
            [
                t0.address,
                t1.address,
                amt0,
                amt1,
                0,
                0,
                to,
                deadlineTs(100)
            ],
            true
        )

    await tx.wait(0)
    console.log('pairFor: ', t0.address, t1.address, await router.factory())
    let pair = await router.pairFor(t0.address, t1.address)
        , pairToken = await getPairToken(pair)
    await printBalance('Balance ' + to + ' after add liquidity', to, [t0, t1, pairToken])
}

const swapExactTokensForTokens = async (router: Contract, from: IToken, to: IToken, amtIn: BigNumberish, receiver: string) => {
    await printBalance('Balance ' + receiver + ' before swap', receiver, [from, to])
    await from.contract!.approve(router.address, amtIn)

    let tx = await callWithEstimateGas(
        router,
        'swapExactTokensForTokensUnderlying',
        [
            amtIn,
            0,
            [from.address, to.address],
            receiver,
            deadlineTs(100)
        ],
        true
    )
    await tx.wait(1)
    await printBalance('Balance ' + receiver + ' after swap', receiver, [from, to])
}

export {
    addLiquidity,
    addLiquidityWithSigner,
    swapExactTokensForTokens
}
