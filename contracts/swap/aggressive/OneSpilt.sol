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

import "hardhat/console.sol";

contract OneSplit is Ownable {
    using SafeMath for uint256;
    // using DisableFlags for uint256;

    using UniERC20 for IERC20;
    using UniERC20 for IWETH;
    using UniswapV2ExchangeLib for IUniswapV2Exchange;
    // using ChaiHelper for IChai;

    IWETH public weth; // = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IUniswapV2Factory[] public factories = [
      IUniswapV2Factory(0x6Cf6749FE8Be5Db551a9962504F10a8467361754),
      IUniswapV2Factory(0x1eA875068D325AF621Dfd9B63C461E7536149b1F)
    ];
    // IUniswapV2Factory mdexFactory = 0xb0b670fc1F7724119963018DB0BfA86aDb22d941;
    // IUniswapV2Factory bxhFactory = 0xB6B1fE87cAa52D968832a5053116af08f4601475;
    uint256 private constant _REVERSE_MASK =   0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant _WETH_MASK =      0x4000000000000000000000000000000000000000000000000000000000000000;

    constructor(address _weth) public {
        weth = IWETH(_weth);
    }

    struct Args {
        IERC20 fromToken;
        IERC20 destToken;
        IERC20[] midTokens;
        uint256 amount;
        uint256 parts;
        uint256 flags;
        // uint256 slip;  // 分母 10000
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
        uint routers;
        uint returnAmt;
        uint[] amts;
        uint[] outAmts;
        uint[] minOutAmts;
        uint[] flags;
        bytes32[][] pools;
    }

    // function addFactory(address _factory) external onlyOwner {
    //     factories[factories.length] = _factory;
    // }

    function resetFactories(address[] memory _factories) external onlyOwner {
        uint total = factories.length;
        for (uint i = 0; i < total; i ++) {
            factories.pop();
        }

        factories = new IUniswapV2Factory[](_factories.length);
        for (uint i = 0; i < _factories.length; i ++) {
            factories[i] = IUniswapV2Factory(_factories[i]);
        }
    }

    function getExpectedReturnWithGas(Args memory args)
        public
        view
        returns(
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution,
            bytes memory data
        ) {
        uint routers = (1 + args.midTokens.length) * factories.length;
        uint256[] memory amounts = _linearInterpolation(args.amount, args.parts);
        int256[][] memory matrix = new int256[][](routers);
        uint256[] memory gases = new uint256[](routers);

        {
          CalcVars memory localVar;
          localVar.fromToken = args.fromToken;
          localVar.destToken = args.destToken;
          localVar.amounts = amounts;
          localVar.flags = args.flags;
          localVar.destTokenEthPriceTimesGasPrice = args.destTokenEthPriceTimesGasPrice;

          uint n = 0;
          // bool atLeastOnePositive = false;
          for (uint i = 0; i < factories.length; i ++ ) {
              localVar.factory = factories[i];
              _getFactoryResults(localVar, args.midTokens, matrix, gases, n);
              // bool pos = _getFactoryResults(localVar, midTokens, matrix, n, destTokenEthPriceTimesGasPrice);
              // atLeastOnePositive = atLeastOnePositive || pos;
              n = 1 + args.midTokens.length;
              // (uint256[] memory amts, uint gas) = _calculateUniswapV2(localVar);
              // rets[n] = amts;
              // n ++;
              // for (uint j = 0; j < midTokens.length; j ++) {
              //     localVar.midToken = midTokens[j];
              //     (uint256[] memory amts, uint gas) = _calculateUniswapV2OverMidToken(localVar);
              //     rets[n] = amts;
              //     n ++;
              // }
          }
        }

        console.log("before _findBestDistribution");
        
        (, distribution) = _findBestDistribution(args.parts, matrix);

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
                param.routers ++;
            }
        }

        param.srcToken = address(args.fromToken);
        param.amts = new uint[](param.routers);
        param.outAmts = new uint[](param.routers);
        param.minOutAmts = new uint[](param.routers);
        param.flags = new uint[](param.routers);
        param.pools = new bytes32[][](param.routers);

        uint total;
        uint idx;
        // uint amtIn = args.amount.mul(args.parts);
        // uint slip = 10000 - args.slip;
        
        for (uint i = 0; i < distribution.length; i ++) {
            if (distribution[i] > 0) {
                estimateGasAmount = estimateGasAmount.add(gases[i]);
                int256 value = matrix[i][distribution[i]] + int256(gases[i].mul(args.destTokenEthPriceTimesGasPrice).div(1e18));
                returnAmount = returnAmount.add(uint256(value));

                if (idx == param.routers - 1) {
                    // 弥补精度
                    param.amts[idx] = args.amount - total;
                } else {
                    param.amts[idx] = args.amount.mul(distribution[i]).div(args.parts);
                }
                param.outAmts[idx] = uint256(value);
                param.minOutAmts[idx] = uint256(value);  // .mul(10000 - args.slip).div(10000);
                // param.minOutAmts[idx] = uint256(value).mul(10000 - args.slip).div(10000);
                total += param.amts[idx];
                // uint units = args.midTokens.length + 1;
                if (i % (args.midTokens.length+1) == 0) {
                    // 没有中间交易对
                    //bytes32[] memory data = 
                    param.pools[idx] = _buildPoolData(PairParam({
                      factory: factories[i/(args.midTokens.length+1)],
                      srcToken: args.fromToken,
                      midToken: IERC20(0),
                      destToken: args.destToken,
                      feeRate: 997000
                      })
                      );
                    //  = new bytes32[](1); // 
                } else {
                    // 有中间交易对的情况
                    // param.pools[idx] = 
                    uint units = args.midTokens.length+1;
                    // IERC20 midToken = args.midTokens[(i%units)-1];
                    param.pools[idx] = _buildPoolData(PairParam({
                      factory: factories[i/(units)],
                      srcToken: args.fromToken,
                      midToken: args.midTokens[(i%units)-1],
                      destToken: args.destToken,
                      feeRate: 997000
                    })
                    );
                }

                idx ++;
            }
        }

        param.returnAmt = returnAmount;
        data = abi.encode(param);
    }

    struct PairParam {
      IUniswapV2Factory factory;
      IERC20 srcToken;
      IERC20 midToken;
      IERC20 destToken;
      uint feeRate;
    }

    // feeRate 的分母是 1000_000
    function _buildPoolData(PairParam memory pairParam) private view returns (bytes32[] memory) {
        bytes32[] memory data;
        
        uint feeRate = pairParam.feeRate << 160;
        //console.log("_buildPoolData:", feeRate);
        IERC20 fromTokenReal = pairParam.srcToken.isETH() ? weth : pairParam.srcToken;
        IERC20 destTokenReal = pairParam.destToken.isETH() ? weth : pairParam.destToken;
        address[] memory path;

        if (address(pairParam.midToken) == address(0)) {
            data = new bytes32[](1);
            path = new address[](2);
            path[0] = address(fromTokenReal);
            path[1] = address(destTokenReal);
        } else {
            data = new bytes32[](2);
            path = new address[](3);
            path[0] = address(fromTokenReal);
            path[1] = address(pairParam.midToken);
            path[2] = address(destTokenReal);
        }

        for (uint i = 0; i < path.length - 1; i ++) {
            address t0 = path[i];
            address t1 = path[i+1];

            address pair = address(pairParam.factory.getPair(IERC20(t0), IERC20(t1)));
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

    // function _getReserves(IERC20[] memory midTokens) private returns (function(IUniswapV2Factory,IERC20,IERC20,uint256,uint256,uint256) view returns(uint256[] memory, uint256)[] memory) {
    //   function(IUniswapV2Factory,IERC20,IERC20,uint256,uint256,uint256) view returns(uint256[] memory, uint256)[] memory reserves = new function(IUniswapV2Factory,IERC20,IERC20,uint256,uint256,uint256) view returns(uint256[] memory, uint256)[]();

    //   for (uint i = 0; i < factories.length; i ++ ) {
    //       reserves.push();
    //       for (uint j = 0; j < midTokens.length; j ++) {

    //       }
    //   }
    // }

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

    function _calculateUniswapV2(CalcVars memory lvar) internal view returns(uint256[] memory rets, uint256 gas) {
        IUniswapV2Factory factory = lvar.factory;
        IERC20 fromToken = lvar.fromToken;
        IERC20 destToken = lvar.destToken;
        uint256[] memory amounts = lvar.amounts;
        // uint256 /*flags*/
        rets = new uint256[](amounts.length);

        IERC20 fromTokenReal = fromToken.isETH() ? weth : fromToken;
        IERC20 destTokenReal = destToken.isETH() ? weth : destToken;
        IUniswapV2Exchange exchange = factory.getPair(fromTokenReal, destTokenReal);
        if (exchange != IUniswapV2Exchange(0)) {
            uint256 fromTokenBalance = fromTokenReal.uniBalanceOf(address(exchange));
            uint256 destTokenBalance = destTokenReal.uniBalanceOf(address(exchange));
            for (uint i = 0; i < amounts.length; i++) {
                rets[i] = _calculateUniswapFormula(fromTokenBalance, destTokenBalance, amounts[i]);
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
