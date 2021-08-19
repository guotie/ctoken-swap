import { IToken, printBalance, deadlineTs } from "./token"
import { BigNumberish, Contract } from "ethers"
import { getPairToken } from "./token"
import { callWithEstimateGas } from "./estimateGas"

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
    swapExactTokensForTokens
}
