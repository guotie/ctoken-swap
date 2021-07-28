import { BigNumber, BigNumberish, Contract } from "ethers";

// 聚合交易

// 1. 根据 tokenIn tokenOut midTokens 获取参数 path列表 cpath 列表
// 2. 获取各个交易所的 reserve 列表 exchangeRate 等关键数据
// 3. 客户端计算最佳路径
// 3. 调用构建交易方法, 参数为路径列表, 构建交易体
//
const FLAG_TOKEN_IN_ETH      = BigNumber.from('0x000000000100')
const FLAG_TOKEN_IN_TOKEN    = BigNumber.from('0x000000000200')
const FLAG_TOKEN_IN_CTOKEN   = BigNumber.from('0x000000000400')
const FLAG_TOKEN_OUT_ETH     = BigNumber.from('0x000000000800')
const FLAG_TOKEN_OUT_TOKEN   = BigNumber.from('0x000000001000')
const FLAG_TOKEN_OUT_CTOKEN  = BigNumber.from('0x000000002000')

const EXCHANGE_UNISWAP_V2 = BigNumber.from(1);  // prettier-ignore
const EXCHANGE_UNISWAP_V3 = BigNumber.from(2);  // prettier-ignore
const EXCHANGE_EBANK_EX   = BigNumber.from(3);  // prettier-ignore
const EXCHANGE_CURVE      = BigNumber.from(4);  // prettier-ignore

const _SHIFT_COMPLEX_LEVEL  = 80
const zero = BigNumber.from(0)

// 交易所
interface Exchange {
    exFlag: BigNumber
    contractAddr: string
}

// calcExchangeListSwap 入参: 多个交易所的  SwapReserveRates
interface SwapReserveRates {
    // uint256 routes;           // distributeCounts
    // uint256 rateIn;
    // uint256 rateOut;
    // uint256[]  fees;
    // Exchange[]  exchanges;
    // address[][] paths;        // 由 midTokens 和 复杂度计算得到的所有 path 列表
    // address[][] cpaths;       // 由 midCTokens 和 复杂度计算得到的所有 cpath 列表
    // uint256[][] reserves;  // [routes][path]
    isEToken:     boolean
    allowBurnchi: boolean
    allEbank:     boolean
    ebankAmt:     BigNumber
    amountIn:     BigNumber
    swapRoutes:   number
    tokenIn:      string
    tokenOut:     string
    etokenIn:     string
    etokenOut:    string
    routes:       BigNumber
    rateIn:       BigNumber
    rateOut:      BigNumber
    fees:         BigNumber[]
    exchanges:    Exchange[]
    paths:        string[][]
    cpaths:       string[][]
    reserves:     BigNumber[][]
    distributes:  BigNumber[]
}

// 根据 x*y=K 计算 uniswap 的 amountOut
function calculateUniswapFormula(fromBalance: BigNumber, toBalance: BigNumber, amountIn: BigNumber): BigNumber {
    if (amountIn.eq(0)) {
        return zero;
    }

    return amountIn.mul(toBalance).mul(997).div(
            fromBalance.mul(1000).add(amountIn.mul(997))
        );
}

// 计算 uniswap 的兑换
// path: 兑换路径, eg: ['usdt address', 'wht address', 'wbtc address']
// amountIns: amountIn 被平均分为 parts 份
// reserves: path 数组相邻两个 token  构成的交易对的 reserve
function uniswapLikeSwap(path: string[], amountIns: BigNumber[], reserves: BigNumber[]): BigNumber[] {
    let tmp = new Array(path.length)
        , amountOuts: BigNumber[] = new Array(amountIns.length+1)

    amountOuts[0] = zero
    for (let i = 0; i < amountIns.length; i ++) {
        tmp[0] = amountIns[i];
        for (let j = 0; j < path.length - 1; j ++) {
            tmp[j + 1] = calculateUniswapFormula(reserves[j], reserves[j+1], tmp[j]);
        }
        amountOuts[i+1] = tmp[path.length-1];
    }

    return amountOuts
}

// 计算 ebank swap token 的兑换
// 需要考虑第一个 token 和最后一个 token 的 exchange rate
function ebankSwapTokens() {

}

function ebankSwapCTokens() {

}

