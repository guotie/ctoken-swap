import { BigNumber, BigNumberish, Contract, Signer } from 'ethers'
import {
            addressOf,
            getTokenContract,
            getOrderbookContract,
            getSigner,
            getTakerSigner,
            getETokenAddress,
            getCTokenContract,
            getProvider
        } from './contractHelper'
import { amountToCAmount } from './exchangeRate'

async function approve(token: Contract, spender: string, amount: BigNumberish) {
    await token.approve(spender, amount)
}

function logHr(title: string) {
    console.log('--------------------------  ' + title + '  --------------------------')
}

// 创建订单
async function createLimitOrder(
                    signer: Signer,
                    sellToken: string,
                    buyToken: string,
                    sellAmt: BigNumberish,
                    buyAmt: BigNumberish
                ) {
    // let sea = contractAddress[NETWORK]['SEA']
    //     , usdt = contractAddress[NETWORK]['USDT']
    //     , seaC = getTokenContract(sea, signer)
    let orderbook = addressOf('OrderBook')
        , obC = getOrderbookContract(orderbook, signer)
        , to = await signer.getAddress()
        , sellTokenC = getTokenContract(sellToken, signer)

    logHr('createLimitOrder')
    await sellTokenC.approve(orderbook, sellAmt.toString())
    let balanceBefore = await sellTokenC.balanceOf(to)
    let tx = await obC.createOrder(sellToken, buyToken, to, sellAmt.toString(), buyAmt.toString(), 0)
        , receipt =await tx.wait(1)
        , event = receipt.events[receipt.events.length - 1]
        , orderId = event.args[3]
        , balanceAfter = await sellTokenC.balanceOf(to)
    console.log('balance of sellToken(%s) Before CreateOrder: %s After: %s delta: %s',
                    sellToken,
                    balanceBefore.toString(),
                    balanceAfter.toString(),
                    balanceBefore.sub(balanceAfter).toString()
                    )
    console.log('orderId: ', orderId.toString())
    console.log('create limit order: sellToken=%s buyToken=%s sellAmt=%s expect buyAmt=%s',
                    sellToken,
                    buyToken,
                    sellAmt.toString(),
                    buyAmt.toString()
                    )
    return orderId;
}

// 取消订单
async function cancelOrder(
                    signer: Signer,
                    orderId: BigNumberish,
                    sellToken: string,
                    buyToken: string
                ) {
    let sellTokenC = getTokenContract(sellToken, signer)
        , buyTokenC = getTokenContract(buyToken, signer)
        , orderbook = addressOf('OrderBook')
        , obC = getOrderbookContract(orderbook, signer)
        , to = await signer.getAddress()

    logHr('cancelOrder')
    let balanceBefore = await sellTokenC.balanceOf(to)
    let balanceBefore2 = await buyTokenC.balanceOf(to)
    let tx = await obC.cancelOrder(orderId)
    await tx.wait(1)
    let balanceAfter = await sellTokenC.balanceOf(to)
    let balanceAfter2 = await buyTokenC.balanceOf(to)
    console.log('sell token %s balance Before CancelOrder: %s %s After: %s, changed: %s',
                    sellToken,
                    orderId.toString(),
                    balanceBefore.toString(),
                    balanceAfter.toString(),
                    balanceAfter.sub(balanceBefore).toString()
                )
    console.log('buy token %s balance Before CancelOrder: %s %s After: %s, changed: %s',
                    buyToken,
                    orderId.toString(),
                    balanceBefore2.toString(),
                    balanceAfter2.toString(),
                    balanceAfter2.sub(balanceBefore2).toString()
                )
}

