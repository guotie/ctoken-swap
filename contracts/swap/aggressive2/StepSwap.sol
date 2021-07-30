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

    receive() external payable {

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
        return ctokenFactory.getTokenAddress(ctoken);
    }

    /// @dev 根据入参交易对, midTokens, complex 计算 flag, routes, path列表, cpath列表
    // 参数 midTokens 中不能包含 tokenIn/tokenOut 相同的 token
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

        if (ti == address(0)) {
            ti = address(weth);
        }
        if (to == address(0)) {
            to = address(weth);
        }
        // 排除 midToken 中与 tokenIn/tokenOut 相同的 token
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

        // console.log("exchange rate done");
        // params.routes = routes;
        // params.paths = paths;
        // params.cpaths = cpaths;
        // params.exchanges = exchanges;

        params.fees = new uint[](params.routes);
        params.reserves = new uint[][][](params.routes);
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
                    // set exchange fee
                    params.fees[i] = 30;
                    params.reserves[i] = Exchanges.getReserves(ex.contractAddr, path);
                }
            } else {
                // curve todo
                params.fees[i] = 4;
            }
        }
    }

    /// @dev 根据入参, 生成交易参数
    function buildSwapRouteSteps(
                    DataTypes.SwapReserveRates memory args
                )
                public
                view
                returns (DataTypes.SwapParams memory params) {
        uint steps = args.swapRoutes;

        params.amountIn = args.amountIn;
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
            params.steps[stepIdx] = _buildCompoundRedeemStep(args.amountIn.sub(args.ebankAmt), args.etokenIn);
            stepIdx ++;
        }

        if (args.ebankAmt > 0) {
            // build ebank swap
            address ebankRouter = _getEBankContract();
            address[] memory path;
            address[] memory cpath;
            uint i = 0;
            for (; i < args.distributes.length; i ++) {
                if (args.distributes[i] == 0) {
                    continue;
                }

                DataTypes.Exchange memory ex = args.exchanges[i];
                if (Exchanges.isEBankExchange(ex.exFlag)) {
                    path = args.paths[i];
                    cpath = args.cpaths[i];
                    break;
                }
            }
            console.log("build ebank step: amt=%d", args.ebankAmt);
            require(i != args.distributes.length, "no ebank");
            params.steps[stepIdx] = buildEbankSwapStep(
                                                ebankRouter,
                                                path,
                                                cpath,
                                                args.ebankAmt,
                                                args.isEToken
                                            );
            stepIdx ++;
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
                params.steps[stepIdx] = buildUniSwapStep(
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
        //     params.step[stepIdx] = _buildCompoundMintStep(0, args.etokenOut);
        // }
        params.block = block.number;
    }

    function _isETH(address token) private view returns (bool) {
        if (token == address(weth) || token == address(0)) {
            return true;
        }
        return false;
    }

    function _isCETH(address token) private view returns (bool) {
        if (token == address(ceth) || token == address(0)) {
            return true;
        }
        return false;
    }

    /// 构建 ebank swap 参数
    function buildEbankSwapStep(
                    address router,
                    address[] memory path,
                    address[] memory cpath,
                    uint256 amtIn,
                    bool isEToken                // 是否是 token in token out
                )
                public
                view
                returns (DataTypes.StepExecuteParams memory step) {
        DataTypes.UniswapRouterParam memory rp;
        if (!isEToken) {
            // underlying swap
            address tokenIn = cpath[0];
            address tokenOut = cpath[cpath.length-1];

            if (_isCETH(tokenIn)) {
                step.flag = DataTypes.STEP_EBANK_ROUTER_ETH_TOKENS;
            } else if (_isCETH(tokenOut)) {
                step.flag = DataTypes.STEP_EBANK_ROUTER_TOKENS_ETH;
            } else {
                step.flag = DataTypes.STEP_EBANK_ROUTER_TOKENS_TOKENS;
            }
            // underlying 时, path 必须是 token
            rp.path = path;
        } else {
            step.flag = DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS;
            rp.path = cpath;
        }

        rp.contractAddr = router;
        rp.amount = amtIn;

        step.data = abi.encode(rp);
    }

    /// 构建 uniswap swap 参数
    function buildUniSwapStep(
                    address router,
                    address[] memory path,
                    uint256 amtIn,
                    bool useRouter
                )
                public
                view
                returns (DataTypes.StepExecuteParams memory step) {
            require(useRouter, "must be router");
        // if (useRouter) {
            address tokenIn = path[0];
            address tokenOut = path[path.length-1];

            if (_isETH(tokenIn)) {
                step.flag = DataTypes.STEP_UNISWAP_ROUTER_ETH_TOKENS;
            } else if (_isETH(tokenOut)) {
                step.flag = DataTypes.STEP_UNISWAP_ROUTER_TOKENS_ETH;
            } else {
                step.flag = DataTypes.STEP_UNISWAP_ROUTER_TOKENS_TOKENS;
            }
            DataTypes.UniswapRouterParam memory rp;
            rp.contractAddr = router;
            rp.amount = amtIn;
            rp.path = path;

            step.data = abi.encode(rp);
        // } else {
            // IFactory factory = IFactory(IRouter(router).factory());
            // DataTypes.UniswapPairParam memory rp;
            // rp.amount = amtIn;
            
            // rp.pairs = new address[](path.length-1);
            // for (uint i = 0; i < path.length-2; i ++) {
            //     rp.pairs[i] = factory.getPair(path[i], path[i+1]);
            // }

            // step.flag = DataTypes.STEP_UNISWAP_PAIR_SWAP;
            // step.data = abi.encode(rp);
        // }
    }

    // 如果已经有 approve, 返回; 如果没有 approve, 执行 approve
    function _approve(IERC20 tokenIn, address spender) private {
        if (tokenIn.allowance(address(this), spender) < _HALF_MAX_UINT) {
            tokenIn.approve(spender, uint(-1));
        }
    }

    /*
    function _doPairStep(address tokenIn, address tokenOut, uint amt, uint[] memory pairs) private {
        if (tokenIn == address(0)) {
            //
            weth.deposit{value: amt}();
            tokenIn = address(weth);
        }
        
        TransferHelper.safeTransfer(tokenIn, pairs[i], amt);
        uint amount = amt;

        for (uint i = 0; i < pairs.length; i ++) {
            address to;
            bool reversed = (pairs[i] & DataTypes.REVERSE_SWAP_MASK) > 0;
            address pair = address(pairs[i] & ADDRESS_MASK);

            if (i == pairs.length - 1) {
                to = address(this);
            } else {
                to = address(pairs[i+1] & ADDRESS_MASK);
            }

            if (reversed) {
                IPair(pair).swap(0, amount, to, new bytes(0));
            } else {
                IPair(pair).swap(amount, 0, to, new bytes(0));
            }
        }

        if (tokenOut == address(0)) {
            //
            weth.withdraw(IERC20(weth).balanceOf(address(this)));
        }
    }
    */

    function _doRouterSetp(uint flag, address tokenIn, address router, uint amt, address[] memory path, uint deadline) private {
        // approve, swap
            // DataTypes.UniswapRouterParam memory param = abi.decode(step.data, (DataTypes.UniswapRouterParam));
            // address router = param.contractAddr;
        console.log("_doRouterSetp flag:", flag);
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
            _approve(IERC20(tokenIn), router);
            if (flag == DataTypes.STEP_UNISWAP_ROUTER_TOKENS_TOKENS) {
                console.log("uniswap token->token:", path.length, amt, IERC20(tokenIn).balanceOf(address(this)));
                IRouter(router).swapExactTokensForTokens(amt, 0, path, address(this), deadline);
            } else if (flag == DataTypes.STEP_UNISWAP_ROUTER_TOKENS_ETH) {
                IRouter(router).swapExactTokensForETH(amt, 0, path, address(this), deadline);
            } else if (flag == DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS) {
                console.log("ebank ctoken->ctoken:", path.length, amt, IERC20(tokenIn).balanceOf(address(this)));
                IDeBankRouter(router).swapExactTokensForTokens(amt, 0, path, address(this), deadline);
            } else if (flag == DataTypes.STEP_EBANK_ROUTER_TOKENS_TOKENS) {
                console.log("ebank token->token:", path.length, amt, IERC20(tokenIn).balanceOf(address(this)));
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
        address tokenIn = args.tokenIn;

        if (tokenIn == address(0)) {
            require(msg.value >= args.amountIn, "not enough value");
        } else {
            // transfer
            TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), args.amountIn);
        }

        console.log("transfer to stepswap success, steps: %d amountIn: %d", args.steps.length, args.amountIn);

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
                // if (step.flag == DataTypes.STEP_UNISWAP_PAIR_SWAP) {
                //     DataTypes.UniswapPairParam memory param = abi.decode(step.data, (DataTypes.UniswapPairParam));
                //     if (stepIdx != endIdx - 1) {
                //         amount = param.amount.mul(total).div(originAmt);
                //     }
                //     _doPairStep(ctokenIn, amount, param.pairs);
                // } else {
                    DataTypes.UniswapRouterParam memory param = abi.decode(step.data, (DataTypes.UniswapRouterParam));
                    if (stepIdx != endIdx - 1) {
                        amount = param.amount.mul(total).div(originAmt);
                    }
                    _doRouterSetp(step.flag, ctokenIn, param.contractAddr, amount, param.path, deadline);
                // }
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
            console.log("steps:", args.steps.length);
            for (uint i = 0; i < args.steps.length; i ++) {
                uint flag = args.steps[i].flag;
                console.log("swap %d %d", i, flag);
                DataTypes.StepExecuteParams memory step = args.steps[i];
                // if (flag == DataTypes.STEP_UNISWAP_PAIR_SWAP) {
                //     DataTypes.UniswapPairParam memory param = abi.decode(step.data, (DataTypes.UniswapPairParam));
                //     _doPairStep(tokenIn, param.amount, param.pairs);
                // } else {
                    DataTypes.UniswapRouterParam memory param = abi.decode(step.data, (DataTypes.UniswapRouterParam));
                    _doRouterSetp(flag, tokenIn, param.contractAddr, param.amount, param.path, deadline);
                // }
            }
        }

        /// 
        // transfer to user
        if (args.tokenOut == address(0)) {
            uint balance = address(this).balance;
            require(balance >= args.minAmt, "less than minAmt");
            console.log("eth balance:", balance);
            TransferHelper.safeTransferETH(msg.sender, balance);
        } else {
            uint balance = IERC20(tokenOut).balanceOf(address(this));
            require(balance >= args.minAmt, "less than minAmt");
            console.log("token balance:", balance);
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

    function _buildCompoundMintStep(
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

        step.data = abi.encode(rp);
    }

    /// @dev 构建 redeem 步骤的合约地址及参数
    /// @param amt redeem amount, if 0, redeem all(balanceOf(address(this)))
    function _buildCompoundRedeemStep(
                uint amt,
                address ctoken
            )
            private 
            pure
            returns (DataTypes.StepExecuteParams memory step) {
        // eth 和 token 都是调用同一个方法 redeem, 且参数相同, 因此，使用同一个 flag
        step.flag = DataTypes.STEP_COMPOUND_REDEEM_TOKEN;
        // }
        DataTypes.CompoundRedeemParam memory rp;
        rp.amount = amt;
        rp.ctoken = ctoken;

        step.data = abi.encode(rp);
    }


    function _buildEBankRouteStep(
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
