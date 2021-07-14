// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./interface/IWETH.sol";
import "./interface/ICToken.sol";
import "./interface/IRouter.sol";
import "./interface/IDeBankRouter.sol";
import "./interface/ICurve.sol";
import "./library/SafeMath.sol";
import "./library/DataTypes.sol";
import "./library/SwapFlag.sol";

// import "./interface/IAToken.sol";

/**
 * @title Exchanges library 计算能够 mint 、赎回、兑换多少
 * @author ebankex
 * @notice Provides data types and functions to perform step swap calculations
 * @dev Exchanges are used for aggressive swap within multi swap exchanges.
 **/

library Exchanges {
    using SafeMath for uint;
    using SafeMath for uint256;
    using SwapFlag for DataTypes.SwapFlagMap;

    uint constant public MAX_COMPLEX_LEVEL = 3;

    uint constant public EXCHANGE_UNISWAP_V2 = 1;  // prettier-ignore
    uint constant public EXCHANGE_UNISWAP_V3 = 2;  // prettier-ignore
    uint constant public EXCHANGE_EBANK_EX   = 3;  // prettier-ignore
    uint constant public EXCHANGE_CURVE      = 4;  // prettier-ignore

    uint constant public SWAP_EBANK_CTOKENS_CTOKENS      = 1;  // prettier-ignore
    uint constant public SWAP_EBANK_TOKENS_TOKENS        = 1;  // prettier-ignore
    uint constant public SWAP_EBANK_ETH_TOKENS           = 1;  // prettier-ignore
    uint constant public SWAP_EBANK_TOKENS_ETH           = 1;  // prettier-ignore

    /// @dev 根据 midToken 数量, complexLevel 计算类 uniswap 交易所有多少个交易路径: 1 + P(midTokens, 1) + P(midTokens, 2) + .... + P(midTokens, complex)
    /// complexLevel: 一次兑换时, 中间token的数量。例如为 2 时，可以的兑换路径为 a-m1-m2-b, a-m2-m1-b 或者 a-m1-b a-m2-b
    /// 仅对于uniswap类的交易所, 其他类型交易所例如 curve 不适用
    function uniswapRoutes(uint midTokens, uint complexLevel) internal pure returns (uint) {
        uint count = 1;

        if (complexLevel > MAX_COMPLEX_LEVEL) {
            complexLevel = MAX_COMPLEX_LEVEL;
        }

        if (complexLevel >= midTokens) {
            complexLevel = midTokens;
        }
        for (uint i = 1; i <= complexLevel; i ++) {
            uint p = 1;
            for (uint j = 0; j < i; j ++) {
                p = p * (midTokens-j);
            }
            count += p;
        }

        return count;
    }

    /// @dev 递归计算特定 complex 下 paths 数组: P(midTokens, complex)
    function calcPathComplex(
                address[][] memory paths,
                uint idx,
                uint complex,
                address token1,
                address[] memory midTokens,
                address[] memory path) internal pure returns (uint) {
        if (complex == 0) {
            address[] memory npath = new address[](path.length+1);
            for (uint i = 0; i < path.length; i ++) {
                npath[i] = path[i];
            }
            npath[path.length-1] = token1;
            paths[idx] = npath;
            return idx+1;
        }

        for (uint i = 0; i < midTokens.length; i ++) {
            address[] memory npath = new address[](path.length+1);
            for (uint ip = 0; ip < path.length; ip ++) {
                npath[ip] = path[ip];
            }
            address midToken = midTokens[i];
            npath[path.length-1] = midToken;

            uint nMidLen = 0;
            for (uint j = 0; j < midTokens.length; j ++) {
                address mid = midTokens[j];
                if (_itemInArray(npath, mid) == false) {
                    nMidLen ++;
                }
            }
            address[] memory nMidTokens = new address[](nMidLen);
            uint midIdx = 0;
            for (uint j = 0; j < midTokens.length; j ++) {
                address mid = midTokens[j];
                if (_itemInArray(npath, mid) == false) {
                    nMidTokens[midIdx] = mid;
                    midIdx ++;
                }
            }
            idx = calcPathComplex(paths, idx, complex-1, token1, nMidTokens, npath);
            // npath.pop();
        }
    }

    /// @dev _itemInArray item 是否在数组 vec 中
    function _itemInArray(address[] memory vec, address item) private pure returns (bool) {
        for (uint i = 0; i < vec.length; i ++) {
            if (item == vec[i]) {
                return true;
            }
        }
        return false;
    }

    // 计算所有路径
    function allPaths(
                address tokenIn,
                address tokenOut,
                address[] memory midTokens,
                uint complexLevel
            )
                internal
                pure
                returns (address[][] memory paths) {
        // uint complexLevel = args.flag.getComplexLevel();
        uint mids = midTokens.length;
        // address token0 = args.tokenIn;
        // address token1 = args.tokenOut;
        
        if (complexLevel > MAX_COMPLEX_LEVEL) {
            complexLevel = MAX_COMPLEX_LEVEL;
        }

        if (complexLevel >= mids) {
            complexLevel = mids;
        }

        uint total = uniswapRoutes(mids, complexLevel);
        uint idx = 0;
        paths = new address[][](total);
        // paths[idx] = new address[]{token0, token1};
        // idx ++;

        address[] memory initialPath = new address[](1);
        initialPath[0] = tokenIn;

        // address[] memory midTokens = new address[](midTokens.length);
        // for (uint i = 0; i < mids; i ++) {
        //     midTokens[i] = args.midTokens[i];
        // }

        for (uint i = 0; i <= complexLevel; i ++) {
            idx = calcPathComplex(paths, idx, i, tokenOut, midTokens, initialPath);
        }
    }

    function getExchangeRoutes(uint flag, uint midTokens, uint complexLevel) public pure returns (uint)  {
        if (isUniswapLikeExchange(flag)) {
            return uniswapRoutes(midTokens, complexLevel);
        }
        // todo 其他更多的类型
        return 1;
    }

    function linearInterpolation(
        uint256 value,
        uint256 parts
    ) internal pure returns(uint256[] memory rets) {
        rets = new uint256[](parts);
        for (uint i = 0; i < parts; i++) {
            rets[i] = value.mul(i + 1).div(parts);
        }
    }

    /// @dev calcDistributes calc swap exchange
    function calcDistributes(
                DataTypes.Exchange memory ex,
                address[] memory path,
                uint[] memory amts,
                address to) public view returns (uint256[] memory distributes){
        uint flag = ex.exFlag;
        address addr = ex.contractAddr;

        distributes = new uint256[](amts.length);
        if (flag == EXCHANGE_UNISWAP_V2 || flag == EXCHANGE_UNISWAP_V3) {
            for (uint i = 0; i < amts.length; i ++) {
                distributes[i] = uniswapLikeSwap(addr, path, amts[i]);
            }
        } else if (flag == EXCHANGE_EBANK_EX) {
            for (uint i = 0; i < amts.length; i ++) {
                distributes[i] = ebankSwap(addr, path, amts[i], to);
            }
        } else {
            // should NOT reach here
        }
        // todo other swap
    }

    // 是否是 uniswap 类似的交易所
    function isUniswapLikeExchange(uint flag) public pure returns (bool) {
        if (flag == EXCHANGE_UNISWAP_V2 || flag == EXCHANGE_UNISWAP_V3 || flag == EXCHANGE_EBANK_EX) {
            return true;
        }
        return false;
    }

    function isEBankExchange(uint flag) public pure returns (bool) {
        if (flag == EXCHANGE_EBANK_EX) {
            return true;
        }
        return false;
    }


    // deposit eth from address from
    function depositETH(IWETH weth) public returns (uint256) {
        weth.deposit();

        return weth.balanceOf(address(this));
    }

    // withdraw weth
    function withdrawWETH(IWETH weth, uint256 amount) public {
        weth.withdraw(amount);
    }

    /// @dev 计算 ctoken 的 exchange rate
    function _calcExchangeRate(ICToken ctoken) private view returns (uint) {
        uint rate = ctoken.exchangeRateStored();
        uint supplyRate = ctoken.supplyRatePerBlock();
        uint lastBlock = ctoken.accrualBlockNumber();
        uint blocks = block.number.sub(lastBlock);
        uint inc = rate.mul(supplyRate).mul(blocks);
        return rate.add(inc);
    }

    /// @dev 计算 token 能够 mint 得到多少 ctoken
    function convertCompoundCtokenMinted(address ctoken, uint[] memory amounts, uint parts) public view returns (uint256[] memory) {
        uint256 rate = _calcExchangeRate(ICToken(ctoken));
        uint256[] memory cAmts = new uint256[](parts);

        for (uint i = 0; i < parts; i ++) {
            cAmts[i] = amounts[i].mul(1e18).div(rate);
        }
        return cAmts;
    }

    /// @dev 计算 ctoken 能够 redeem 得到多少 token
    function convertCompoundTokenRedeemed(address ctoken, uint[] memory cAmounts, uint parts) public view returns (uint256[] memory) {
        uint256 rate = _calcExchangeRate(ICToken(ctoken));
        uint256[] memory amts = new uint256[](parts);

        for (uint i = 0; i < parts; i ++) {
            amts[i] = cAmounts[i].mul(rate).div(1e18);
        }
        return amts;
    }

    // mint token in compound
    // token must NOT be ETH, ETH should _depositETH first, then do compound mint
    // 币已经转到合约地址
    function compoundMintToken(address ctoken, uint256 amount) public returns (uint256) {
        uint256 balanceBefore = IERC20(ctoken).balanceOf(address(this));
        ICToken(ctoken).mint(amount);

        return IERC20(ctoken).balanceOf(address(this)).sub(balanceBefore);
    }

    /// @dev compund mint ETH
    function compoundMintETH(address weth, uint amount) public returns (uint256) {
        IWETH(weth).deposit{value: amount}();

        return compoundMintToken(address(weth), amount);
    }

    /// @dev compoundRedeemCToken redeem compound token
    /// @param ctoken compund token
    /// @param amount amount to redeem
    function compoundRedeemCToken(address ctoken, uint256 amount) public {
        ICToken(ctoken).redeem(amount);
    }

    /// @dev aave deposit token
    function aaveDepositToken(address aToken) public pure {
        aToken;
    }

    /// @dev withdraw aave token
    function aaveWithdrawToken(address aToken, uint256 amt) public pure {
        aToken;
        amt;
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////

    /// todo 需要考虑 reserve 为 0 的情况

    /// @dev uniswap like exchange
    function uniswapLikeSwap(address router, address[] memory path, uint256 amountIn) public view returns (uint) {
        uint[] memory amounts = IRouter(router).getAmountsOut(amountIn, path);
        return amounts[amounts.length - 1];
    }

    /// @dev ebank exchange
    function ebankSwap(address router, address[] memory path, uint256 amountIn, address to) public view returns (uint) {
        uint[] memory amounts = IDeBankRouter(router).getAmountsOut(amountIn, path, to);
        return amounts[amounts.length - 1];
    }

    /// @dev swap stable coin in curve
    function curveSwap(address addr, uint i, uint j, uint dx) public view returns (uint) {
        return ICurve(addr).get_dy(int128(i), int128(j), dx);
    }
}