function linearInterpolation(
                value: BigNumberish,
                parts: BigNumberish
            ): BigNumber[] {
    let amount = BigNumber.from(value)
        , total = BigNumber.from(parts).toNumber()
    let rets: BigNumber[] = new Array(total)

    for (let i = 0; i < total; i++) {
        rets[i] = amount.mul(i+1).div(total) // value.mul(i + 1).div(parts);
    }

    return rets
}


// 是否是 uniswap 类似的交易所
function isUniswapLikeExchange(flag: BigNumber): boolean {
    if (flag.eq(EXCHANGE_UNISWAP_V2) ||
        flag.eq(EXCHANGE_UNISWAP_V3) ||
        flag.eq(EXCHANGE_EBANK_EX) ) {
        return true;
    }
    return false;
}

function isEBankExchange(flag: BigNumber): boolean {
    if (flag.eq(EXCHANGE_EBANK_EX)) {
        return true;
    }
    return false;
}

// 计算所有交易所在不同的 path 下，不同的 amount 对应的交易量
function calcExchangeListSwap(parts: number, amountIn: BigNumberish, params: SwapReserveRates): BigNumber[][] {
    let len = params.exchanges.length
    let amountOuts: BigNumber[][] = new Array(len);
    let amountIns = linearInterpolation(amountIn, parts)

    for (let i = 0; i < len; i ++) {
        let ex = params.exchanges[i]
            , path = params.paths[i]
            , cpath = params.cpaths[i]
            , reserves = params.reserves[i]

        for (let j = 0; j < parts; j ++) {
            if (isEBankExchange(ex.exFlag)) {

            } else if (isUniswapLikeExchange(ex.exFlag)) {
                amountOuts[i] = uniswapLikeSwap(path, amountIns, reserves)
            } else {

            }
        }
    }

    return amountOuts
}

// 计算最佳兑换在各个交易所路径的分配比例
function findBestDistribution(s: number, amounts: BigNumber[][]) {
    let n = amounts.length
    let answer: BigNumber[][] = new Array(n) // new int256[][](n); // int[n][s+1]
    let parent: number[][] = new Array(n) // new uint256[][](n); // int[n][s+1]

    console.log('n: %d s: %d amounts[0].length: %d', n, s, amounts[0].length)
    for (let i = 0; i < n; i++) {
        answer[i] = new Array(s + 1);
        // for (let j = 0; j <= s; j ++) {
        //     answer[i][j] = zero;
        // }
        parent[i] = new Array(s + 1);
    }
    
    // 初始化
    for (let j = 0; j <= s; j++) {
        answer[0][j] = amounts[0][j];
        for (let i = 1; i < n; i++) {
            answer[i][j] = zero;
            // console.log(i, j, answer[i][j])
        }
        parent[0][j] = 0;
    }

    // 逐层比较
    for (let i = 1; i < n; i++) {
        for (let j = 0; j <= s; j++) {
            answer[i][j] = answer[i - 1][j];
            parent[i][j] = j;

            for (let k = 1; k <= j; k++) {
                // console.log(i, j, k, answer[i - 1][j - k], amounts[i][k], answer[i][j])
                if (answer[i - 1][j - k].add(amounts[i][k]).gt(answer[i][j])) {
                    answer[i][j] = answer[i - 1][j - k].add(amounts[i][k]);
                    parent[i][j] = j - k;
                }
            }
        }
    }
    
    // 根据上面比较的结果得到最佳分配比例
    let partsLeft = s;
    let distribution: number[] = new Array(n);
    for (let curExchange = n - 1; partsLeft > 0; curExchange--) {
        distribution[curExchange] = partsLeft - parent[curExchange][partsLeft];
        partsLeft = parent[curExchange][partsLeft];
    }

    let returnAmount = answer[n - 1][s].lte(0) ? zero : answer[n - 1][s]
        , swapRoutes = 0;
    console.log("return amount:", returnAmount.toString());
    for (let i = 0; i < n; i ++) {
        if (distribution[i] > 0) {
            swapRoutes ++;
        }
        // console.log("distribution[%d]: %d %d", i, distribution[i], amounts[i][s].toString());
    }

    return {
        swapRoutes: swapRoutes,
        returnAmount: returnAmount,
        distribution: distribution,
    }
}

