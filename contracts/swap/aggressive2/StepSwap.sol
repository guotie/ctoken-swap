// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./library/SafeMath.sol";
import "./library/DataTypes.sol";
import "./library/SwapFlag.sol";
import "./library/PathFinder.sol";
import "./interface/IWETH.sol";
import "./interface/ICToken.sol";
import "./interface/ICTokenFactory.sol";
import "./Ownable.sol";
import "./Exchanges.sol";

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
    ICTokenFactory public ctokenFactory;
}

// contract StepSwap is BaseStepSwap {
contract StepSwap is Ownable, StepSwapStorage {
    using SafeMath for uint;
    using SafeMath for uint256;
    using SwapFlag for DataTypes.SwapFlagMap;

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
            ) internal view returns(int[] memory) {
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
        uint gas = 106000;  // uniswap v2

        for (uint i = 0; i < sd.paths.length; i ++) {
            address[] memory path = sd.paths[i];
            uint[] memory amts;

            // 是否是 ebankex 及 tokenIn, tokenOut 是否是 ctoken
            if (sd.ctokenIn == false) {
                amts = Exchanges.calcDistributes(ex, path, sd.amounts, sd.to);
                if (sd.ctokenOut == true) {
                    // 转换为 ctoken
                    for (uint i = 0; i < sd.amounts.length; i ++) {
                        amts[i] = amts[i].mul(1e18).div(sd.rateOut);
                    }
                    gas += 193404;
                }
            } else {
                // withdraw token 203573
                // withdraw eth: 138300
                gas += 203573;
                amts = Exchanges.calcDistributes(ex, path, sd.cAmounts, sd.to);
                if (sd.ctokenOut == true) {
                    // 转换为 ctoken
                    for (uint i = 0; i < sd.amounts.length; i ++) {
                        amts[i] = amts[i].mul(1e18).div(sd.rateOut);
                    }
                    // deposit token 193404
                    // deposit eth   160537
                    gas += 193404;
                }
            }
            sd.pathIdx[idx + i] = i;
            sd.distributes[idx + i] = amts;
            sd.exchanges[idx + i] = ex;
            sd.netDistributes[idx + i] = _deductGasFee(amts, gas, tokenPriceGWei);
        }

        sd.gases[idx] = gas;
    }

    /// @dev ebankex 兑换数量
    function _calcEbankExchangeReturn(
                DataTypes.Exchange memory ex,
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint tokenPriceGWei
            ) internal view returns (uint)  {
        uint gas = 106000;  // todo ebank swap 的 gas 费用
        if (sd.ctokenIn == false) {
            // mint 为 ctoken
            gas += 193404;
        }

        for (uint i = 0; i < sd.paths.length; i ++) {
            address[] memory path = sd.paths[i];
            uint[] memory amts;

            // ebankex tokenIn 都是 ctoken, tokenOut 是否是 ctoken

            // withdraw token 203573
            // withdraw eth: 138300
            // gas += ;
            amts = Exchanges.calcDistributes(ex, path, sd.cAmounts, sd.to);
            if (sd.ctokenOut != true) {
                // 转换为 token redeem
                for (uint i = 0; i < sd.amounts.length; i ++) {
                    amts[i] = amts[i].mul(sd.rateOut).div(1e18);
                }
                // deposit token 193404
                // deposit eth   160537
                gas += 203573;
            }
        
            sd.pathIdx[idx + i] = i;
            sd.distributes[idx + i] = amts;
            sd.exchanges[idx + i] = ex;
            sd.netDistributes[idx + i] = _deductGasFee(amts, gas, tokenPriceGWei);
        }

        sd.gases[idx] = gas;
    }

    /// @dev _makeSwapDistributes 构造参数
    function _makeSwapDistributes(
                DataTypes.QuoteParams calldata args,
                uint distributeCounts
            ) internal view returns (DataTypes.SwapDistributes memory swapDistributes) {
        swapDistributes.to = args.to;
        swapDistributes.ctokenIn = args.flag.tokenInIsCToken();
        swapDistributes.ctokenOut = args.flag.tokenOutIsCToken();
        uint parts = args.flag.getParts();
        swapDistributes.parts = parts;

        address tokenIn;
        address tokenOut;
        address ctokenIn;
        address ctokenOut;
        if (swapDistributes.ctokenIn) {
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

        if (swapDistributes.ctokenOut) {
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
            returns (DataTypes.StepExecuteParams[] memory result) {
        // DataTypes.SwapFlagMap memory flag = args.flag;
        // bool ctokenIn = flag.tokenInIsCToken();
        // bool ctokenOut = flag.tokenOutIsCToken();
        uint distributeCounts = calcExchangeRoutes(args.midTokens.length, args.flag.getComplexLevel());
        uint distributeIdx = 0;
        uint tokenPriceGWei = args.tokenPriceGWei;
        DataTypes.SwapDistributes memory swapDistributes = _makeSwapDistributes(args, distributeCounts);

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

        // 根据 dist 构建交易步骤
        return _makeSwapSteps(swapDistributes);
    }


    /// @dev 构建兑换步骤
    function _makeSwapSteps(DataTypes.SwapDistributes memory sd)
            private
            view
            returns(DataTypes.StepExecuteParams[] memory result) {
        (, uint[] memory dist) = PathFinder.findBestDistribution(sd.parts, sd.netDistributes);

        uint routes = 0;
        uint routeIdx = 0;
        for (uint i = 0; i < dist.length; i ++) {
            if (dist[i] > 0) {
                routes ++;
            }
        }
        bool allEbank = _allSwapByEBank(sd, dist);
        if (allEbank) {
            // 全部都是由 ebank

            if (!sd.ctokenIn) {
                // 如果全部由 ebank 兑换
            }

            if (!sd.ctokenOut) {
                // 如果全部由 ebank 兑换
            }
        } else {
            if (sd.ctokenIn) {

            }
            if (sd.ctokenOut) {}
        }

        result = new DataTypes.StepExecuteParams[](routes);

        for (uint i = 0; i < dist.length; i ++) {
            if (dist[i] <= 0) {
                continue;
            }
            // 计算 routes
        }
    }

    /// @dev 兑换合约地址及参数
    /// @param sd swap distributes
    /// @param idx sd 数组小标
    /// @param amt 待兑换的 token 数量
    /// @param direct 兑换结构是否直接转给最终用户
    function _makeUniswapLikeRouteStep(
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint amt,
                bool direct
            )
            private 
            view
            returns (DataTypes.StepExecuteParams memory step) {
        step.flag = sd.exchanges[idx].exFlag;

        DataTypes.UniswapRouterParam memory rp;
        rp.contract = sd.exchanges[idx].contractAddr;
        rp.amount = amt;
        if (direct) {
            rp.to = sd.to;
        } else {
            rp.to = address(this);
        }
        rp.path = sd.paths[sd.pathIdx[idx]];
        step.data = abi.encode(rp);
    }

    function _makeUniswapLikePairStep(
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint amt,
                bool direct
            )
            private 
            view
            returns (DataTypes.StepExecuteParams memory step) {

        IFactory factory = IFactory(IRouter(sd.exchanges[idx].contractAddr).factory());
        DataTypes.UniswapPairParam memory rp;

        rp.amount = amt;
        if (direct) {
            rp.to = sd.to;
        } else {
            rp.to = address(this);
        }
        // 构造 pair
        address[] paths = sd.paths[sd.pathIdx[idx]];
        rp.pairs = new address[](paths.length-1);
        for (uint i = 0; i < paths.length-1; i ++) {
            rp.pairs[i] = factory.getPair(paths[i], paths[i+1]);
        }

        step.flag = sd.exchanges[idx].exFlag;
        step.data = abi.encode(rp);
    }

    function _makeEBankRouteStep(
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint amt,
                bool direct
            )
            private 
            view
            returns (DataTypes.StepExecuteParams memory step) {
        step.flag = sd.exchanges[idx].exFlag;

        DataTypes.UniswapRouterParam memory rp;
        rp.contract = sd.exchanges[idx].contractAddr;
        rp.amount = amt;
        if (direct) {
            rp.to = sd.to;
        } else {
            rp.to = address(this);
        }
        rp.path = sd.paths[sd.pathIdx[idx]];
        step.data = abi.encode(rp);
    }

    // 是否所有的 amount 都是由 ebank 兑换
    function _allSwapByEBank(DataTypes.SwapDistributes memory sd, uint[] memory distributes) private view returns (bool) {
        return false;
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

    function setCtokenFactory(address factory) external onlyOwner {
        ctokenFactory = ICTokenFactory(factory);
    }
}
