// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./library/SafeMath.sol";
import "./library/DataTypes.sol";
import "./library/SwapFlag.sol";
import "./library/PathFinder.sol";
import "./interface/IWETH.sol";
import "./interface/ICToken.sol";
import "./interface/ILHT.sol";
import "./interface/ICTokenFactory.sol";
import "./interface/IFactory.sol";
import "./Ownable.sol";
import "./Exchanges.sol";

import "hardhat/console.sol";

// 分步骤 swap, 可能的步骤
// 0. despot eth/ht
// 1. withdraw weth/wht
// 2. mint token (compound)
// 3. mint wht/ht (compound)
// 4. redeem ctoken (compound)
// 5. redeem wht/ht (compound)
// 6. uniswap v1
// 7. uniswap v2
// 8. curve stable
// 9. uniswap v3
// 
//
// tokenIn的情况:
// 1. ht
// 2. token
// 3. ctoken
//
// tokenOut的情况:
// 1. ht
// 2. token
// 3. ctoken
// 4. cht
//
//
// uniswap 只需要提供 router 地址，router 合约有 factory 地址
// 
// exchange 的类型
// 1. uniswap v1
// 2. uniswap v2, direct by pair 直接使用pair交易
// 3. uniswap v2, 使用router交易, 因为mdex可以交易挖矿
// 4. curve
//

contract StepSwapStorage {
    mapping(uint => DataTypes.Exchange) public exchanges;  // 
    uint public exchangeCount;  // exchange 数量
    IWETH public weth;
    ILHT public ceth;  // compound eth
    ICTokenFactory public ctokenFactory;
}

