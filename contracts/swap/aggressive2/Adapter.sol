// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./interface/IWETH.sol";
import "./interface/ICToken.sol";
import "./library/SafeMath.sol";

// import "./interface/IAToken.sol";

/**
 * @title DataTypes library
 * @author ebankex
 * @notice Provides data types and functions to perform step swap calculations
 * @dev DataTypes are used for aggressive swap within multi swap exchanges.
 **/

contract StepSwapExecutor {
    using SafeMath for uint;
    using SafeMath for uint256;

    IWETH public immutable WETH;

    constructor(address weth_) public {
        WETH = IWETH(weth_);
    }

    // deposit eth from address from
    function depositETH() public payable returns (uint256) {
        WETH.deposit();

        return WETH.balanceOf(address(this));
    }

    // withdraw weth
    function withdrawWETH(uint256 amount) public {
        WETH.withdraw(amount);
    }

    // mint token in compound
    // token must NOT be ETH, ETH should _depositETH first, then do compound mint
    // 币已经转到合约地址
    function compoundMintToken(address ctoken, uint256 amount) public returns (uint256) {
        uint256 balanceBefore = IERC20(ctoken).balanceOf(address(this));
        ICToken(ctoken).mint(amount);

        return IERC20(ctoken).balanceOf(address(this)).sub(balanceBefore);
    }

    // 
    function compoundMintETH() public payable returns (uint256) {
        WETH.deposit();

        return compoundMintToken(address(WETH), msg.value);
    }

    // 
    function compoundRedeemCToken(address ctoken, uint256 amount) public {
        ctoken;
    }


    // aave deposit token
    function aaveDepositToken(address aToken) public {
        aToken;
    }
}
