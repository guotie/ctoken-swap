// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./interface/IWETH.sol";
import "./interface/ICToken.sol";
import "./interface/IRouter.sol";
import "./interface/IDeBankRouter.sol";
import "./library/SafeMath.sol";
import "./libray/DataTypes.sol";

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

    uint constant public MAX_COMPLEX_LEVEL = 3;

    uint constant public EXCHANGE_UNISWAP_V2 = 1;  // prettier-ignore
    uint constant public EXCHANGE_UNISWAP_V3 = 2;  // prettier-ignore
    uint constant public EXCHANGE_EBANK_EX   = 3;  // prettier-ignore
    uint constant public EXCHANGE_CURVE      = 4;  // prettier-ignore


    /// @dev 根据 midToken 数量, complexLevel 计算类 uniswap 交易所有多少个交易路径
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

    // 计算所有路径
    function allPaths(DataTypes.QuoteParams calldata args) internal pure returns (address[][] paths) {
        uint complexLevel = args.flag.getComplexLevel();
        uint mids = args.midTokens.length;
        address token0 = args.tokenIn;
        address token1 = args.tokenOut;
        
        if (complexLevel > MAX_COMPLEX_LEVEL) {
            complexLevel = MAX_COMPLEX_LEVEL;
        }

        if (complexLevel >= mids) {
            complexLevel = mids;
        }

        uint total = uniswapRoutes(mids, complexLevel);
        uint idx = 0;
        paths = new address[][](total);
        paths[idx] = [token0, token1];
        idx ++;

        for (uint i = 1; i <= complexLevel; i ++) {
            uint p = 1;
            address[] path = new address[](i+2);
            path[0] = token0;
            path[path.length-1] = token1;
            for (uint j = 0; j < i; j ++) {
            
                p = p * (midTokens-j);
            }
        }
    }

    function getExchangeRoutes(uint flag, uint midTokens, uint complexLevel) public  {
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
    function calcDistributes(Exchanges.Exchange memory ex, address[] memory path, uint[] amts, address to) public view returns (uint256[] memory distributes){
        uint flag = ex.flag;
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


    // deposit eth from address from
    function depositETH(IWETH weth) public payable returns (uint256) {
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
    function convertCompoundCtokenMinted(address ctoken, uint amount) public view returns (uint256) {
        uint256 rate = _calcExchangeRate(ICToken(ctoken));

        return amount.mul(1e18).div(rate);
    }

    /// @dev 计算 ctoken 能够 redeem 得到多少 token
    function convertCompoundTokenRedeemed(address ctoken, uint amount) public view returns (uint256) {
        uint256 rate = _calcExchangeRate(ICToken(ctoken));

        return amount.mul(rate).div(1e18);
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
    function compoundMintETH(address weth) public payable returns (uint256) {
        weth.deposit();

        return compoundMintToken(address(weth), msg.value);
    }

    /// @dev compoundRedeemCToken redeem compound token
    /// @param ctoken compund token
    /// @param amount amount to redeem
    function compoundRedeemCToken(address ctoken, uint256 amount) public {
        ICToken(ctoken).redeem(amount);
    }

    /// @dev aave deposit token
    function aaveDepositToken(address aToken) public {
        aToken;
    }

    /// @dev withdraw aave token
    function aaveWithdrawToken(address aToken, uint256 amt) public {
        aToken;
        amt;
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////


    /// @dev uniswap like exchange
    function uniswapLikeSwap(address router, address[] memory path, uint256 amountIn) public returns (uint) {
        uint[] amounts = IRouter(router).getAmountsOut(amountIn, path);
        return amounts[amounts.length - 1];
    }

    /// @dev ebank exchange
    function ebankSwap(address router, address[] memory path, uint256 amountIn, address to) public returns (uint) {
        uint[] amounts = IDeBankRouter(router).getAmountsOut(amountIn, path, to);
        return amounts[amounts.length - 1];
    }

    /// @dev swap stable coin in curve
    function curveSwap(address addr, uint i, uint j, uint dx) public returns (uint) {
        return ICurve(addr).get_y(i, j, dx);
    }
}
