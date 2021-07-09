// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./interface/IWETH.sol";
import "./interface/ICToken.sol";
import "./interface/IRouter.sol";
import "./interface/IDeBankRouter.sol";
import "./library/SafeMath.sol";

// import "./interface/IAToken.sol";

/**
 * @title Exchanges library 计算能够 mint 、赎回、兑换多少
 * @author ebankex
 * @notice Provides data types and functions to perform step swap calculations
 * @dev DataTypes are used for aggressive swap within multi swap exchanges.
 **/

library Exchanges {
    using SafeMath for uint;
    using SafeMath for uint256;

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
    function uniswapLikeExchange(address router, address[] memory path, uint256 amountIn) public returns (uint) {
        uint[] amounts = IRouter(router).getAmountsOut(amountIn, path);
        return amounts[amounts.length - 1];
    }

    /// @dev ebank exchange
    function ebankExchange(address router, address[] memory path, uint256 amountIn, address to) public returns (uint) {
        uint[] amounts = IDeBankRouter(router).getAmountsOut(amountIn, path, to);
        return amounts[amounts.length - 1];
    }

    /// @dev swap stable coin in curve
    function curveExchange(address addr, uint i, uint j, uint dx) public returns (uint) {
        return ICurve(addr).get_y(i, j, dx);
    }
}
