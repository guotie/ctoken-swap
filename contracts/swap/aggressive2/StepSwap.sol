// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./library/SafeMath.sol";
import "./library/DataTypes.sol";
import "./library/SwapFlag.sol";
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


    /// @dev 计算uniswap类似的交易所的 return
    function _calcUnoswapExchangeReturn(DataTypes.Exchange memory ex, DataTypes.SwapDistributes memory sd, uint idx) internal view returns (uint) {
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
            sd.distributes[idx + i] = amts;
        }

        sd.gases[idx] = gas;
    }

    /// @dev ebankex 兑换数量
    function _calcEbankExchangeReturn(DataTypes.Exchange memory ex, DataTypes.SwapDistributes memory sd, uint idx) internal view returns (uint)  {
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
        
            sd.distributes[idx + i] = amts;
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

        swapDistributes.distributes = new uint[][](distributeCounts);
        swapDistributes.gases = new uint[](distributeCounts);
        
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
    function getExpectedReturnWithGas(DataTypes.QuoteParams calldata args) external returns (DataTypes.SwapParams memory result) {
        // DataTypes.SwapFlagMap memory flag = args.flag;
        // bool ctokenIn = flag.tokenInIsCToken();
        // bool ctokenOut = flag.tokenOutIsCToken();
        uint distributeCounts = calcExchangeRoutes(args.midTokens.length, args.flag.getComplexLevel());
        uint distributeIdx = 0;
        DataTypes.SwapDistributes memory swapDistributes = _makeSwapDistributes(args, distributeCounts);

        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange memory ex = exchanges[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }

            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                distributeIdx += _calcUnoswapExchangeReturn(ex, swapDistributes, distributeIdx);
            } else {
                // curve todo
            }
        }

        result.steps = new DataTypes.StepExecuteParams[](distributeCounts);
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
