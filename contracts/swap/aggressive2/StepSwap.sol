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
    mapping(uint => DataTypes.Exchange) public swaps;  // 
    uint public exchangeCount;  // exchange 数量
    IWETH public weth;
    ILHT public ceth;  // compound eth
    ICTokenFactory public ctokenFactory;

    uint internal constant _HALF_MAX_UINT = uint(-1) >> 1;                            // 0x8fffffffffff...
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

    function isTokenToken(address token) public view returns (bool) {
        address ctoken = ctokenFactory.getCTokenAddressPure(token);
        // 有对应的 ctoken 时, 一定是 token
        if (ctoken != address(0)) {
            return true;
        }
        // 没有对应的 ctoken 时, 有可能 token 是 ctoken, 也有可能是 token 没有对应的 ctoken 地址
        if (ctokenFactory.getTokenAddress(token) != address(0)) {
            // 是 ctoken, 存在对应的 token 地址
            return false;
        }
        return true;
    }

    function _getCTokenAddressPure(address token) internal view returns (address ctoken) {
        if (token == address(0)) {
            return address(ceth);
        }
        return ctokenFactory.getCTokenAddressPure(token);
    }

    function _getTokenAddressPure(address ctoken) internal view returns (address token) {
        if (token == address(ceth)) {
            return address(0);
        }
        return ctokenFactory.getTokenAddress(token);
    }

    /// @dev 根据入参交易对, midTokens, complex 计算 flag, routes, path列表, cpath列表
    function getRoutesPaths(
                    DataTypes.QuoteParams memory args
                )
                public
                view
                returns (
                    // uint flag,
                    uint routes,
                    address[][] memory paths,
                    address[][] memory cpaths,
                    DataTypes.Exchange[] memory exchanges
                    ) {
        (routes, exchanges) = calcExchangeRoutes(args.midTokens.length, args.complex);

        address ti = args.tokenIn;
        address to = args.tokenOut;
        address cti = args.tokenIn;
        address cto = args.tokenOut;
        if (args.tokenIn == address(0)) {
            // flag = flag | SwapFlag.FLAG_TOKEN_IN_ETH;
            cti = address(ceth);
        } else if (isTokenToken(args.tokenIn)) {
            // flag = flag | SwapFlag.FLAG_TOKEN_TOKEN;
            cti = _getCTokenAddressPure(ti);
        } else {
            // flag = flag | SwapFlag.FLAG_TOKEN_CTOKEN;
            ti = ctokenFactory.getTokenAddress(cti);
        }

        if (args.tokenOut == address(0)) {
            // flag = flag | SwapFlag.FLAG_TOKEN_OUT_ETH;
            cto = address(ceth);
        } else if (isTokenToken(args.tokenOut)) {
            // both token
            require(isTokenToken(args.tokenIn) || args.tokenIn == address(0), "both token in/out should be token");
            cto = _getCTokenAddressPure(to);
        } else {
            // both ctoken
            require(isTokenToken(args.tokenIn) == false || args.tokenIn == address(0), "both token in/out should be etoken");
            to = ctokenFactory.getTokenAddress(cto);
        }

        // flag = flag | ((args.mainRoutes & 0xff) << SwapFlag._SHIFT_MAIN_ROUTES);
        // flag = flag | ((args.complex & 0x3) << SwapFlag._SHIFT_COMPLEX_LEVEL);
        // flag = flag | (args.parts & 0xff);
        // if (args.allowPartial) {
        //     flag = flag | SwapFlag._MASK_PARTIAL_FILL;
        // }
        // if (args.allowBurnchi) {
        //     flag = flag | SwapFlag._MASK_PARTIAL_FILL;
        // }

        address[] memory midCTokens = new address[](args.midTokens.length);
        for (uint i = 0; i < args.midTokens.length; i ++) {
            midCTokens[i] = _getCTokenAddressPure(args.midTokens[i]);
        }
        address[][] memory tmp = Exchanges.allPaths(ti, to, args.midTokens, args.complex);
        paths = allSwapPaths(tmp);
        tmp = Exchanges.allPaths(cti, cto, midCTokens, args.complex);
        cpaths = allSwapPaths(tmp);
    }

    function allSwapPaths(
                    address[][] memory ps
                )
                public
                view
                returns (address[][] memory paths) {
        uint total = 0;
        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange storage ex = swaps[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }
            // DataTypes.Exchange memory ex = exchanges[i];
            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                total += ps.length;
            } else {
                // curve, etc
                total ++;
            }
        }
        paths = new address[][](total);
        uint pIdx = 0;
        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange storage ex = swaps[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }
            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                for (uint j = 0; j < ps.length; j ++) {
                    paths[pIdx] = ps[j];
                    pIdx ++;
                }
            } else {
                // curve, etc
                paths[pIdx] = new address[](1);
                pIdx ++;
            }
        }
    }

    /// @dev 获取交易所的 reserve 数据及 exchangeRate
    function getSwapReserveRates(
                DataTypes.QuoteParams memory args
            )
            public
            view
            returns (DataTypes.SwapReserveRates memory params) {
        require(exchangeCount > 0, "no exchanges");
        // uint flag;
        (
            // flag,
            params.routes,
            params.paths,
            params.cpaths,
            params.exchanges
        ) = getRoutesPaths(args);

        console.log("routes: %d paths: %d exchanges: %d", params.routes, params.paths.length, params.exchanges.length);
        if (isTokenToken(args.tokenIn) || isTokenToken(args.tokenOut)) {
            address ctokenIn = _getCTokenAddressPure(args.tokenIn);
            address ctokenOut = _getCTokenAddressPure(args.tokenOut);
            params.isEToken  = false;
            params.tokenIn   = args.tokenIn;
            params.tokenOut  = args.tokenOut;
            params.etokenIn  = ctokenIn;
            params.etokenOut = ctokenOut;
            params.rateIn    = Exchanges.calcCTokenExchangeRate(ICToken(ctokenIn));
            params.rateOut   = Exchanges.calcCTokenExchangeRate(ICToken(ctokenOut));
        } else {
            params.isEToken  = true;
            params.etokenIn  = args.tokenIn;
            params.etokenOut = args.tokenOut;
            params.tokenIn   = ctokenFactory.getTokenAddress(args.tokenIn);
            params.tokenOut  = ctokenFactory.getTokenAddress(args.tokenOut);
            params.rateIn    = Exchanges.calcCTokenExchangeRate(ICToken(args.tokenIn));
            params.rateOut   = Exchanges.calcCTokenExchangeRate(ICToken(args.tokenOut));
        }
        // params.routes = routes;
        // params.paths = paths;
        // params.cpaths = cpaths;
        // params.exchanges = exchanges;

        params.reserves = new uint[][](params.routes);
        for (uint i = 0; i < params.paths.length; i ++) {
            DataTypes.Exchange memory ex = params.exchanges[i];
            address[] memory path = params.paths[i];

            // if (ex.contractAddr == address(0)) {
            //     params.reserves[i] = new uint[](path.length);
            //     continue;
            // }

            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                if (Exchanges.isEBankExchange(ex.exFlag)) { // 必须先于 UniswapLike 的判断
                    // todo set exchange fee
                    params.fees[i] = 30;
                    params.reserves[i] = Exchanges.getReserves(ex.contractAddr, params.cpaths[i]);
                } else {
                    // todo set exchange fee
                    params.fees[i] = 30;
                    params.reserves[i] = Exchanges.getReserves(ex.contractAddr, path);
                }
            } else {
                // curve todo
            }
        }
    }

    /*
    /// @dev 根据入参计算在各个交易所分配的资金比例及交易路径(步骤)
    function getExpectedReturnWithGas(
                DataTypes.QuoteParams memory args
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
        uint distributeCounts = args.routes; // calcExchangeRoutes(args.midTokens.length, args.flag.getComplexLevel());
        uint distributeIdx = 0;
        uint tokenPriceGWei = 0; // args.tokenPriceGWei;
        DataTypes.SwapDistributes memory swapDistributes = _makeSwapDistributes(args, distributeCounts);
        console.log("routes:", distributeCounts);

        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange memory ex = swaps[i];

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
        console.log("calc done");

        // 根据 dist 构建交易步骤
        DataTypes.SwapParams memory params;
        params.flag = args.flag;
        params.block = block.number;
        params.amountIn = args.amountIn;
        params.tokenIn = args.tokenIn;
        params.tokenOut = args.tokenOut;
        /// todo 根据 slip 计算出 minAmt
        _makeSwapSteps(args.amountIn, swapDistributes, params);
        return params;
    }
    */

    /// @dev 根据入参, 生成交易参数
    function makeSwapRouteSteps(
                    DataTypes.SwapReserveRates memory args
                )
                public
                view
                returns (DataTypes.SwapParams memory params) {
        uint steps = args.swapRoutes;

        if (args.isEToken) {
            params.tokenIn = args.etokenIn;
            params.tokenOut = args.etokenOut;
            // etoken 且不完全由ebank 兑换时, step 增加两步: redeem 和 mint, mint 不计入 step 中
            if (args.allEbank == false) {
                steps += 1;
            }
        } else {
            params.tokenIn = args.tokenIn;
            params.tokenOut = args.tokenOut;
        }
        params.isEToken = args.isEToken;

        uint stepIdx = 0;
        params.steps = new DataTypes.StepExecuteParams[](steps);
        if (args.isEToken && args.allEbank == false) {
            // redeem to token
            params.steps[stepIdx] = _makeCompoundRedeemStep(args.amountIn.sub(args.ebankAmt), args.etokenIn);
            stepIdx ++;
        }

        if (args.ebankAmt > 0) {
            // make ebank swap
            address ebankRouter = _getEBankContract();
            address[] memory cpath;
            uint i = 0;
            for (; i < args.distributes.length; i ++) {
                if (args.distributes[i] == 0) {
                    continue;
                }

                DataTypes.Exchange memory ex = args.exchanges[i];
                if (Exchanges.isEBankExchange(ex.exFlag)) {
                    cpath = args.cpaths[i];
                    break;
                }
            }
            require(i != args.distributes.length, "no ebank");
            params.steps[stepIdx] = makeEbankSwapStep(
                                                ebankRouter,
                                                cpath,
                                                args.ebankAmt,
                                                args.isEToken
                                            );
        }

        for (uint i = 0; i < args.distributes.length; i ++) {
            if (args.distributes[i] == 0) {
                continue;
            }

            DataTypes.Exchange memory ex = args.exchanges[i];
            if (Exchanges.isEBankExchange(ex.exFlag)) {
                continue;
            }

            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                params.steps[stepIdx] = makeUniSwapStep(
                                            ex.contractAddr,
                                            args.paths[i],
                                            args.distributes[i],
                                            true
                                        );
            } else {
                // todo curve, etc
                DataTypes.StepExecuteParams memory step;
                step.flag = 0;
                params.steps[stepIdx] = step;
            }

            stepIdx ++;
        }

        // if (args.isEToken && args.allEbank == false) {
        //     //
        //     params.step[stepIdx] = _makeCompoundMintStep(0, args.etokenOut);
        // }
        params.block = block.number;
    }

    /// 构建 ebank swap 参数
    function makeEbankSwapStep(
                    address router,
                    address[] memory cpath,
                    uint256 amtIn,
                    bool isToken                // 是否是 token in token out
                )
                public
                view
                returns (DataTypes.StepExecuteParams memory step) {
        if (isToken) {
            // underlying swap
            address tokenIn = cpath[0];
            address tokenOut = cpath[cpath.length-1];

            if (tokenIn == address(0)) {
                step.flag = DataTypes.STEP_EBANK_ROUTER_ETH_TOKENS;
            } else if (tokenOut == address(0)) {
                step.flag = DataTypes.STEP_EBANK_ROUTER_TOKENS_ETH;
            } else {
                step.flag = DataTypes.STEP_EBANK_ROUTER_TOKENS_TOKENS;
            }
        } else {
            step.flag = DataTypes.STEP_UNISWAP_ROUTER_TOKENS_TOKENS;
        }

        DataTypes.UniswapRouterParam memory rp;
        rp.contractAddr = router;
        rp.amount = amtIn;
        rp.path = cpath;

        step.data = abi.encode(rp);
    }

    /// 构建 uniswap swap 参数
    function makeUniSwapStep(
                    address router,
                    address[] memory path,
                    uint256 amtIn,
                    bool useRouter
                )
                public
                view
                returns (DataTypes.StepExecuteParams memory step) {
        if (useRouter) {
            address tokenIn = path[0];
            address tokenOut = path[path.length-1];

            if (tokenIn == address(0)) {
                step.flag = DataTypes.STEP_UNISWAP_ROUTER_ETH_TOKENS;
            } else if (tokenOut == address(0)) {
                step.flag = DataTypes.STEP_UNISWAP_ROUTER_TOKENS_ETH;
            } else {
                step.flag = DataTypes.STEP_UNISWAP_ROUTER_TOKENS_TOKENS;
            }
            DataTypes.UniswapRouterParam memory rp;
            rp.contractAddr = router;
            rp.amount = amtIn;
            rp.path = path;

            step.data = abi.encode(rp);
        } else {
            IFactory factory = IFactory(IRouter(router).factory());
            DataTypes.UniswapPairParam memory rp;
            rp.amount = amtIn;
            
            rp.pairs = new address[](path.length-1);
            for (uint i = 0; i < path.length-2; i ++) {
                rp.pairs[i] = factory.getPair(path[i], path[i+1]);
            }

            step.flag = DataTypes.STEP_UNISWAP_PAIR_SWAP;
            step.data = abi.encode(rp);
        }
    }

    /*
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
        for (uint i = 0; i < paths.length-1; i ++) {
            rp.pairs[i] = factory.getPair(paths[i], paths[i+1]);
        }

        step.flag = DataTypes.STEP_UNISWAP_PAIR_SWAP;
        step.data = abi.encode(rp);
    }
    */

    // 如果已经有 approve, 返回; 如果没有 approve, 执行 approve
    function _approve(IERC20 tokenIn, address spender) private {
        if (tokenIn.allowance(msg.sender, spender) < _HALF_MAX_UINT) {
            tokenIn.approve(spender, uint(-1));
        }
    }

    function _doPairStep(address tokenIn, uint amt, address[] memory pairs) private {
        if (tokenIn == address(0)) {

        } else {

        }
    }

    function _doRouterSetp(uint flag, address tokenIn, address router, uint amt, address[] memory path, uint deadline) private {
        // approve, swap
            // DataTypes.UniswapRouterParam memory param = abi.decode(step.data, (DataTypes.UniswapRouterParam));
            // address router = param.contractAddr;
        if (flag == DataTypes.STEP_UNISWAP_ROUTER_ETH_TOKENS || flag == DataTypes.STEP_EBANK_ROUTER_ETH_TOKENS) {
            // eth
            if (amt == 0) {
                amt = address(this).balance;
            }
            if (flag == DataTypes.STEP_UNISWAP_ROUTER_ETH_TOKENS) {
                IRouter(router).swapExactETHForTokens{value: amt}(0, path, address(this), deadline);
            } else {
                IDeBankRouter(router).swapExactETHForTokensUnderlying{value: amt}(0, path, address(this), deadline);
            }
        } else {
            if (amt == 0) {
                amt = IERC20(tokenIn).balanceOf(address(this));
            }
            // approve
            _approve(IERC20(tokenIn), address(this));
            if (flag == DataTypes.STEP_UNISWAP_ROUTER_TOKENS_TOKENS) {
                IRouter(router).swapExactTokensForTokens(amt, 0, path, address(this), deadline);
            } else if (flag == DataTypes.STEP_UNISWAP_ROUTER_TOKENS_ETH) {
                IRouter(router).swapExactTokensForETH(amt, 0, path, address(this), deadline);
            } else if (flag == DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS) {
                IDeBankRouter(router).swapExactTokensForTokens(amt, 0, path, address(this), deadline);
            } else if (flag == DataTypes.STEP_EBANK_ROUTER_TOKENS_TOKENS) {
                IDeBankRouter(router).swapExactTokensForTokensUnderlying(amt, 0, path, address(this), deadline);
            } else {
                // STEP_EBANK_ROUTER_TOKENS_ETH
                require(flag == DataTypes.STEP_EBANK_ROUTER_TOKENS_ETH, "invalid flag");
                IDeBankRouter(router).swapExactTokensForETHUnderlying(amt, 0, path, address(this), deadline);
            }
        }

    }

    /// @dev 根据参数执行兑换
    // 用户需要授权
    function unoswap(DataTypes.SwapParams memory args) public payable {
        if (args.tokenIn == address(0)) {
            // transfer
            TransferHelper.safeTransferFrom(args.tokenIn, msg.sender, address(this), args.amountIn);
        } else {
            require(msg.value >= args.amountIn, "not enough value");
        }
        address tokenIn = args.tokenIn;
        address tokenOut = args.tokenOut;

        // solhint-disable-next-line
        uint deadline = block.timestamp + 600;
        if (args.isEToken) {
            // 是否需要 redeem
            uint stepIdx = 0;
            uint endIdx = args.steps.length;
            bool redeemMint = false;
            uint total = 0;   // total redeemed
            uint originAmt = 0;
            if (args.steps[0].flag == DataTypes.STEP_COMPOUND_REDEEM_TOKEN) {
                redeemMint = true;
                stepIdx ++;
                endIdx -= 1;
                DataTypes.CompoundRedeemParam memory rp = abi.decode(args.steps[0].data, (DataTypes.CompoundRedeemParam));
                // _approve(tokenIn, spender);
                ICToken(rp.ctoken).redeem(rp.amount);
                originAmt = rp.amount;
                if (rp.ctoken == address(ceth)) {
                    total = address(this).balance;
                } else {
                    address token = ctokenFactory.getTokenAddress(rp.ctoken);
                    total = IERC20(token).balanceOf(address(this));
                }
            }

            // 如果有 ebank swap, 必定在第一个
            if (args.amountIn > originAmt) {
                _approve(IERC20(tokenIn), address(this));
                DataTypes.UniswapRouterParam memory param = abi.decode(args.steps[stepIdx].data, (DataTypes.UniswapRouterParam));
                IDeBankRouter(param.contractAddr).swapExactTokensForTokens(param.amount, 0, param.path, address(this), deadline);
                stepIdx ++;
            }

            address ctokenIn = _getTokenAddressPure(tokenIn);
            for (; stepIdx < endIdx; stepIdx ++) {
                // 根据不同情况, 计算不同的交易数量
                uint amount = 0;
                DataTypes.StepExecuteParams memory step = args.steps[stepIdx];
                if (step.flag == DataTypes.STEP_UNISWAP_PAIR_SWAP) {
                    DataTypes.UniswapPairParam memory param = abi.decode(step.data, (DataTypes.UniswapPairParam));
                    if (stepIdx != endIdx - 1) {
                        amount = param.amount.mul(total).div(originAmt);
                    }
                    _doPairStep(ctokenIn, amount, param.pairs);
                } else {
                    DataTypes.UniswapRouterParam memory param = abi.decode(step.data, (DataTypes.UniswapRouterParam));
                    if (stepIdx != endIdx - 1) {
                        amount = param.amount.mul(total).div(originAmt);
                    }
                    _doRouterSetp(step.flag, ctokenIn, param.contractAddr, amount, param.path, deadline);
                }
            }

            if (redeemMint) {
                // mint to ctoken
                if (tokenOut == address(ceth)) {
                    uint amt = address(this).balance;
                    ceth.mint{value: amt}();
                } else {
                    address token = ctokenFactory.getTokenAddress(tokenOut);
                    _approve(IERC20(token), tokenOut);
                    ICToken(tokenOut).mint(IERC20(token).balanceOf(address(this)));
                }
            }
        } else {
            // 没有 redeem/mint操作, 不需要考虑 amount 转换的问题
            for (uint i = 0; i < args.steps.length; i ++) {
                uint flag = args.steps[i].flag;
                DataTypes.StepExecuteParams memory step = args.steps[i];
                if (flag == DataTypes.STEP_UNISWAP_PAIR_SWAP) {
                    DataTypes.UniswapPairParam memory param = abi.decode(step.data, (DataTypes.UniswapPairParam));
                    _doPairStep(tokenIn, param.amount, param.pairs);
                } else {
                    DataTypes.UniswapRouterParam memory param = abi.decode(step.data, (DataTypes.UniswapRouterParam));
                    _doRouterSetp(flag, tokenIn, param.contractAddr, param.amount, param.path, deadline);
                }
            }
        }

        /// 
        // transfer to user
        if (args.tokenOut == address(0)) {
            uint balance = address(this).balance;
            require(balance >= args.minAmt, "less than minAmt");
            TransferHelper.safeTransferETH(msg.sender, balance);
        } else {
            uint balance = IERC20(tokenOut).balanceOf(address(this));
            require(balance >= args.minAmt, "less than minAmt");
            console.log("balance:", balance);
            TransferHelper.safeTransfer(tokenOut, msg.sender, balance);
        }
    }

    /// @dev 在给定中间交易对数量和复杂度的情况下, 有多少种兑换路径
    function calcExchangeRoutes(
                    uint midTokens,
                    uint complexLevel
                )
                public
                view
                returns (uint total, DataTypes.Exchange[] memory exchanges) {
        uint i;

        // 计算一共有多少个 exchange routes
        for (i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange storage ex = swaps[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }

            total += Exchanges.getExchangeRoutes(ex.exFlag, midTokens, complexLevel);
        }
        exchanges = new DataTypes.Exchange[](total);
        uint exIdx = 0;
        for (i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange storage ex = swaps[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }

            uint count = Exchanges.getExchangeRoutes(ex.exFlag, midTokens, complexLevel);
            for (uint j = 0; j < count; j ++) {
                exchanges[exIdx].exFlag = ex.exFlag;
                exchanges[exIdx].contractAddr = ex.contractAddr;
                exIdx ++;
            }
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

        for (uint i = 1; i < amounts.length; i ++) {
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

    /*
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
                // console.log("ex: %s  i: %d", ex.contractAddr, i);
                address[] memory path = sd.paths[i];
                // console.log("path:", path.length, path[0], path[1]);
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
            uint nIdx = idx +i;
            sd.pathIdx[nIdx] = i;
            sd.exchanges[nIdx] = ex;
            sd.distributes[nIdx] = amts;
            sd.netDistributes[nIdx] = _deductGasFee(amts, gas, tokenPriceGWei);
            sd.gases[nIdx] = gas;
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
                DataTypes.QuoteParams memory args,
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
            ctokenIn = _getCTokenAddressPure(tokenIn);
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
            ctokenOut = _getCTokenAddressPure(tokenOut);
        }

        swapDistributes.gases          = new uint[]  (distributeCounts); // prettier-ignore
        swapDistributes.pathIdx        = new uint[]  (distributeCounts); // prettier-ignore
        swapDistributes.distributes    = new uint[][](distributeCounts); // prettier-ignore
        swapDistributes.netDistributes = new int[][](distributeCounts);  // prettier-ignore
        swapDistributes.exchanges      = new DataTypes.Exchange[](distributeCounts);
        
        // uint mids = args.midTokens.length;
        // address[] memory midTokens = new address[](mids);
        // address[] memory midCTokens = new address[](mids);
        // for (uint i = 0; i < mids; i ++) {
        //     midTokens[i] = args.midTokens[i];
        //     midCTokens[i] = _getCTokenAddressPure(args.midTokens[i]);
        // }
        // swapDistributes.midTokens = midTokens;
        // swapDistributes.midCTokens = midCTokens;

        swapDistributes.paths = args.paths; // Exchanges.allPaths(tokenIn, tokenOut, midTokens, args.flag.getComplexLevel());
        swapDistributes.cpaths = args.cpaths; // Exchanges.allPaths(ctokenIn, ctokenOut, midCTokens, args.flag.getComplexLevel());
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

        uint ebankParts = _allSwapByEBank(sd, dists);
        console.log("ebankParts:", ebankParts);
        if (ebankParts == sd.parts) {
            // 全部都是由 ebank
            // if (sd.ctokenIn != sd.ctokenOut) {
            //     // 如果全部由 ebank 兑换
            //     routes ++;
            // }
            return _buildEBankSteps(steps, amountIn, dists, sd, params);
        }
        if (ebankParts == 0) {
            // todo 
        }

        if (sd.isCtoken) {
            // redeem ctoken, mint token
            steps += 2;
        }
        DataTypes.StepExecuteParams[] memory stepArgs = new DataTypes.StepExecuteParams[](steps);

        if (sd.isCtoken) {
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
    */

    /// amt * part / totalParts
    function _partAmount(uint amt, uint part, uint totalParts) private pure returns (uint) {
        return amt.mul(part).div(totalParts);
    }

    function _getEBankContract() private view returns (address ebank) {
        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange memory ex = swaps[i];
            if (ex.exFlag == Exchanges.EXCHANGE_EBANK_EX && ex.contractAddr != address(0)) {
                ebank = ex.contractAddr;
                break;
            }
        }
        require(ebank != address(0), "not found ebank");
        return ebank;
    }

    /*
    function _buildUniswapLikeSteps(
                uint amt,
                uint idx,
                bool useRouter,
                DataTypes.SwapDistributes memory sd
            )
            private
            view
            returns (DataTypes.StepExecuteParams memory params) {
        console.log("_buildUniswapLikeSteps: amt=%d idx=%d useRouter:", amt, idx, useRouter);
        if (useRouter) {
            return _makeUniswapLikeRouteStep(amt, idx, sd);
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
    }
    */

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
        //     ctoken = _getCTokenAddressPure(tokenOut);
        // }
        // if (ctoken == ceth) {
        //     step.flag = DataTypes.STEP_COMPOUND_REDEEM_ETH;
        // } else {
        // 
        // eth 和 token 都是调用同一个方法 redeem, 且参数相同, 因此，使用同一个 flag
        step.flag = DataTypes.STEP_COMPOUND_REDEEM_TOKEN;
        // }
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

    /*
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
        // uniswap router
        step.flag = DataTypes.STEP_UNISWAP_ROUTER_TOKENS_TOKENS;
        // step.flag = sd.exchanges[idx].exFlag;

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

        step.flag = DataTypes.STEP_UNISWAP_PAIR_SWAP;
        step.data = abi.encode(rp);
    }
    */

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

    /*
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
                returns (uint part) {
        for (uint i = 0; i < distributes.length; i ++) {
            if (distributes[i] > 0) {
                // 该 swap 是 ebank
                if (Exchanges.isEBankExchange(sd.exchanges[i].exFlag) == true) {
                    return distributes[i];
                }
            }
        }

        return 0;
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
    */

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    

    function addSwap(uint flag, address addr) external onlyOwner {
        DataTypes.Exchange storage ex = swaps[exchangeCount];
        ex.exFlag = flag;
        ex.contractAddr = addr;

        exchangeCount ++;
    }

    function removeSwap(uint i) external onlyOwner {
        DataTypes.Exchange storage ex = swaps[i];

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

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}
