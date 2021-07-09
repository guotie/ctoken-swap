// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;


import "./UniERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./Address.sol";
import "./IWETH.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Exchange.sol";
import "./ICTokenFactory.sol";
import "./ICERC20.sol";

import "hardhat/console.sol";

contract OneSplit is Ownable {
    using SafeMath for uint;
    using SafeMath for uint256;
    // using DisableFlags for uint256;

    using UniERC20 for IERC20;
    using UniERC20 for IWETH;
    using UniswapV2ExchangeLib for IUniswapV2Exchange;
    // using ChaiHelper for IChai;

    IWETH public weth; // = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public ctokenFactory;

    struct SwapAddr {
        address router;        // router 
        uint256 flag; // pool | flag, ctokenFactory | flag
    }

    SwapAddr[] public swaps;
    // IUniswapV2Router[] public routers; // = [];
    //   IUniswapV2Factory(0x6Cf6749FE8Be5Db551a9962504F10a8467361754),
    //   IUniswapV2Factory(0x1eA875068D325AF621Dfd9B63C461E7536149b1F)
    // ];
    // IUniswapV2Factory mdexFactory = 0xb0b670fc1F7724119963018DB0BfA86aDb22d941;
    // IUniswapV2Factory bxhFactory = 0xB6B1fE87cAa52D968832a5053116af08f4601475;
    uint256 private constant _ADDRESS_MASK =   0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant _FLAG_MASK    =   0xffffffffffffffffffffffff0000000000000000000000000000000000000000;

    uint256 private constant _REVERSE_MASK =   0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant _WETH_MASK =      0x4000000000000000000000000000000000000000000000000000000000000000;

    // 稳定币兑换
    uint private constant _SWAP_CURVE    = 0x1000000000000000000000000000000000000000000000000000000000000000;
    // ctoken 兑换
    uint private constant _SWAP_COMPOUND = 0x0800000000000000000000000000000000000000000000000000000000000000;

    // 对于 compound 交易所, 直接兑换 ctoken 
    uint public constant FLAG_SWAP_DIRECT = 0x0400000000000000000000000000000000000000000000000000000000000000;
    // 使用 router 而不是 pair 来兑换
    uint public constant FLAG_SWAP_ROUTER = 0x0200000000000000000000000000000000000000000000000000000000000000;

    constructor(address _weth, address _ctokenFactory) public {
        weth = IWETH(_weth);
        ctokenFactory = _ctokenFactory;
    }

    struct Args {
        IERC20 fromToken;
        IERC20 destToken;
        IERC20[] midTokens;
        uint256 amount;
        uint256 parts;
        uint256 flags;
        uint256 slip;  // 分母 10000
        uint256 destTokenEthPriceTimesGasPrice;
    }

    struct CalcVars {
      IUniswapV2Factory factory;
      IERC20 fromToken;
      IERC20 midToken;
      IERC20 destToken;
      uint256[] amounts;
      uint256 flags;
      uint256 destTokenEthPriceTimesGasPrice;
      bool atLeastOnePositive;
    }

    struct SwapParm {
        address srcToken;
        address destToken;
        uint routes;
        uint returnAmt;
        uint[] amts;
        uint[] outAmts;
        uint[] minOutAmts;
        uint[] flags;
        bytes32[][] pools;
    }

    function resetSwaps() external onlyOwner {
        uint total = swaps.length;
        for (uint i = 0; i < total; i ++) {
            swaps.pop();
        }
    }

    function addUniswap(address _router, uint _flag) external onlyOwner {
        swaps.push(SwapAddr({
            router: _router, 
            flag: _flag
        }));
    }

    function addCurveSwap(address _pool, uint _flag) external onlyOwner {
        swaps.push(SwapAddr({
            router: _pool,
            flag: _SWAP_CURVE | _flag
        }));
    }

    // compound 交易所必须使用 router 交易 !!!
    function addCompoundSwap(address _router, address _ctokenFactory, uint _flag) external onlyOwner {
        swaps.push(SwapAddr({
            router: _router,
            flag: uint(_ctokenFactory) | _SWAP_COMPOUND | FLAG_SWAP_ROUTER | _flag
        }));
    }

    // ctoken, midToken 输入输出都是 ctoken
    // function getExpectedReturnWithGasCToken(Args memory args) 
    //     public
    //     view
    //     returns(
    //         uint256 returnAmount,
    //         uint256 estimateGasAmount,
    //         uint256[] memory distribution,
    //         bytes memory data
    //     ) {

    // }

    // token, midTokens 都是 token
    // amount 也是以 token 的数量
    function getExpectedReturnWithGas(Args memory args)
        public
        view
        returns(
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution,
            bytes memory data
        ) {
        uint routes = (1 + args.midTokens.length) * swaps.length;
        uint256[] memory amounts = _linearInterpolation(args.amount, args.parts);
        int256[][] memory matrix = new int256[][](routes);
        uint256[] memory gases = new uint256[](routes);

        console.log("before _getFactoryResults", swaps.length);
        {
          CalcVars memory localVar;
          // todo fromToken destToken 转换为 token
          localVar.fromToken = args.fromToken;
          localVar.destToken = args.destToken;
          localVar.amounts = amounts; // 是否需要根据 amount
          localVar.destTokenEthPriceTimesGasPrice = args.destTokenEthPriceTimesGasPrice;

          uint n = 0;
          // bool atLeastOnePositive = false;
          for (uint i = 0; i < swaps.length; i ++ ) {
              console.log("swa[%d].router:", i, swaps[i].router);
              localVar.factory = IUniswapV2Router(swaps[i].router).factory();
              console.log("factory", address(localVar.factory));
              localVar.flags = swaps[i].flag;
              _getFactoryResults(localVar, args.midTokens, matrix, gases, n);
              // bool pos = _getFactoryResults(localVar, midTokens, matrix, n, destTokenEthPriceTimesGasPrice);
              // atLeastOnePositive = atLeastOnePositive || pos;
              n += 1 + args.midTokens.length;
          }
        }

        console.log("before _findBestDistribution:", args.parts, matrix.length);
        
        (, distribution) = _findBestDistribution(args.parts, matrix);

        console.log("before _getReturnAndGasByDistribution");

        (returnAmount, estimateGasAmount, data) = _getReturnAndGasByDistribution(args, distribution, matrix, gases);
        //     Args({
        //         fromToken: fromToken,
        //         destToken: destToken,
        //         amount: amount,
        //         parts: parts,
        //         flags: flags,
        //         destTokenEthPriceTimesGasPrice: destTokenEthPriceTimesGasPrice,
        //         distribution: distribution,
        //         matrix: matrix,
        //         gases: gases,
        //     })
        // );
        return (returnAmount, estimateGasAmount, distribution, data);
    }

    function _getReturnAndGasByDistribution(
        Args memory args,
        uint[] memory distribution,
        int[][] memory matrix,
        uint[] memory gases
    ) internal view returns(uint256 returnAmount, uint256 estimateGasAmount, bytes memory data) {
        SwapParm memory param;
        // uint routes;
        for (uint i = 0; i < distribution.length; i ++) {
            if (distribution[i] > 0) {
                param.routes ++;
            }
        }

        param.srcToken = address(args.fromToken);
        param.destToken = address(args.destToken);
        param.amts = new uint[](param.routes);
        param.outAmts = new uint[](param.routes);
        param.minOutAmts = new uint[](param.routes);
        param.flags = new uint[](param.routes);
        param.pools = new bytes32[][](param.routes);

        uint total;
        uint idx;
        // uint amtIn = args.amount.mul(args.parts);
        // uint slip = 10000 - args.slip;
        
        for (uint i = 0; i < distribution.length; i ++) {
            if (distribution[i] > 0) {
                estimateGasAmount = estimateGasAmount.add(gases[i]);
                int256 value = matrix[i][distribution[i]] + int256(gases[i].mul(args.destTokenEthPriceTimesGasPrice).div(1e18));
                returnAmount = returnAmount.add(uint256(value));

                if (idx == param.routes - 1) {
                    // 弥补精度
                    param.amts[idx] = args.amount - total;
                } else {
                    param.amts[idx] = args.amount.mul(distribution[i]).div(args.parts);
                }

                {
                    param.outAmts[idx] = uint256(value);
                    param.minOutAmts[idx] = uint256(value).mul(10000 - args.slip).div(10000);
                    total += param.amts[idx];
                }

                PairParam memory pp;
                uint units = args.midTokens.length + 1;
                pp.router = IUniswapV2Router(swaps[i/units].router);
                pp.flag = args.flags | swaps[i/units].flag;
                pp.srcToken = args.fromToken;
                pp.destToken = args.destToken;
                pp.feeRate = 997000;
                    // uint units = args.midTokens.length+1;
                    // uint flag = args.flags | swaps[i/(args.midTokens.length+1)].flag;
                if ((i % units) != 0) {
                    // 有中间交易对的情况
                    // param.pools[idx] = 
                    pp.midToken = args.midTokens[(i%units)-1];
                }
                param.pools[idx] = _buildPoolData(pp);
                param.flags[idx] = uint(swaps[i/units].flag & _FLAG_MASK);

                idx ++;
            }
        }

        param.returnAmt = returnAmount;
        data = abi.encode(param);
    }

    struct PairParam {
      IUniswapV2Router router;
      uint flag;
      IERC20 srcToken;
      IERC20 midToken;
      IERC20 destToken;
      uint feeRate;
    }

    // 使用 router 来 swap
    // 
    function _buildRouterData(PairParam memory pairParam, bool useCtoken) private view returns (bytes32[] memory) {
        // uint feeRate = pairParam.feeRate << 160;
        //console.log("_buildPoolData:", feeRate);
        IERC20 fromTokenReal = pairParam.srcToken.isETH() ? weth : pairParam.srcToken;
        IERC20 destTokenReal = pairParam.destToken.isETH() ? weth : pairParam.destToken;
        IERC20 midToken = pairParam.midToken;
        if (useCtoken) {
            address _ctokenFactory = address(pairParam.flag & _ADDRESS_MASK);
            midToken = IERC20(_getCtokenAddress(_ctokenFactory, midToken));
            fromTokenReal = IERC20(_getCtokenAddress(_ctokenFactory, fromTokenReal));
            destTokenReal = IERC20(_getCtokenAddress(_ctokenFactory, destTokenReal));
        }

        bytes32[] memory data;
        if (address(pairParam.midToken) == address(0)) {
            data = new bytes32[](3); //  router + path[2]
            // data[0] = bytes32(pairParam.flag & _FLAG_MASK);
            data[0] = bytes32(uint(address(pairParam.router)));
            data[1] = bytes32(uint(address(fromTokenReal)));
            data[2] = bytes32(uint(address(destTokenReal)));
        } else {
            data = new bytes32[](4); //  router + path[3]
            // data[0] = bytes32(pairParam.flag & _FLAG_MASK);
            data[0] = bytes32(uint(address(pairParam.router)));
            data[1] = bytes32(uint(address(fromTokenReal)));
            data[2] = bytes32(uint(address(midToken)));
            data[3] = bytes32(uint(address(destTokenReal)));
        }

        return data;
    }

    // 根据 token 查找其 ctoken 地址
    function _getCtokenAddress(address _ctokenFactory, IERC20 token) private view returns (address) {
        address ctoken = ICTokenFactory(_ctokenFactory).getCTokenAddressPure(address(token));

        if (ctoken == address(0)) {
            // 此种情况认为 token 就是 ctoken
            return address(0); // address(token);
        }
        return ctoken;
    }

    // pair  交易方式: flag, pair|flag
    // router 交易方式: flag, router, []path
    // useCtoken: 是否是兑换ctoken, 在兑换的时候处理该标识
    // feeRate 的分母是 1000_000
    function _buildPoolData(PairParam memory pairParam) private view returns (bytes32[] memory) {
        bytes32[] memory data;
        bool useRouter = (pairParam.flag & FLAG_SWAP_ROUTER) != 0;
        bool useCtoken = (pairParam.flag & FLAG_SWAP_DIRECT) != 0;
        
        if (useRouter) {
            return _buildRouterData(pairParam, useCtoken);
        }

        uint feeRate = pairParam.feeRate << 160;
        //console.log("_buildPoolData:", feeRate);
        IERC20 fromTokenReal = pairParam.srcToken.isETH() ? weth : pairParam.srcToken;
        IERC20 destTokenReal = pairParam.destToken.isETH() ? weth : pairParam.destToken;
        // if (useCtoken) {
        //     // 不需要处理 path 都是 token token/token 的 pair 地址与 ctoken/ctoken 的 pair 地址相同
        // }
        address[] memory path;

        // data[0] = flag
        if (address(pairParam.midToken) == address(0)) {
            data = new bytes32[](1);
            path = new address[](2);
            path[0] = address(fromTokenReal);
            path[1] = address(destTokenReal);
        } else {
            data = new bytes32[](2);
            path = new address[](3);
            if (useCtoken) {
                address _ctokenFactory = address(pairParam.flag & _ADDRESS_MASK);
                path[0] = _getCtokenAddress(_ctokenFactory, fromTokenReal);
                path[1] = _getCtokenAddress(_ctokenFactory, pairParam.midToken);
                path[2] = _getCtokenAddress(_ctokenFactory, destTokenReal);
            } else {
                path[0] = address(fromTokenReal);
                path[1] = address(pairParam.midToken);
                path[2] = address(destTokenReal);
            }
        }
        // data[0] = bytes32(pairParam.flag & _FLAG_MASK);

        for (uint i = 0; i < path.length - 1; i ++) {
            address t0 = path[i];
            address t1 = path[i+1];

            address pair = address(pairParam.router.factory().getPair(IERC20(t0), IERC20(t1)));
            require(pair != address(0), "pair not exist");
            console.log("t0: %s t1: %s pair: %s", t0, t1, pair);
            uint pool = uint(pair);
            pool = feeRate | pool;
            // reverse
            address token0 = IUniswapV2Pair(pair).token0();
            console.log("token0: %s", token0);
            if (token0 != t0) {
              pool = pool | _REVERSE_MASK;
            }
            data[i] = bytes32(pool);
        }
        if (pairParam.destToken.isETH()) {
          data[data.length - 1] = bytes32(uint(data[data.length - 1]) | _WETH_MASK);
        }

        console.log("data[0]:", uint(data[0]));
        return data;
    }

    function _getFactoryResults(CalcVars memory localVar,
      IERC20[] memory midTokens,
      int256[][] memory matrix,
      uint256[] memory gases,
      uint n) internal view {
        bool atLeastOnePositive = false;
        // Prepend zero and sub gas

        (uint256[] memory amts, uint gas) = _calculateUniswapV2(localVar);
        gases[n] = gas;
        gas = gas.mul(localVar.destTokenEthPriceTimesGasPrice).div(1e18);
        matrix[n] = new int256[](amts.length + 1);
        for (uint j = 0; j < amts.length; j++) {
            matrix[n][j + 1] = int256(amts[j]) - int256(gas);
            atLeastOnePositive = atLeastOnePositive || (matrix[n][j + 1] > 0);
        }
        n ++;

        for (uint i = 0; i < midTokens.length; i ++) {
            localVar.midToken = midTokens[i];
            // (uint256[] memory amts, uint gas) = _calculateUniswapV2OverMidToken(localVar);
            (amts, gas) = _calculateUniswapV2OverMidToken(localVar);
            gases[n] = gas;
            gas = gas.mul(localVar.destTokenEthPriceTimesGasPrice).div(1e18);
            
            matrix[n] = new int256[](amts.length + 1);
            for (uint j = 0; j < amts.length; j++) {
                matrix[n][j + 1] = int256(amts[j]) - int256(gas);
                atLeastOnePositive = atLeastOnePositive || (matrix[n][j + 1] > 0);
            }
            n ++;
        }

        if (atLeastOnePositive) {
          localVar.atLeastOnePositive = true;
        }
    }

    function _findBestDistribution(
        uint256 s,                // parts
        int256[][] memory amounts // exchangesReturns
    )
        internal
        pure
        returns(
            int256 returnAmount,
            uint256[] memory distribution
        )
    {
        uint256 n = amounts.length;

        int256[][] memory answer = new int256[][](n); // int[n][s+1]
        uint256[][] memory parent = new uint256[][](n); // int[n][s+1]

        for (uint i = 0; i < n; i++) {
            answer[i] = new int256[](s + 1);
            parent[i] = new uint256[](s + 1);
        }

        for (uint j = 0; j <= s; j++) {
            answer[0][j] = amounts[0][j];
            for (uint i = 1; i < n; i++) {
                answer[i][j] = 0;
            }
            parent[0][j] = 0;
        }

        for (uint i = 1; i < n; i++) {
            for (uint j = 0; j <= s; j++) {
                answer[i][j] = answer[i - 1][j];
                parent[i][j] = j;

                for (uint k = 1; k <= j; k++) {
                    if (answer[i - 1][j - k] + amounts[i][k] > answer[i][j]) {
                        answer[i][j] = answer[i - 1][j - k] + amounts[i][k];
                        parent[i][j] = j - k;
                    }
                }
            }
        }

        distribution = new uint256[](n);

        uint256 partsLeft = s;
        for (uint curExchange = n - 1; partsLeft > 0; curExchange--) {
            distribution[curExchange] = partsLeft - parent[curExchange][partsLeft];
            partsLeft = parent[curExchange][partsLeft];
        }

        returnAmount = (answer[n - 1][s] == 0) ? 0 : answer[n - 1][s];
    }

    function _calculateUniswapFormula(uint256 fromBalance, uint256 toBalance, uint256 amount) internal pure returns(uint256) {
        if (amount == 0) {
            return 0;
        }
        return amount.mul(toBalance).mul(997).div(
            fromBalance.mul(1000).add(amount.mul(997))
        );
    }

    function _calculateUniswapFormulaCompound(uint256 fromBalance,
            uint256 toBalance,
            uint256 amount,
            uint rateIn,
            uint rateOut)
            internal pure returns(uint256) {
        if (amount == 0) {
            return 0;
        }
        amount = amount.mul(1e18).div(rateIn);
        uint amtOut = amount.mul(toBalance).mul(997).div(
                fromBalance.mul(1000).add(amount.mul(997))
            );
        return amtOut.mul(rateOut).div(1e18);
    }

    // 计算 ctoken 的 exchange rate
    function _calcExchangeRate(ICERC20 ctoken) private view returns (uint) {
        uint rate = ctoken.exchangeRateStored();
        uint supplyRate = ctoken.supplyRatePerBlock();
        uint lastBlock = ctoken.accrualBlockNumber();
        uint blocks = block.number.sub(lastBlock);
        uint inc = rate.mul(supplyRate).mul(blocks);
        return rate.add(inc);
    }

    // 使用 token 来计算收益
    function _calculateUniswapV2(CalcVars memory lvar) internal view returns(uint256[] memory rets, uint256 gas) {
        // IUniswapV2Factory factory = lvar.factory;
        bool compound = (lvar.flags & _SWAP_COMPOUND) != 0;
        uint exchangeRateFrom;
        uint exchangeRateDest;
        // uint256[] memory amounts = lvar.amounts;
        // uint256 /*flags*/
        rets = new uint256[](lvar.amounts.length);

        IERC20 fromTokenReal = lvar.fromToken.isETH() ? weth : lvar.fromToken;
        IERC20 destTokenReal = lvar.destToken.isETH() ? weth : lvar.destToken;
        if (compound) {
            address _ctokenFactory = address(lvar.flags & _ADDRESS_MASK);
            fromTokenReal = IERC20(_getCtokenAddress(_ctokenFactory, fromTokenReal));
            destTokenReal = IERC20(_getCtokenAddress(_ctokenFactory, destTokenReal));
            // 不会返回 0
            if ((address(fromTokenReal) == address(0)) || (address(destTokenReal) == address(0))) {
                // gas = 50_000;
                return (rets, 50_000);
            }

            exchangeRateFrom = _calcExchangeRate(ICERC20(address(fromTokenReal)));
            exchangeRateDest = _calcExchangeRate(ICERC20(address(destTokenReal)));

            console.log("compound exchange rat:", exchangeRateFrom, exchangeRateDest);
        }

        IUniswapV2Exchange exchange = lvar.factory.getPair(fromTokenReal, destTokenReal);
        if (exchange != IUniswapV2Exchange(0)) {
            uint256 fromTokenBalance = fromTokenReal.uniBalanceOf(address(exchange));
            uint256 destTokenBalance = destTokenReal.uniBalanceOf(address(exchange));
            for (uint i = 0; i < lvar.amounts.length; i++) {
                if (compound) {
                    rets[i] = _calculateUniswapFormulaCompound(
                                    fromTokenBalance,
                                    destTokenBalance,
                                    lvar.amounts[i],
                                    exchangeRateFrom,
                                    exchangeRateDest
                                );
                } else {
                    rets[i] = _calculateUniswapFormula(fromTokenBalance, destTokenBalance, lvar.amounts[i]);
                }
            }
            return (rets, 50_000);
        }
    }

    function _linearInterpolation(
        uint256 value,
        uint256 parts
    ) internal pure returns(uint256[] memory rets) {
        rets = new uint256[](parts);
        for (uint i = 0; i < parts; i++) {
            rets[i] = value.mul(i + 1).div(parts);
        }
    }

    function _calculateUniswapV2OverMidToken(
        CalcVars memory lvar
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        // rets = _linearInterpolation(amount, parts);
        // IUniswapV2Factory factory = var.factory;
        // IERC20 fromToken = var.fromToken;
        // IERC20 midToken = var.midToken;
        // IERC20 destToken = var.destToken;
        // uint256[] memory amounts = var.amounts;
        // // uint256 parts,
        // uint256 flags = var.flags;
        CalcVars memory tmpVar;
        tmpVar.factory = lvar.factory;
        tmpVar.fromToken = lvar.fromToken;
        // tmpVar.midToken = lvar.factory;
        tmpVar.destToken = lvar.midToken;
        tmpVar.amounts = lvar.amounts;
        tmpVar.flags = lvar.flags;

        uint256 gas1;
        uint256 gas2;
        (rets, gas1) = _calculateUniswapV2(tmpVar);
        tmpVar.amounts = rets;
        tmpVar.fromToken = lvar.midToken;
        tmpVar.destToken = lvar.destToken;
        (rets, gas2) = _calculateUniswapV2(tmpVar);
        return (rets, gas1 + gas2);
    }

}