// 成交订单
async function fufilOrder(
                    signer: Signer,
                    orderId: number | string,
                    token: string,           // 对于调用者来说, 卖出的 token
                    gotToken: string,        // 对于调用者来说, 买入得到的 token
                    amount: BigNumberish,    // 对于调用者来说, 卖出的 token 数量
                ) {
    let tokenC = getTokenContract(token, signer)
        , gotTokenC = getTokenContract(gotToken, signer)
        , orderbook = addressOf('OrderBook')
        , obC = getOrderbookContract(orderbook, signer)
        , factory = addressOf('CtokenFactory')
        , ctoken = await getETokenAddress(factory, token)
        , ctokenC = getCTokenContract(ctoken, getProvider())
        , camt = await amountToCAmount(ctokenC, amount)
        , taker = await signer.getAddress()

    await tokenC.approve(orderbook, amount)
    logHr('fufilOrder')
    console.log('taker: %s buyAmt: %s %s',
                    taker,
                    amount.toString(),
                    camt.toString()
                )
    let tokenBefore = await tokenC.balanceOf(taker)
        , gotTokenBefore = await gotTokenC.balanceOf(taker)

    let tx = await obC.fulfilOrder(orderId, camt, taker, true, true, [])
    await tx.wait(1)

    let tokenAfter = await tokenC.balanceOf(taker)
        , gotTokenAfter = await gotTokenC.balanceOf(taker)
    console.log('taker token %s balance before fulfil: %s, after fulfil: %s, changed: -%s',
                    token,
                    tokenBefore.toString(),
                    tokenAfter.toString(),
                    tokenBefore.sub(tokenAfter).toString()
                )
    console.log('taker token %s balance before fulfil: %s, after fulfil: %s changed: +%s',
                    gotToken,
                    gotTokenBefore.toString(),
                    gotTokenAfter.toString(),
                    gotTokenAfter.sub(gotTokenBefore).toString()
                )
}

// 取现: 已成交部分得到的币
async function withdrawUnderlying(
                    signer: Signer,
                    orderId: BigNumberish,
                    token: string,
                    gotToken: string
                ) {
    let tokenC = getTokenContract(token, signer)
        , gotTokenC = getTokenContract(gotToken, signer)
        , orderbook = addressOf('OrderBook')
        , obC = getOrderbookContract(orderbook, signer)
        , maker = await signer.getAddress()
        , tokenBefore = await tokenC.balanceOf(maker)
        , gotTokenBefore = await gotTokenC.balanceOf(maker)
        , factory = addressOf('ctokenFactory')
        , gotEToken = await getETokenAddress(factory, gotToken)
    
    logHr('withdrawUnderlying')
    let total = await obC.balanceOf(gotEToken, maker)
    console.log('maker %s balance of etoken %s: %s',
                    maker, gotEToken, total.toString())
    let tx = await obC.withdrawUnderlying(orderId, total)
    await tx.wait(1)

    let tokenAfter = await tokenC.balanceOf(maker)
        , gotTokenAfter = await gotTokenC.balanceOf(maker)
    console.log('maker token %s balance before withdraw: %s, after fulfil: %s, changed: -%s',
                    token,
                    tokenBefore.toString(),
                    tokenAfter.toString(),
                    tokenBefore.sub(tokenAfter).toString()
                )
    console.log('maker token %s balance before withdraw: %s, after fulfil: %s changed: +%s',
                    gotToken,
                    gotTokenBefore.toString(),
                    gotTokenAfter.toString(),
                    gotTokenAfter.sub(gotTokenBefore).toString()
                    )
}

// createLimitOrder()
// cancelOrder(1)

async function main() {
    const sea = addressOf('SEA')
        , usdt = addressOf('USDT')
        , srcAmt = BigNumber.from('10000000000000000000') // 10
        , guaranteeAmountOut = BigNumber.from('5000000') // 
        , dealAmt            = BigNumber.from('200000')
        , maker = getSigner()
        , taker = await getTakerSigner()

    // const orderId = await createLimitOrder(maker, sea, usdt, srcAmt, guaranteeAmountOut)
    // fulfil order about 2000000
    let orderId = 13
    await fufilOrder(taker, orderId, usdt, sea, dealAmt)
    // await withdrawUnderlying(maker, orderId, sea, usdt)
    // await cancelOrder(maker, orderId, sea, usdt)
}

// main()

export {
    createLimitOrder,
    cancelOrder,
    fufilOrder,
    withdrawUnderlying,
}