// contract StepSwap is BaseStepSwap {
contract StepSwap is Ownable, StepSwapStorage {
    using SafeMath for uint;
    using SafeMath for uint256;
    using SwapFlag for DataTypes.SwapFlagMap;

    constructor(address _weth, address _ceth, address _factory) public {
        weth = IWETH(_weth);
        ceth = ILHT(_ceth);
        ctokenFactory = ICTokenFactory(_factory);
    }

    /// @dev 在给定中间交易对数量和复杂度的情况下, 有多少种兑换路径
    function calcExchangeRoutes(uint midTokens, uint complexLevel) public view returns (uint total) {
        uint i;

        for (i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange storage ex = exchanges[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }

            total += Exchanges.getExchangeRoutes(ex.exFlag, midTokens, complexLevel);
        }
    }


    /// @dev 扣除 gas 费用后得到的
    /// @param amounts 未计算 gas 时兑换得到的数量
    /// @param gas gas, 单位 GWei
    /// @param tokenPriceGWei token 的价格相对于 GWei 的价格 token/ht * gas. 例如 tokenOut 为 usdt, eth 的价格为 2000 usdt, 此时, 将消耗的 gas 折算为
    ///                       usdt, 然后再 amounts 中扣减
    function _deductGasFee(
                uint[] memory amounts,
                uint gas,
                uint tokenPriceGWei
            )
            internal
            pure
            returns(int[] memory) {
        uint val = gas.mul(tokenPriceGWei);
        int256[] memory deducted = new int256[](amounts.length);

        for (uint i = 0; i < amounts.length; i ++) {
            uint amt = amounts[i];
            // if (amt > val) {
                deducted[i] = int256(amt) - int256(val);
            // } else {
                // 负数
                // deducted[i] = int256(amt).sub(int256(val));
            // }
        }

        return deducted;
    }

    /// @dev 计算uniswap类似的交易所的 return
    function _calcUnoswapExchangeReturn(
                DataTypes.Exchange memory ex,
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint tokenPriceGWei
            ) internal view returns (uint) {

        console.log("path: %d", sd.paths.length);
        for (uint i = 0; i < sd.paths.length; i ++) {
            uint[] memory amts;
            uint gas = 106000;  // uniswap v2

            // 是否是 ebankex 及 tokenIn, tokenOut 是否是 ctoken
            if (sd.isCtoken == false) {
                console.log("ex: %s  i: %d", ex.contractAddr, i);
                address[] memory path = sd.paths[i];
                console.log("path:", path[0], path[1]);
                amts = Exchanges.calcDistributes(ex, path, sd.amounts, sd.to);
                // if (sd.ctokenOut == true) {
                //     // 转换为 ctoken
                //     for (uint j = 0; j < sd.amounts.length; j ++) {
                //         amts[j] = amts[j].mul(1e18).div(sd.rateOut);
                //     }
                //     gas += 193404;
                // }
            } else {
                address[] memory cpath = sd.cpaths[i];
                amts = Exchanges.calcDistributes(ex, cpath, sd.cAmounts, sd.to);
                // if (sd.ctokenOut == true) {
                    // 转换为 ctoken
                    for (uint j = 0; j < sd.amounts.length; j ++) {
                        amts[j] = amts[j].mul(1e18).div(sd.rateOut);
                    }
                    // withdraw token 203573
                    // withdraw eth: 138300
                    // gas += 203573;
                    // deposit token 193404
                    // deposit eth   160537
                    gas += 203573 + 193404;
                // }
            }
            sd.pathIdx[idx + i] = i;
            sd.distributes[idx + i] = amts;
            sd.exchanges[idx + i] = ex;
            sd.netDistributes[idx + i] = _deductGasFee(amts, gas, tokenPriceGWei);
            sd.gases[idx] = gas;
        }

        console.log("_calcUnoswapExchangeReturn done");
        return sd.paths.length;
    }

    /// @dev ebankex 兑换数量
    function _calcEbankExchangeReturn(
                DataTypes.Exchange memory ex,
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint tokenPriceGWei
            )
            internal
            view
            returns (uint) {

        for (uint i = 0; i < sd.cpaths.length; i ++) {
            uint gas = 106000;  // todo ebank swap 的 gas 费用
            address[] memory path = sd.cpaths[i];
            uint[] memory amts;

            // ebankex tokenIn 都是 ctoken, tokenOut 是否是 ctoken

            // withdraw token 203573
            // withdraw eth: 138300
            // gas += ;
            amts = Exchanges.calcDistributes(ex, path, sd.cAmounts, sd.to);
            if (sd.isCtoken == false) {
                // 转换为 token redeem
                for (uint j = 0; j < sd.amounts.length; j ++) {
                    amts[j] = amts[j].mul(sd.rateOut).div(1e18);
                }
                // deposit token 193404
                // deposit eth   160537
                // mint 为 ctoken
                gas += 193404 + 203573;
            }
        
            sd.pathIdx[idx + i] = i;
            sd.distributes[idx + i] = amts;
            sd.exchanges[idx + i] = ex;
            sd.netDistributes[idx + i] = _deductGasFee(amts, gas, tokenPriceGWei);
        
            sd.gases[idx] = gas;
        }
        return sd.paths.length;
    }

    /// @dev _makeSwapDistributes 构造参数
    function _makeSwapDistributes(
                DataTypes.QuoteParams calldata args,
                uint distributeCounts
            )
            internal
            view
            returns (DataTypes.SwapDistributes memory swapDistributes) {
        swapDistributes.to = args.to;
        swapDistributes.tokenIn = args.tokenIn;
        swapDistributes.tokenOut = args.tokenOut;
        swapDistributes.isCtoken = args.flag.tokenIsCToken();
        // swapDistributes.ctokenOut = args.flag.tokenOutIsCToken();
        uint parts = args.flag.getParts();
        swapDistributes.parts = parts;

        console.log("parts: %d isCtoken:", parts, swapDistributes.isCtoken);

        address tokenIn;
        address tokenOut;
        address ctokenIn;
        address ctokenOut;
        if (swapDistributes.isCtoken) {
            swapDistributes.cAmounts = Exchanges.linearInterpolation(args.amountIn, parts);
            // 获取 token 对应的 ctoken 地址
            ctokenIn = args.tokenIn;
            tokenIn = ctokenFactory.getTokenAddress(ctokenIn);
            swapDistributes.amounts = Exchanges.convertCompoundTokenRedeemed(ctokenIn, swapDistributes.cAmounts, parts);
            // new uint[](parts);
            // // amount = cAmount * exchangeRate
            // for (uint i = 0; i < parts; i ++) {
            //     swapDistributes.amounts[i] = Exchanges.convertCompoundTokenRedeemed(ctokenIn, swapDistributes.cAmounts[i]);
            // }
        } else {
            tokenIn = args.tokenIn;
            ctokenIn = ctokenFactory.getCTokenAddressPure(tokenIn);
            swapDistributes.amounts = Exchanges.linearInterpolation(args.amountIn, parts);
            swapDistributes.cAmounts = Exchanges.convertCompoundCtokenMinted(ctokenIn, swapDistributes.amounts, parts);
            // new uint[](parts);
            // // amount = cAmount * exchangeRate
            // for (uint i = 0; i < parts; i ++) {
            //     swapDistributes.cAmounts[i] = Exchanges.convertCompoundCtokenMinted(ctokenIn, swapDistributes.cAmounts[i]);
            // }
        }

        if (swapDistributes.isCtoken) {
            tokenOut = ctokenFactory.getTokenAddress(args.tokenOut);
            ctokenOut = args.tokenOut;
        } else {
            tokenOut = args.tokenOut;
            ctokenOut = ctokenFactory.getCTokenAddressPure(tokenOut);
        }

        swapDistributes.gases          = new uint[]  (distributeCounts); // prettier-ignore
        swapDistributes.pathIdx        = new uint[]  (distributeCounts); // prettier-ignore
        swapDistributes.distributes    = new uint[][](distributeCounts); // prettier-ignore
        swapDistributes.netDistributes = new int[][](distributeCounts);  // prettier-ignore
        swapDistributes.exchanges      = new DataTypes.Exchange[](distributeCounts);
        
        uint mids = args.midTokens.length;
        address[] memory midTokens = new address[](mids);
        address[] memory midCTokens = new address[](mids);
        for (uint i = 0; i < mids; i ++) {
            midTokens[i] = args.midTokens[i];
            midCTokens[i] = ctokenFactory.getCTokenAddressPure(args.midTokens[i]);
        }
        swapDistributes.midTokens = midTokens;
        swapDistributes.midCTokens = midCTokens;

        swapDistributes.paths = Exchanges.allPaths(tokenIn, tokenOut, midTokens, args.flag.getComplexLevel());
        swapDistributes.cpaths = Exchanges.allPaths(ctokenIn, ctokenOut, midCTokens, args.flag.getComplexLevel());
    }

    /// @dev 根据入参计算在各个交易所分配的资金比例及交易路径(步骤)
    function getExpectedReturnWithGas(
                DataTypes.QuoteParams calldata args
            )
            external
            view
            returns (DataTypes.SwapParams memory) {
        // DataTypes.SwapFlagMap memory flag = args.flag;
        // require(flag.tokenInIsCToken() == flag.tokenOutIsCToken(), "both token or etoken"); // 输入输出必须同时为 token 或 ctoken
        require(exchangeCount > 0, "no exchanges");

        console.log("tokenIn: %s tokenOut: %s", args.tokenIn, args.tokenOut);

        // bool ctokenIn = flag.tokenInIsCToken();
        // bool ctokenOut = flag.tokenOutIsCToken();
        uint distributeCounts = calcExchangeRoutes(args.midTokens.length, args.flag.getComplexLevel());
        uint distributeIdx = 0;
        uint tokenPriceGWei = args.tokenPriceGWei;
        DataTypes.SwapDistributes memory swapDistributes = _makeSwapDistributes(args, distributeCounts);
        console.log("routes:", distributeCounts);

        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange memory ex = exchanges[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }

            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                if (Exchanges.isEBankExchange(ex.exFlag)) {
                    distributeIdx += _calcEbankExchangeReturn(ex, swapDistributes, distributeIdx, tokenPriceGWei);
                } else {
                    distributeIdx += _calcUnoswapExchangeReturn(ex, swapDistributes, distributeIdx, tokenPriceGWei);
                }
            } else {
                // curve todo
            }
        }
        // todo desposit eth withdraw eth 的 gas 费用
        console.log("calc done");

        // 根据 dist 构建交易步骤
        DataTypes.SwapParams memory params;
        params.flag = args.flag;
        _makeSwapSteps(args.amountIn, swapDistributes, params);
        return params;
    }


    /// @dev 构建兑换步骤
    function _makeSwapSteps(
                uint amountIn,
                DataTypes.SwapDistributes memory sd,
                DataTypes.SwapParams memory params
            )
            private
            view {
        (, uint[] memory dists) = PathFinder.findBestDistribution(sd.parts, sd.netDistributes);
        // todo 计算 amountOut

        uint steps = 0;
        uint routeIdx = 0;
        for (uint i = 0; i < dists.length; i ++) {
            if (dists[i] > 0) {
                steps ++;
            }
        }

        bool allEbank = _allSwapByEBank(sd, dists);
        if (allEbank) {
            // 全部都是由 ebank
            // if (sd.ctokenIn != sd.ctokenOut) {
            //     // 如果全部由 ebank 兑换
            //     routes ++;
            // }
            return _buildEBankSteps(steps, amountIn, dists, sd, params);
        }

        if (sd.isCtoken) {
            // redeem ctoken, mint token
            steps += 2;
        }
        DataTypes.StepExecuteParams[] memory stepArgs = new DataTypes.StepExecuteParams[](steps);

        if (sd.isCtoken) {
            /*
            address ctokenIn = sd.cpaths[0][0];
            address ctokenOut = sd.cpaths[0][sd.cpaths[0].length-1];
            // ebank 交易的量
            (uint ebankParts, uint ebankAmt) = _calcEBankAmount(amountIn, sd, dists);
            uint remaining = amountIn.sub(ebankAmt);
            uint uniswapParts = sd.parts - ebankParts;
            if (remaining > 0) {
                // redeem
                stepArgs[0] = _makeCompoundRedeemStep(remaining, ctokenIn);
                routeIdx ++;
                // todo remaining 转换为 token 数量
            }
            // 最后一个类 uniswap 的交易所 index
            // (int256 lastUniswapIdx, int256 lastEbankIdx) = _getLastSwapIndex(sd, dists);
            for (uint i = 0; i < dists.length; i ++) {
                if (dists[i] <= 0) {
                    continue;
                }


                DataTypes.Exchange memory ex = sd.exchanges[i];
                if (Exchanges.isEBankExchange(ex.exFlag)) {
                    // todo 区分最后一个 ebank
                    uint amt = _partAmount(amountIn, dists[i], sd.parts);
                    stepArgs[routeIdx] = _buildEBankSwapSteps(amt, i, true, sd);
                } else if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                    // todo 区分最后一个 uniswap 
                    uint amt = _partAmount(remaining, dists[i], uniswapParts);
                    stepArgs[routeIdx] = _buildUniswapLikeSteps(amt, i, true, sd);
                } else {
                    // todo curve, etc
                }
                routeIdx ++;
                // 计算 routes
            }
            */
            _fillStepArgs(amountIn, routeIdx, dists, sd, stepArgs);
            // 将 uniswap 兑换的 token mint to ctoken
            address ctokenOut = sd.cpaths[0][sd.cpaths[0].length-1];
            stepArgs[routeIdx] = _makeCompoundMintStep(0, ctokenOut);
        } else {
            for (uint i = 0; i < dists.length; i ++) {
                if (dists[i] <= 0) {
                    continue;
                }
                DataTypes.Exchange memory ex = sd.exchanges[i];
                uint amt = _partAmount(amountIn, dists[i], sd.parts);
                if (Exchanges.isEBankExchange(ex.exFlag)) {
                    stepArgs[routeIdx] = _buildEBankSwapSteps(amt, i, false, sd);
                } else if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                    stepArgs[routeIdx] = _buildUniswapLikeSteps(amt, i, true, sd);
                } else {
                    // todo curve, etc
                }
                routeIdx ++;
            }
        }

        params.steps = stepArgs;
    }


    function _fillStepArgs(
                uint amountIn,
                uint routeIdx,
                uint[] memory dists,
                DataTypes.SwapDistributes memory sd,
                DataTypes.StepExecuteParams[] memory stepArgs
            )
            private
            view {

        address ctokenIn = sd.cpaths[0][0];
        // ebank 交易的量
        (uint ebankParts, uint ebankAmt) = _calcEBankAmount(amountIn, sd, dists);
        uint remaining = amountIn.sub(ebankAmt);
        uint uniswapParts = sd.parts - ebankParts;
        if (remaining > 0) {
            // redeem
            stepArgs[0] = _makeCompoundRedeemStep(remaining, ctokenIn);
            routeIdx ++;
            // todo remaining 转换为 token 数量
        }

        // 最后一个类 uniswap 的交易所 index
        (int256 lastUniswapIdx, int256 lastEbankIdx) = _getLastSwapIndex(sd, dists);
        for (uint i = 0; i < dists.length; i ++) {
            if (dists[i] <= 0) {
                continue;
            }

            DataTypes.Exchange memory ex = sd.exchanges[i];
            if (Exchanges.isEBankExchange(ex.exFlag)) {
                // todo 区分最后一个 ebank
                uint amt = _partAmount(amountIn, dists[i], sd.parts);
                stepArgs[routeIdx] = _buildEBankSwapSteps(amt, i, true, sd);
            } else if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                // todo 区分最后一个 uniswap 
                uint amt = _partAmount(remaining, dists[i], uniswapParts);
                stepArgs[routeIdx] = _buildUniswapLikeSteps(amt, i, true, sd);
            } else {
                // todo curve, etc
            }
            routeIdx ++;
            // 计算 routes
        }
    }

    /// amt * part / totalParts
    function _partAmount(uint amt, uint part, uint totalParts) private pure returns (uint) {
        return amt.mul(part).div(totalParts);
    }

    function _getEBankContract() private view returns (address ebank) {
        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange memory ex = exchanges[i];
            if (ex.exFlag == Exchanges.EXCHANGE_EBANK_EX && ex.contractAddr != address(0)) {
                ebank = ex.contractAddr;
                break;
            }
        }
        require(ebank != address(0), "not found ebank");
        return ebank;
    }

    function _buildUniswapLikeSteps(
                uint amt,
                uint idx,
                bool useRouter,
                DataTypes.SwapDistributes memory sd
            )
            private
            view
            returns (DataTypes.StepExecuteParams memory params) {
        if (useRouter) {
            _makeUniswapLikeRouteStep(amt, idx, sd);
        }
        return _makeUniswapLikePairStep(amt, idx, sd);
    }

    function _buildEBankSwapSteps(
                uint amt,
                uint idx,
                bool isCToken,
                DataTypes.SwapDistributes memory sd
            )
            private
            pure
            returns (DataTypes.StepExecuteParams memory params) {
        // DataTypes.Exchange memory ex = sd.exchanges[idx];

        if (isCToken) {
            return _makeEBankRouteStep(
                        DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
                        amt,
                        sd.exchanges[idx].contractAddr,
                        sd.cpaths[sd.pathIdx[idx]]
                    );
        } else {
            if (sd.tokenIn == address(0)) {
                /// eth -> token
                return _makeEBankRouteStep(
                            DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
                            amt,
                            sd.exchanges[idx].contractAddr,
                            sd.paths[sd.pathIdx[idx]]
                        );
                // routeIdx ++;
            } else if (sd.tokenOut == address(0)) {
                /// token -> eth
                return _makeEBankRouteStep(
                            DataTypes.STEP_EBANK_ROUTER_TOKENS_ETH,
                            amt,
                            sd.exchanges[idx].contractAddr,
                            sd.paths[sd.pathIdx[idx]]
                        );
            } else {
                /// token -> token
                return _makeEBankRouteStep(
                            DataTypes.STEP_EBANK_ROUTER_TOKENS_TOKENS,
                            amt,
                            sd.exchanges[idx].contractAddr,
                            sd.paths[sd.pathIdx[idx]]
                        );
            }
        }
    }

    /// @dev _buildEBankSteps ebank 的交易指令, 8 类情况:
    /// ctokenIn, ctokenOut: swapExactTokensForTokens
    /// tokenIn, tokenOut: swapExactTokensForTokensUnderlying / swapExactETHForTokensUnderlying / swapExactTokensForETHUnderlying
    /// ctokenIn, tokenOut: swapExactTokensForTokens, redeem / redeemCETH
    /// tokenIn, ctokenOut: mint / mintETH, swapExactTokensForTokens
    function _buildEBankSteps(
                uint steps,
                uint amountIn,
                uint[] memory dists,
                DataTypes.SwapDistributes memory sd,
                DataTypes.SwapParams memory params
            )
            private
            pure {
        uint routeIdx = 0;
        uint parts = sd.parts;
        uint remaining = amountIn;
        // address ebank = _getEBankContract();
        params.steps = new DataTypes.StepExecuteParams[](steps);


        // if (sd.ctokenIn == sd.ctokenOut) {
            for (uint i = 0; i < dists.length; i ++) {
                if (dists[i] > 0) {
                    // swap
                    uint amt;
                    if (routeIdx == steps - 1) {
                        amt = remaining;
                    } else {
                        amt = _partAmount(amountIn, dists[i], parts);
                        remaining -= amt;
                    }
                    if (sd.isCtoken) {
                        // ctoken in, ctokenout
                        params.steps[routeIdx] = _makeEBankRouteStep(
                                                    DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
                                                    amt,
                                                    sd.exchanges[i].contractAddr,
                                                    sd.cpaths[sd.pathIdx[i]]
                                                );
                        routeIdx ++;
                    } else {
                        // token in, token out
                        // swapUnderlying / swapETHUnderlying
                        if (sd.tokenIn == address(0)) {
                            /// eth -> token
                            params.steps[routeIdx] = _makeEBankRouteStep(
                                                        DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
                                                        amt,
                                                        sd.exchanges[i].contractAddr,
                                                        sd.paths[sd.pathIdx[i]]
                                                    );
                            routeIdx ++;
                        } else if (sd.tokenOut == address(0)) {
                            /// token -> eth
                            params.steps[routeIdx] = _makeEBankRouteStep(
                                                        DataTypes.STEP_EBANK_ROUTER_TOKENS_ETH,
                                                        amt,
                                                        sd.exchanges[i].contractAddr,
                                                        sd.paths[sd.pathIdx[i]]
                                                    );
                        } else {
                            /// token -> token
                            params.steps[routeIdx] = _makeEBankRouteStep(
                                                        DataTypes.STEP_EBANK_ROUTER_TOKENS_TOKENS,
                                                        amt,
                                                        sd.exchanges[i].contractAddr,
                                                        sd.paths[sd.pathIdx[i]]
                                                    );
                        }
                    }
                }
            }
            return;
        // }
        // not allowed !!!
        // sd.ctokenIn != sd.ctokenOut
        // if (sd.ctokenIn) {
        //     // ctoken in, token out: swapExactTokensForTokens, redeem / redeemCETH
        //     for (uint i = 0; i < dists.length; i ++) {
        //         if (dists[i] > 0) {
        //             // swap
        //             uint amt;
        //             if (routeIdx == routes - 1) {
        //                 amt = remaining;
        //             } else {
        //                 amt = _partAmount(amountIn, dists[i], parts);
        //                 remaining -= amt;
        //             }
        //         }
        //         params.steps[routeIdx] = _makeEBankRouteStep(
        //                                     DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
        //                                     amt,
        //                                     sd.exchanges[i].contractAddr,
        //                                     sd.cpath[sd.pathIdx[i]]
        //                                 );
        //         routeIdx ++;
        //     }
        //     // redeem
        //     params.steps[routeIdx] =_makeCompoundRedeemStep(0, sd.tokenOut);
        // } else {
        //     // token in, ctoken out
        //     for (uint i = 0; i < dists.length; i ++) {
        //         if (dists[i] > 0) {
        //             // swap
        //             uint amt;
        //             if (routeIdx == routes - 1) {
        //                 amt = remaining;
        //             } else {
        //                 amt = _partAmount(amountIn, dists[i], parts);
        //                 remaining -= amt;
        //             }
        //         }
        //         uint flag;
        //         if (sd.tokenIn == address(0)) {
        //             // ht in
        //             flag = DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS;
        //         } else {
        //             flag = 
        //         }
        //         params.steps[routeIdx] = _makeEBankRouteStep(
        //                                     flag,
        //                                     amt,
        //                                     sd.exchanges[i].contractAddr,
        //                                     sd.cpath[sd.pathIdx[i]]
        //                                 );
        //     }
        // }
    }

    function _makeCompoundMintStep(
                uint amt,
                address ctoken
            )
            private 
            view
            returns (DataTypes.StepExecuteParams memory step) {
        address token = ctokenFactory.getTokenAddress(ctoken);

        // todo 是否可以用 weth 来做判断
        if (token == address(0) || token == address(weth)) {
            step.flag = DataTypes.STEP_COMPOUND_MINT_CETH;
        } else {
            step.flag = DataTypes.STEP_COMPOUND_MINT_CTOKEN;
        }
        DataTypes.CompoundRedeemParam memory rp;
        rp.amount = amt;
        rp.ctoken = ctoken;
        // if (direct) {
        //     rp.to = sd.to;
        // } else {
            // rp.to = address(this);
        // }
        step.data = abi.encode(rp);
    }

    /// @dev 构建 redeem 步骤的合约地址及参数
    /// @param amt redeem amount, if 0, redeem all(balanceOf(address(this)))
    function _makeCompoundRedeemStep(
                uint amt,
                address ctoken
            )
            private 
            pure
            returns (DataTypes.StepExecuteParams memory step) {
        // address ctoken;
        // if (tokenOut == address(0)) {
        //     ctoken = ceth;
        // } else {
        //     // step.flag = DataTypes.STEP_COMPOUND_REDEEM_TOKEN;
        //     ctoken = ctokenFactory.getCTokenAddressPure(tokenOut);
        // }
        // eth 和 token 都是调用同一个方法 redeem, 且参数相同, 因此，使用同一个 flag
        step.flag = DataTypes.STEP_COMPOUND_REDEEM_TOKEN;
        DataTypes.CompoundRedeemParam memory rp;
        rp.amount = amt;
        rp.ctoken = ctoken;
        // if (direct) {
        //     rp.to = sd.to;
        // } else {
            // rp.to = address(this);
        // }
        step.data = abi.encode(rp);
    }

    /// @dev 兑换合约地址及参数
    /// @param amt 待兑换的 token 数量
    /// @param idx sd 数组索引
    /// @param sd swap distributes
    function _makeUniswapLikeRouteStep(
                uint amt,
                uint idx,
                DataTypes.SwapDistributes memory sd
                // bool direct
            )
            private 
            pure
            returns (DataTypes.StepExecuteParams memory step) {
        // todo flag 根据 输入 token 输出 token 决定
        step.flag = sd.exchanges[idx].exFlag;

        DataTypes.UniswapRouterParam memory rp;
        rp.contractAddr = sd.exchanges[idx].contractAddr;
        rp.amount = amt;
        // if (direct) {
        //     rp.to = sd.to;
        // } else {
            // rp.to = address(this);
        // }
        rp.path = sd.paths[sd.pathIdx[idx]];
        step.data = abi.encode(rp);
    }

    function _makeUniswapLikePairStep(
                uint amt,
                uint idx,
                DataTypes.SwapDistributes memory sd
                // bool direct
            )
            private 
            view
            returns (DataTypes.StepExecuteParams memory step) {

        IFactory factory = IFactory(IRouter(sd.exchanges[idx].contractAddr).factory());
        DataTypes.UniswapPairParam memory rp;

        rp.amount = amt;
        // if (direct) {
        //     rp.to = sd.to;
        // } else {
            // rp.to = address(this);
        // }
        // 构造 pair
        address[] memory paths = sd.paths[sd.pathIdx[idx]];
        rp.pairs = new address[](paths.length-1);
        for (uint i = 0; i < paths.length-2; i ++) {
            rp.pairs[i] = factory.getPair(paths[i], paths[i+1]);
        }

        step.flag = sd.exchanges[idx].exFlag;
        step.data = abi.encode(rp);
    }

    function _makeEBankRouteStep(
                uint flag,
                uint amt,
                address ebank,
                address[] memory path
                // bool direct
            )
            private 
            pure
            returns (DataTypes.StepExecuteParams memory step) {
        step.flag = flag;
        DataTypes.UniswapRouterParam memory rp;
        rp.amount = amt;
        rp.contractAddr = ebank;
        // if (direct) {
        //     rp.to = sd.to;
        // } else {
            // rp.to = address(this);
        // }
        rp.path = path;
        step.data = abi.encode(rp);
    }

    // 是否所有的 amount 都是由 ebank 兑换
    function _getLastSwapIndex(
                    DataTypes.SwapDistributes memory sd,
                    uint[] memory distributes
                )
                private
                pure
                returns (int256 uniswapIdx, int256 ebankIdx) {
        uniswapIdx = -1;
        ebankIdx = -1;
        for (uint i = 0; i < distributes.length; i ++) {
            if (distributes[i] > 0) {
                uint flag = sd.exchanges[i].exFlag;
                // 该 swap 不是 ebank
                if (Exchanges.isEBankExchange(flag)) {
                    ebankIdx = int256(i);
                } else if (Exchanges.isUniswapLikeExchange(flag)) {
                    uniswapIdx = int256(i);
                }
            }
        }
    }

    // 是否所有的 amount 都是由 ebank 兑换
    function _allSwapByEBank(
                    DataTypes.SwapDistributes memory sd,
                    uint[] memory distributes
                )
                private
                pure
                returns (bool) {
        for (uint i = 0; i < distributes.length; i ++) {
            if (distributes[i] > 0) {
                // 该 swap 不是 ebank
                if (Exchanges.isEBankExchange(sd.exchanges[i].exFlag) == false) {
                    return false;
                }
            }
        }

        return true;
    }

    // 是否所有的 amount 都是由 ebank 兑换
    function _calcEBankAmount(
                    uint amountIn,
                    DataTypes.SwapDistributes memory sd,
                    uint[] memory distributes
                )
                private
                pure
                returns (uint part, uint amt) {
        // uint part = 0;
        
        for (uint i = 0; i < distributes.length; i ++) {
            if (distributes[i] > 0) {
                // 该 swap 是 ebank
                if (Exchanges.isEBankExchange(sd.exchanges[i].exFlag)) {
                    part += distributes[i];
                }
            }
        }

        amt = _partAmount(amountIn, part, sd.parts);
    }

    /// @dev 根据参数执行兑换
    function unoswap(DataTypes.SwapParams calldata args) public payable returns (DataTypes.StepExecuteParams[] memory) {
        args;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    

    function addExchange(uint flag, address addr) external onlyOwner {
        DataTypes.Exchange storage ex = exchanges[exchangeCount];
        ex.exFlag = flag;
        ex.contractAddr = addr;

        exchangeCount ++;
    }

    function removeExchange(uint i) external onlyOwner {
        DataTypes.Exchange storage ex = exchanges[i];

        ex.contractAddr = address(0);
    }

    function setWETH(address _weth) external onlyOwner {
        weth = IWETH(_weth);
    }

    function setCETH(address _ceth) external onlyOwner {
        ceth = ILHT(_ceth);
    }

    function setCtokenFactory(address factory) external onlyOwner {
        ctokenFactory = ICTokenFactory(factory);
    }
}