// const e18 = BigNumber.from('1000000000000000000')

// function camtToAmt(camt: BigNumber, rate: BigNumber): BigNumber {
//     return camt.mul(rate).div(e18)
// }

// function amtToCamt(amt: BigNumber, rate: BigNumber): BigNumber {
//     return amt.mul(e18).div(rate)
// }

// 根据参数构建聚合交易参数
async function buildAggressiveSwapTx(
                    stepSwapC: Contract,
                    to: string,
                    tokenIn: string,
                    tokenOut: string,
                    midTokens: string[],
                    amountIn: BigNumber,
                    mainRoutes: number,
                    complex: number,
                    parts: number,
                ) {

    let routePath = await stepSwapC.getSwapReserveRates({
                                to: to,
                                tokenIn: tokenIn,
                                tokenOut: tokenOut,
                                amountIn: amountIn,
                                midTokens: midTokens,
                                mainRoutes: mainRoutes,
                                complex: complex,
                                parts: parts,
                                allowPartial: true,
                                allowBurnchi: true,
                            })
    
    console.log('route path:', routePath)
    let amounts = calcExchangeListSwap(parts, amountIn, routePath)
    // console.log('amouts:', amounts)
    let distributes = findBestDistribution(parts, amounts)

    // 根据 amountIn 和 分配比例, 计算每个兑换路径的 amount
    let idx = 0
        , total = zero
        , ebankAmt = zero
        , allEbank = false
        , distribution: BigNumber[] = new Array(distributes.distribution.length);

    /// amount 的分配
    /// 1. 如果是 ctoken, uniswap 需要把 ctoken redeem 为 token, uniswap 对应的 distribution 是 etoken 数量, 在合约中转换为对应的 token 数量比例;
    ///    ebank 对应的 distribution 是 etoken 数量
    /// 2. 如果是 token, uniswap 对应的是 token 数量, ebank 对应的也是 token 数量;
    for (let i = 0; i < distributes.distribution.length; i ++) {
        if (distributes.distribution[i] === 0) {
            distribution[i] = zero
            continue
        }

        let isEbank = false
        if (isEBankExchange(routePath.exchanges[i].exFlag)) {
            if (distributes.distribution[i] == parts) {
                allEbank = true
            }
            isEbank = true
        }
        let amt: BigNumber
        if (idx === routePath.swapRoutes - 1) {
            // 最后一份
            amt = amountIn.sub(total)
        } else {
            amt = amountIn.mul(distributes.distribution[i]).div(parts)
            total = total.add(amt)
        }
        distribution[i] = amt
        if (isEbank) {
            ebankAmt = amt
        }
        idx ++;
    }
    // todo minAmt
    let args: SwapReserveRates = {
        isEToken:     routePath.isEToken,
        allowBurnchi: routePath.allowBurnchi,
        allEbank:     allEbank,
        ebankAmt:     ebankAmt, // 单位为 tokenIn , 可能是 token 也可能是 etoken 的数量
        amountIn:     amountIn,
        swapRoutes:   distributes.swapRoutes,
        tokenIn:      routePath.tokenIn,
        tokenOut:     routePath.tokenOut,
        etokenIn:     routePath.etokenIn,
        etokenOut:    routePath.etokenOut,
        routes:       routePath.routes,
        rateIn:       routePath.rateIn,
        rateOut:      routePath.rateOut,
        fees:         routePath.fees,
        exchanges:    routePath.exchanges,
        paths:        routePath.paths,
        cpaths:       routePath.cpaths,
        reserves:     routePath.reserves,
        distributes:  distribution,
    }
    // routePath.allEbank = allEbank
    // routePath.ebankAmt = ebankAmt 

    return stepSwapC.buildSwapRouteSteps(args)
}

export {
    FLAG_TOKEN_IN_ETH,
    FLAG_TOKEN_IN_TOKEN,
    FLAG_TOKEN_IN_CTOKEN,
    FLAG_TOKEN_OUT_ETH,
    FLAG_TOKEN_OUT_TOKEN,
    FLAG_TOKEN_OUT_CTOKEN,

    uniswapLikeSwap,
    calcExchangeListSwap,
    findBestDistribution,
    buildAggressiveSwapTx
}
