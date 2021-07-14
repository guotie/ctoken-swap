// Sources flattened with hardhat v2.2.1 https://hardhat.org

// File @openzeppelin/contracts/GSN/Context.sol@v2.5.1

pragma solidity ^0.5.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


// File @openzeppelin/contracts/ownership/Ownable.sol@v2.5.1

pragma solidity ^0.5.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


// File contracts/swap/library/SafeMath.sol

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity >=0.5.16;

library SafeMath {
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    function wad() public pure returns (uint256) {
        return WAD;
    }

    function ray() public pure returns (uint256) {
        return RAY;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function sqrt(uint256 a) internal pure returns (uint256 b) {
        if (a > 3) {
            b = a;
            uint256 x = a / 2 + 1;
            while (x < b) {
                b = x;
                x = (a / x + x) / 2;
            }
        } else if (a != 0) {
            b = 1;
        }
    }

    function wmul(uint256 a, uint256 b) internal pure returns (uint256) {
        return mul(a, b) / WAD;
    }

    function wmulRound(uint256 a, uint256 b) internal pure returns (uint256) {
        return add(mul(a, b), WAD / 2) / WAD;
    }

    function rmul(uint256 a, uint256 b) internal pure returns (uint256) {
        return mul(a, b) / RAY;
    }

    function rmulRound(uint256 a, uint256 b) internal pure returns (uint256) {
        return add(mul(a, b), RAY / 2) / RAY;
    }

    function wdiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(mul(a, WAD), b);
    }

    function wdivRound(uint256 a, uint256 b) internal pure returns (uint256) {
        return add(mul(a, WAD), b / 2) / b;
    }

    function rdiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(mul(a, RAY), b);
    }

    function rdivRound(uint256 a, uint256 b) internal pure returns (uint256) {
        return add(mul(a, RAY), b / 2) / b;
    }

    function wpow(uint256 x, uint256 n) internal pure returns (uint256) {
        uint256 result = WAD;
        while (n > 0) {
            if (n % 2 != 0) {
                result = wmul(result, x);
            }
            x = wmul(x, x);
            n /= 2;
        }
        return result;
    }

    function rpow(uint256 x, uint256 n) internal pure returns (uint256) {
        uint256 result = RAY;
        while (n > 0) {
            if (n % 2 != 0) {
                result = rmul(result, x);
            }
            x = rmul(x, x);
            n /= 2;
        }
        return result;
    }
}


// File contracts/swap/interface/IERC20.sol

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity ^0.5.16;

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);
}


// File contracts/swap/interface/LErc20DelegatorInterface.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.5.16;
// import "./CTokenInterfaces.sol";

contract LErc20DelegatorInterface {
      function delegateToInitialize(address underlying_,
                address comptroller_,
                address interestRateModel_,
                uint initialExchangeRateMantissa_,
                string memory name_,
                string memory symbol_,
                uint8 decimals_,
                address payable admin_,
                address implementation_,
                bytes memory becomeImplementationData) public {}

      // get or create ctoken
      function getCTokenAddress(address token) external returns (address cToken);
      function getCTokenAddressPure(address cToken) external view returns (address);
      function getTokenAddress(address cToken) external view returns (address);
}


// File contracts/swap/interface/IDeBankFactory.sol

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity ^0.5.16;
interface IDeBankFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);

    function router() external view returns (address);

    // function feeToSetter() external view returns (address);

    function lpFeeRate() external view returns (uint256);

    function lErc20DelegatorFactory() external view returns (LErc20DelegatorInterface);

    function anchorToken() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;

    // function setFeeToSetter(address) external;

    function setFeeToRate(uint256) external;

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    function pairFor(address tokenA, address tokenB) external view returns (address pair);

    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    // function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountOut);

    // function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    // function amountToCTokenAmt(address ctoken, uint amountIn) external view returns (uint cAmountIn);
    // function ctokenAmtToAmount(address ctoken, uint cAmountOut) external view returns (uint amountOut);

    function setPairFeeRate(address pair, uint feeRate) external;

    function getReservesFeeRate(address tokenA, address tokenB, address to) external view returns (uint reserveA, uint reserveB, uint feeRate, bool outAnchorToken);

    function getAmountOutFeeRate(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountOut);

    function getAmountInFeeRate(uint amountOut, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountIn);

    function getAmountOutFeeRateAnchorToken(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountOut);

    function setAnchorToken(address _token) external;
}


// File contracts/swap/interface/IDeBankPair.sol

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity ^0.5.16;

interface IDeBankPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    // function ownerAmountOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);

    function factory() external view returns (address);

    function feeRate() external view returns (uint);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    // function mintCToken(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    function swapNoFee(uint amount0Out, uint amount1Out, address to, uint fee) external;

    function skim(address to) external;

    function sync() external;

    function price(address token, uint256 baseDecimal) external view returns (uint256);

    function initialize(address, address, address, address) external;
    function updateFeeRate(uint256 _feeRate) external;
    // initialize ctoken address
    // function initializeCTokenAddress(address, address) external;

    function getFee(uint256 amt) external view returns (uint256);

    // function updateFeeRate(_feeRate) external;
}


// File contracts/swap/interface/IDeBankRouter.sol

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity ^0.5.16;

interface IDeBankRouter {
    function factory() external view returns (address);

    function WHT() external view returns (address);

    function allPairFee() external view returns (uint);

    function allPairFeeLastBlock() external view returns (uint);

    function reward(uint256 blockNumber) external view returns (uint256);

    function rewardToken() external view returns (address);

    function lpDepositAddr() external view returns (address);
    
    function compAddr() external view returns (address);

    function startBlock() external view returns (uint);

    function swapMining() external view returns (address);

    function getBlockRewards(uint256 _lastRewardBlock) external view returns (uint256);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityUnderlying(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETHUnderlying(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityUnderlying(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHUnderlying(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHUnderlyingWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokensUnderlying(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokensUnderlying(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokensUnderlying(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function swapTokensForExactETHUnderlying(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function swapExactTokensForETHUnderlying(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function swapETHForExactTokensUnderlying(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    // external
    // payable
    // returns (uint[] memory amounts);

    // function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    // external
    // returns (uint[] memory amounts);

    // function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    // external
    // returns (uint[] memory amounts);

    // function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    // external
    // payable
    // returns (uint[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external view returns (uint256 amountB);

    // function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountOut);

    // function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    // function removeLiquidityETHSupportingFeeOnTransferTokens(
    //     address token,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline
    // ) external returns (uint amountETH);

    // function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    //     address token,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline,
    //     bool approveMax, uint8 v, bytes32 r, bytes32 s
    // ) external returns (uint amountETH);

    // function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external;

    // function swapExactETHForTokensSupportingFeeOnTransferTokens(
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external payable;

    // function swapExactTokensForETHSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external;
}


// File contracts/swap/interface/IWHT.sol

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity ^0.5.16;

interface IWHT {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}


// File contracts/swap/interface/ICToken.sol

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.5.16;

interface ICToken {

    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);

    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function accrueInterest() external returns (uint);
    function accrualBlockNumber() external view returns (uint);
    // function getCash() virtual external view returns (uint);
    // function accrueInterest() virtual public returns (uint);
    // function seize(address liquidator, address borrower, uint seizeTokens) virtual external returns (uint);

}


// File contracts/swap/heco/Router.sol

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity ^0.5.16;
// import "../../compound/LHT.sol";
// import "hardhat/console.sol";

interface ILHT {
    function mint() external payable;
}

interface ISwapMining {
    function swap(address account, address input, address output, uint256 amount) external returns (bool);
}

contract DeBankRouter is IDeBankRouter, Ownable {
    using SafeMath for uint256;

    address public factory;
    address public WHT;
    address public swapMining;
    address[] public quoteTokens;
    address public cWHT;

    // 鎵€鏈変氦鏄撳浜х敓鐨勬墜缁垂鏀跺叆, 鍚勪釜浜ゆ槗瀵规牴鎹崰姣斿垎閰嶆敹鐩?
    uint public allPairFee;
    // 涓婁竴涓潡鐨勬€绘墜缁垂
    uint public allPairFeeLastBlock;
    // 寮€濮嬪垎閰嶆敹鐩婄殑鍧?
    uint public startBlock;
    // 璁板綍褰撳墠鎵嬬画璐圭殑鍧楁暟
    uint public currentBlock;
    // tokens created per block to all pair LP
    uint256 public lpPerBlock;      // LP 姣忓潡鏀剁泭
    uint256 public traderPerBlock;  // 浜ゆ槗鑰呮瘡鍧楁敹鐩?
    address public rewardToken;     // 鏀剁泭 token
    address public lpDepositAddr;   // compound 娴佸姩鎬ф姷鎶?
    address public compAddr;        // compound unitroller
    uint256 public feeAlloc;        // 鎵嬬画璐瑰垎閰嶆柟妗? 0: 鍒嗛厤缁橪P; 1: 涓嶅垎閰嶇粰LP, 骞冲彴鏀跺彇鍚庡厬鎹负 anchorToken
    // todo How many blocks are halved  182澶?搴旇鍦?rewardToken 涓鐞?
    uint256 public halvingPeriod = 5256000;

    modifier ensure(uint deadline) {
        // solhint-disable-next-line
        require(deadline >= block.timestamp, 'DeBankRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _wht, address _cwht, uint _startBlock) public {
        factory = _factory;
        WHT = _wht;
        cWHT = _cwht;
        startBlock = _startBlock;
        // heco 閾句笂鐨?usdt
        quoteTokens.push(IDeBankFactory(_factory).anchorToken()); // usdt
        quoteTokens.push(_cwht); // wht
        // quoteTokens.push();  // husd
    }

    function() external payable {
        assert(msg.sender == WHT || msg.sender == cWHT);
        // only accept HT via fallback from the WHT contract
    }

    function pairFor(address tokenA, address tokenB) public view returns (address pair) {
        // pair = IDeBankFactory(factory).pairFor(tokenA, tokenB);
        pair = IDeBankFactory(factory).getPair(tokenA, tokenB);
    }

    function setSwapMining(address _swapMininng) public onlyOwner {
        swapMining = _swapMininng;
    }

    function resetQuoteTokens(address[] memory tokens) public onlyOwner {
        for (uint i; i < quoteTokens.length; i ++) {
            quoteTokens.pop();
        }
        // quoteTokens.length = 0;
        for (uint i; i < tokens.length; i ++) {
            quoteTokens.push(tokens[i]);
        }
    }

    function addQuoteToken(address token) public onlyOwner {
        quoteTokens.push(token);
    }

    function phase(uint256 blockNumber) public view returns (uint256) {
        if (halvingPeriod == 0) {
            return 0;
        }
        if (blockNumber > startBlock) {
            return (blockNumber.sub(startBlock).sub(1)).div(halvingPeriod);
        }
        return 0;
    }

    // 璁＄畻鍧楀鍔?
    function reward(uint256 blockNumber) public view returns (uint256) {
        if (rewardToken == address(0)) {
            return 0;
        }
        // todo totalSupply !!!
        // if (IERC20(rewardToken).totalSupply() > 1e28) {
        //     return 0;
        // }
        uint256 _phase = phase(blockNumber);
        return lpPerBlock.div(2 ** _phase);
    }

    // todo to be removed
    function getBlockRewards(uint256 _lastRewardBlock) public view returns (uint256) {
        uint256 blockReward = 0;
        uint256 n = phase(_lastRewardBlock);
        uint256 m = phase(block.number);
        while (n < m) {
            n++;
            uint256 r = n.mul(halvingPeriod).add(startBlock);
            blockReward = blockReward.add((r.sub(_lastRewardBlock)).mul(reward(r)));
            _lastRewardBlock = r;
        }
        blockReward = blockReward.add((block.number.sub(_lastRewardBlock)).mul(reward(block.number)));
        return blockReward;
    }

    function _getOrCreateCtoken(address token) private returns (address ctoken) {
        ctoken = LErc20DelegatorInterface(IDeBankFactory(factory).lErc20DelegatorFactory()).getCTokenAddress(token);
    }

    function _getCtoken(address token) private view returns (address ctoken) {
        ctoken = LErc20DelegatorInterface(IDeBankFactory(factory).lErc20DelegatorFactory()).getCTokenAddressPure(token);
    }

    function _getTokenByCtoken(address ctoken) private view returns (address token) {
        token = LErc20DelegatorInterface(IDeBankFactory(factory).lErc20DelegatorFactory()).getTokenAddress(ctoken);
    }

    // function _safeTransferCtoken(address token, address from, address to, uint amt) private {
    //     TransferHelper.safeTransferFrom(_getCtoken(token), from, to, amt);
    // }

    // **** ADD LIQUIDITY ****

    struct LiquidityLocalVars {
        // uint amountToken;
        // uint amountEth;
        uint camountDesiredA;
        uint camountDesiredB;
        uint camountMinA;
        uint camountMinB;

        uint rateA;
        uint rateB;
        uint rateEth;
        uint camountA;
        uint camountB;
        uint camountEth;

        address tokenA;
        address tokenB;
        address ctokenA;
        address ctokenB;
    }

    // tokenA tokenB 閮芥槸 cToken
    function _addLiquidity(
        address ctokenA,
        address ctokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint amountA, uint amountB) {
        // console.log("_addLiquidity", factory);
        address tokenA = _getTokenByCtoken(ctokenA);
        address tokenB = _getTokenByCtoken(ctokenB);
        // create the pair if it doesn't exist yet
        if (IDeBankFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IDeBankFactory(factory).createPair(tokenA, tokenB);
        }
        // console.log("_addLiquidity getReserves");
        (uint reserveA, uint reserveB) = IDeBankFactory(factory).getReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = IDeBankFactory(factory).quote(amountADesired, reserveA, reserveB);
            // console.log("_addLiquidity: reserveA=%d  reserveB=%d", reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                // console.log("_addLiquidity: amountBOptimal=%d  amountBDesired=%d  amountADesired=%d",
                //       amountBOptimal, amountBDesired, amountADesired);
                require(amountBOptimal >= amountBMin, 'AddLiquidity: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = IDeBankFactory(factory).quote(amountBDesired, reserveB, reserveA);
                // console.log("_addLiquidity: amountAOptimal=%d  amountADesired=%d  amountBDesired=%d",
                //       amountAOptimal, amountADesired, amountBDesired);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'AddLiquidity: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    // tokenA tokenB 閮芥槸 cToken, amount 鍧囦负 ctoken 鐨?amount
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        // console.log(tokenA, tokenB);
        // console.log("amountDesired:", amountADesired, amountBDesired);
        // console.log("amountMin:", amountAMin, amountBMin);
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = pairFor(tokenA, tokenB);
        // console.log("pair: %s", pair);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        // _safeTransferCtoken(tokenA, msg.sender, pair, amountA);
        // _safeTransferCtoken(tokenB, msg.sender, pair, amountB);
        liquidity = IDeBankPair(pair).mint(to);
    }

    function _cTokenExchangeRate(address ctoken) private view returns(uint) {
        uint rate = ICToken(ctoken).exchangeRateStored();
        uint256 supplyRate = ICToken(ctoken).supplyRatePerBlock();
        uint256 prevBlock = ICToken(ctoken).accrualBlockNumber();
        rate += rate.mul(supplyRate).mul(block.number - prevBlock);
        return rate;
    }

    // 0. 璁＄畻闇€瑕佸灏慳mount
    // 1. transfer token from msg.sender to router
    // 2. mint ctoken
    // 3. transfer ctoken to pair
    // amt 鏄?Ctoken 娴佸姩鎬ч渶瑕佺殑 amount
    function _mintTransferCToken(address token, address ctoken, address pair, uint amt) private {
        // uint er = _cTokenExchangeRate(ctoken);
        // uint amt = camt * er / 10**18;

        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amt);
        uint b0 = ICToken(ctoken).balanceOf(address(this));
        // mint 涔嬪墠闇€瑕?approve
        ICToken(token).approve(address(ctoken), amt);
        uint ret = ICToken(ctoken).mint(amt);
        ICToken(ctoken).approve(address(ctoken), 0);
        require(ret == 0, "mint failed");
        uint b1 = ICToken(ctoken).balanceOf(address(this));
        uint mintCAmt = b1 - b0;

        // console.log("_mintTransferCToken:", amt, mintCAmt);

        TransferHelper.safeTransferFrom(ctoken, address(this), pair, mintCAmt);
    }

    function _mintTransferEth(address pair, uint amt) private {
        uint b0 = ICToken(cWHT).balanceOf(address(this));
        // todo
        ILHT(cWHT).mint.value(amt)();
        // require(ret == 0, "mint failed");
        uint b1 = ICToken(cWHT).balanceOf(address(this));
        uint mintCAmt = b1 - b0;
        TransferHelper.safeTransferFrom(cWHT, address(this), pair, mintCAmt);
    }


    function _amount2CAmount(uint amt, uint rate) private pure returns (uint) {
        return amt.mul(10**18).div(rate);
    }

    function _camount2Amount(uint camt, uint rate) private pure returns (uint) {
        return camt.mul(rate).div(10**18);
    }

    // tokenA tokenB 閮芥槸 token
    // 6/23 濡傛灉 ctoken 涓嶅瓨鍦? 闇€瑕佸垱寤?ctoken
    function addLiquidityUnderlying(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        LiquidityLocalVars memory vars;

        vars.ctokenA = _getOrCreateCtoken(tokenA);
        vars.ctokenB = _getOrCreateCtoken(tokenB);
        vars.rateA = _cTokenExchangeRate(vars.ctokenA);
        vars.rateB = _cTokenExchangeRate(vars.ctokenB);
        vars.camountDesiredA = _amount2CAmount(amountADesired, vars.rateA);
        vars.camountDesiredB = _amount2CAmount(amountBDesired, vars.rateB);
        vars.camountMinA = _amount2CAmount(amountAMin, vars.rateA);
        vars.camountMinB = _amount2CAmount(amountBMin, vars.rateB);

        (vars.camountA, vars.camountB) = _addLiquidity(vars.ctokenA,
                vars.ctokenB,
                vars.camountDesiredA,
                vars.camountDesiredB,
                vars.camountMinA,
                vars.camountMinB);
        address pair = pairFor(tokenA, tokenB);
        // mint token 寰楀埌 ctoken
        amountA = _camount2Amount(vars.camountA, vars.rateA);
        amountB = _camount2Amount(vars.camountB, vars.rateB);
        // console.log("amountA: %d amountB: %d", amountA, amountB);
        _mintTransferCToken(tokenA, vars.ctokenA, pair, amountA);
        _mintTransferCToken(tokenB, vars.ctokenB, pair, amountB);
        // TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        // TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        // _safeTransferCtoken(tokenA, msg.sender, pair, amountA);
        // _safeTransferCtoken(tokenB, msg.sender, pair, amountB);
        // console.log('addLiquidityUnderlying: pair=%s', pair);
        liquidity = IDeBankPair(pair).mint(to);
    }

    // token 鏄?token 鑰屼笉鏄?ctoken
    // 杩欎釜鍑芥暟搴旇涓嶈兘鐩存帴琚皟鐢ㄤ簡, 濡傛灉鏄?ctoken, 鐩存帴璋冪敤涓婇潰鐨勫嚱鏁帮紱濡傛灉鏄?token, 闇€瑕佽皟鐢?todo
    function addLiquidityETHUnderlying(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        address ctoken = _getOrCreateCtoken(token);
        LiquidityLocalVars memory vars;
        vars.rateA = _cTokenExchangeRate(ctoken);
        vars.rateB = _cTokenExchangeRate(cWHT);
        vars.camountDesiredA = _amount2CAmount(amountTokenDesired, vars.rateA);
        vars.camountDesiredB = _amount2CAmount(msg.value, vars.rateB);
        vars.camountMinA = _amount2CAmount(amountTokenMin, vars.rateA);
        vars.camountMinB = _amount2CAmount(amountETHMin, vars.rateB);
        (uint amountCToken, uint amountCETH) = _addLiquidity(
            ctoken,
            cWHT,
            vars.camountDesiredA,
            vars.camountDesiredB,
            vars.camountMinA,
            vars.camountMinB
        );
        address pair = pairFor(token, WHT);

        amountToken = _camount2Amount(amountCToken, vars.rateA);
        amountETH = _camount2Amount(amountCETH, vars.rateB);
        _mintTransferCToken(token, ctoken, pair, amountToken);
        // TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        // _safeTransferCtoken(token, msg.sender, pair, amountToken);
        // IWHT(WHT).deposit.value(amountETH)();
        _mintTransferEth(pair, amountETH);
        // cWHT.value(amountETH).mint();
        // assert(IWHT(WHT).transfer(pair, amountETH));
        liquidity = IDeBankPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    // tokenA tokenB 閮芥槸 ctoken
    function removeLiquidity(
        address ctokenA,
        address ctokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = pairFor(ctokenA, ctokenB);
        IDeBankPair(pair).transferFrom(msg.sender, pair, liquidity);
        // console.log("transfer Liquidity success");
        // send liquidity to pair
        (uint amount0, uint amount1) = IDeBankPair(pair).burn(to);
        address tokenA = _getTokenByCtoken(ctokenA);
        address tokenB = _getTokenByCtoken(ctokenB);
        (address token0,) = IDeBankFactory(factory).sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'RemoveLiquidity: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'RemoveLiquidity: INSUFFICIENT_B_AMOUNT');
    }

    // 璧庡洖 ctoken
    function _redeemCToken(address ctoken, address token, uint camt) private returns (uint) {
        uint b0 = IERC20(token).balanceOf(address(this));
        uint err = ICToken(ctoken).redeem(camt);
        require(err == 0, "redeem failed");
        uint b1 = IERC20(token).balanceOf(address(this));
        // console.log(b1, b0);
        // require(b1 >= b0, "redeem failed");
        return b1.sub(b0);
    }

    // 璧庡洖 ctoken
    function _redeemCEth(uint camt) private returns (uint) {
        uint b0 = IERC20(WHT).balanceOf(address(this));
        uint err = ICToken(cWHT).redeem(camt);
        require(err == 0, "redeem failed");
        uint b1 = IERC20(WHT).balanceOf(address(this));
        return b1.sub(b0);
    }

    function _redeemCTokenTransfer(address ctoken, address token, address to, uint camt) private returns (uint)  {
        uint amt = _redeemCToken(ctoken, token, camt);
        // console.log("redeem amt: %d", camt, amt);
        if (amt > 0) {
            TransferHelper.safeTransfer(token, to, amt);
        }
        return amt;
    }

    function _redeemCETHTransfer(address to, uint camt) private returns (uint) {
        uint amt = _redeemCEth(camt);
        if (amt > 0) {
            TransferHelper.safeTransferETH(to, amt);
        }
        return amt;
    }

    // tokenA tokenB 閮芥槸 token amount閮芥槸 token 鐨?amount
    // 浠?ctoken redeem token 鍙兘浼氬け璐?棰濆害涓嶈冻), 鍥犳, 
    // 鍦ㄨ皟鐢ㄤ箣鍓? 鍓嶇蹇呴』鏍￠獙鍊熻捶姹犱綑棰濇槸鍚﹁冻澶燂紒锛侊紒
    function removeLiquidityUnderlying(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = pairFor(tokenA, tokenB);
        // 纭繚鍙湁owner鍙互绉婚櫎娴佸姩鎬?
        // require(IDeBankPair(pair).ownerAmountOf(to) >= liquidity, "not owner or not enough");

        IDeBankPair(pair).transferFrom(msg.sender, pair, liquidity);
        LiquidityLocalVars memory vars;
        {
            vars.tokenA = tokenA;
            vars.tokenB = tokenB;
            //  鍏堟妸 ctoken 鍙戦€佺粰 router
            (uint camount0, uint camount1) = IDeBankPair(pair).burn(address(this));
            (address token0,) = IDeBankFactory(factory).sortTokens(vars.tokenA, vars.tokenB);
            (vars.camountA, vars.camountB) = tokenA == token0 ? (camount0, camount1) : (camount1, camount0);
        }
        // console.log("camountA: %d camountB: %d", vars.camountA, vars.camountB);
        amountA = _redeemCTokenTransfer(_getCtoken(tokenA), tokenA, to, vars.camountA);
        amountB = _redeemCTokenTransfer(_getCtoken(tokenB), tokenB, to, vars.camountB);

        // console.log("amountA: %d amountB: %d", amountA, amountB);
        // TransferHelper.safeTransfer(tokenA, to, amountA);
        // TransferHelper.safeTransfer(tokenB, to, amountB);
        // address ctokenB = _getCtoken(tokenB);
        // ICToken(ctokenA).redeem(camountA);
        // ICToken(ctokenB).redeem(camountB);

        require(amountA >= amountAMin, 'RemoveLiquidityUnderlying: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'RemoveLiquidityUnderlying: INSUFFICIENT_B_AMOUNT');
    }

    // 鍦ㄨ皟鐢ㄤ箣鍓? 鍓嶇蹇呴』鏍￠獙鍊熻捶姹犱綑棰濇槸鍚﹁冻澶燂紒锛侊紒
    function removeLiquidityETHUnderlying(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountToken, uint amountETH) {
        LiquidityLocalVars memory vars;
        vars.ctokenA = _getCtoken(token);
        vars.rateA = _cTokenExchangeRate(vars.ctokenA);
        vars.rateEth = _cTokenExchangeRate(cWHT);
        uint camountTokenMin = _amount2CAmount(amountTokenMin, vars.rateA);
        uint camountETHMin = _amount2CAmount(amountETHMin, vars.rateEth);
        uint amountCToken;
        uint amountCETH;
        
        (amountCToken, amountCETH) = removeLiquidity(
            vars.ctokenA,
            cWHT,
            liquidity,
            camountTokenMin,
            camountETHMin,
            address(this),
            deadline
        );
        
        amountToken = _redeemCTokenTransfer(vars.ctokenA, token, to, amountCToken);
        // TransferHelper.safeTransfer(token, to, amountToken);
        // IWHT(WHT).withdraw(amountETH);
        amountETH = _redeemCETHTransfer(to, amountCETH);
        // to.transfer(amountETH);
        // TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB) {
        address pair = pairFor(tokenA, tokenB);
        uint value = approveMax ? uint(- 1) : liquidity;
        IDeBankPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityETHUnderlyingWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH) {
        address pair = pairFor(token, WHT);
        uint value = approveMax ? uint(- 1) : liquidity;
        IDeBankPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETHUnderlying(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    // function removeLiquidityETHSupportingFeeOnTransferTokens(
    //     address token,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline
    // ) public ensure(deadline) returns (uint amountETH) {
    //     (, amountETH) = removeLiquidity(
    //         token,
    //         WHT,
    //         liquidity,
    //         amountTokenMin,
    //         amountETHMin,
    //         address(this),
    //         deadline
    //     );
    //     TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
    //     IWHT(WHT).withdraw(amountETH);
    //     TransferHelper.safeTransferETH(to, amountETH);
    // }

    // function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    //     address token,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline,
    //     bool approveMax, uint8 v, bytes32 r, bytes32 s
    // ) external returns (uint amountETH) {
    //     address pair = pairFor(token, WHT);
    //     uint value = approveMax ? uint(- 1) : liquidity;
    //     IDeBankPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    //     amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
    //         token, liquidity, amountTokenMin, amountETHMin, to, deadline
    //     );
    // }

    // 鍏戞崲鎵嬬画璐? 涓嶆敹鎵嬬画璐?
    function _swapFee(address pair, uint feeIn, address feeTo) internal returns (uint feeOut) {
        (uint reserve0, uint reserve1, ) = IDeBankPair(pair).getReserves();
        feeOut = feeIn.mul(reserve1).div(reserve0.add(feeIn));
        IDeBankPair(pair).swapNoFee(0, feeOut, feeTo, feeOut);
    }

    // 灏嗘敹鍒扮殑鎵嬬画璐?token 杞崲涓?anchorToken
    // input 涓?token
    // swap鍚庡緱鍒扮殑鏄?canchorToken, cUSDT
    function _swapToCAnchorToken(address input, address pair, address anchorToken) internal returns (uint fee) {
        address feeTo = IDeBankFactory(factory).feeTo();
        require(feeTo != address(0), "feeTo is zero");

        uint amountIn = IERC20(_getCtoken(input)).balanceOf(pair);    // 杈撳叆杞叆
        uint feeIn = IDeBankPair(pair).getFee(amountIn);
        // console.log("amountIn: %d  feeIn: %d", amountIn, feeIn);

        if (input == anchorToken) {
            // 鐩存帴鏀?
            fee = feeIn;
            // feeTotal = feeTotal.add(feeIn);
        } else {
            // 鍏戞崲鎴?anchorToken
            // uint fee = _swapToCAnchorToken(input, amountIn);
            for (uint i; i < quoteTokens.length; i ++) {
                address token = quoteTokens[i];
                address tPair = IDeBankFactory(factory).getPair(input, token);

                // console.log("_swapToCAnchorToken: input=%s token=%s pair=%s", input, token, tPair);
                if (tPair != address(0)) {
                    if (token == anchorToken) {
                        // 鍏戞崲鎴愬姛
                        IERC20(tPair).transfer(tPair, feeIn);
                        fee = _swapFee(tPair, feeIn, feeTo);
                    } else {
                        // 闇€瑕佷袱姝ュ厬鎹?
                        // 绗竴姝? 鍏戞崲涓轰腑闂村竵绉?渚嬪ht husd btc
                        address pair2 = IDeBankFactory(factory).getPair(token, anchorToken);
                        require(pair2 != address(0), "quote coin has no pair to anchorToken");
                        IERC20(tPair).transfer(tPair, feeIn);
                        uint fee1 = _swapFee(tPair, feeIn, pair2);
                        // 绗簩姝?
                        fee = _swapFee(pair2, fee1, feeTo);
                    }
                    break;
                }
            }
        }

        // console.log("_swapToCAnchorToken: input: %s  fee: %d  ", input, fee);
        // IERC20(anchorToken).transfer(feeTo, fee);
        return fee;
    }

    function _updatePairFee(uint fee) private {
        // 鏇存柊鎵€鏈変氦鏄撳鐨勬墜缁垂
        if (currentBlock == block.number) {
            allPairFee += fee;
        } else {
            //
            allPairFeeLastBlock = allPairFee;
            allPairFee = fee;
            currentBlock = block.number;
        }
    }

    // **** SWAP ****
    // amounts 涓?ctoken 鐨?amount
    // path 涓殑 token 鍧囦负 token, 璋冪敤鍓嶈杞崲锛侊紒锛?
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        // uint feeTotal;  // by anchorToken
        address anchorToken = IDeBankFactory(factory).anchorToken();
        // address[] memory path = _cpath2path(cpath);

        // console.log("_swap ....");
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = IDeBankFactory(factory).sortTokens(input, output);
            address pair = IDeBankFactory(factory).getPair(path[i], path[i + 1]);
            // address feeTo = IDeBankFactory(factory).feeTo();
            // uint feeRate = IDeBankPair(pair).feeRate();
            uint amountOut = amounts[i + 1];
            // uint amountIn = IERC20(pair).balanceOf(pair);    // 杈撳叆杞叆
            // uint feeIn = IDeBankPair(pair).getFee(amountIn);

            // feeTotal = feeTotal.add();
            // if (feeTotal > 0) {
            //     // 鍒嗛厤LP鎵嬬画璐瑰鍔?
            // }

            if (swapMining != address(0)) {
                // 浜ゆ槗鎸栫熆
                ISwapMining(swapMining).swap(msg.sender, input, output, amountOut);
            }
            
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? pairFor(output, path[i + 2]) : _to;
            if (feeAlloc == 1) {
                // 鏀舵墜缁垂, 骞跺皢鎵嬬画璐瑰厬鎹负 canchorToken(cUSDT)
                uint fee = _swapToCAnchorToken(input, pair, anchorToken);
                if (fee > 0) {
                    _updatePairFee(fee);
                }

                IDeBankPair(pairFor(input, output)).swapNoFee(
                    amount0Out, amount1Out, to, fee
                );
            } else {
                IDeBankPair(pairFor(input, output)).swap(
                    amount0Out, amount1Out, to, new bytes(0)
                );
            }
        }
    }

    function _path2cpath(address[] memory path) private view returns (address[] memory) {
        address[] memory cpath = new address[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            cpath[i] = _getCtoken(path[i]);
        }
        return cpath;
    }

    function _cpath2path(address[] memory cpath) private view returns (address[] memory) {
        address[] memory path = new address[](cpath.length);
        for (uint i = 0; i < cpath.length; i ++) {
            path[i] = _getTokenByCtoken(cpath[i]);
        }
        return path;
    }

    // amount token 鍧囦负 ctoken
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata cpath,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        // console.log('swapExactTokensForTokens ....');
        address[] memory path = _cpath2path(cpath);
        amounts = IDeBankFactory(factory).getAmountsOut(amountIn, path, to);
        // console.log(amounts[0], amounts[1]);
        require(amounts[amounts.length - 1] >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        TransferHelper.safeTransferFrom(cpath[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    // amount token 鍧囦负 ctoken
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata cpath,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        // console.log('swapTokensForExactTokens ....');
        address[] memory path = _cpath2path(cpath);
        amounts = IDeBankFactory(factory).getAmountsIn(amountOut, path, to);
        require(amounts[0] <= amountInMax, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        TransferHelper.safeTransferFrom(cpath[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }


    function _swapExactTokensForTokensUnderlying(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        uint deadline,
        bool ethIn,
        bool ethOut
    ) private ensure(deadline) returns (uint[] memory amounts) {
        // console.log('_swapExactTokensForTokensUnderlying ....');
        address[] memory cpath = _path2cpath(path);
        SwapLocalVars memory vars;
        vars.amountIn = amountIn;
        vars.rate0 = _cTokenExchangeRate(cpath[0]);
        vars.rate1 = _cTokenExchangeRate(cpath[0]);
        uint camtIn = _amount2CAmount(amountIn, vars.rate0);
        uint[] memory camounts = IDeBankFactory(factory).getAmountsOut(camtIn, path, to);
        // console.log(camounts[0], camounts[1]);
        vars.amountOut = _camount2Amount(camounts[camounts.length - 1], vars.rate1);
        require(vars.amountOut >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        if (ethIn) {
            _mintTransferEth(pairFor(path[0], path[1]), amountIn);
        } else {
            _mintTransferCToken(path[0], cpath[0], pairFor(path[0], path[1]), vars.amountIn);
        }

        // TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        // 鍏堝皢 ctoken 杞粰 router
        _swap(camounts, path, address(this));
        uint idx = path.length - 1;
        if (ethOut) {
            _redeemCETHTransfer(to, camounts[idx]);
        } else {
            _redeemCTokenTransfer(cpath[idx], path[idx], to, camounts[idx]);
        }

        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[idx] = vars.amountOut;
    }

    // amount token 鍧囦负 token
    // 璋冪敤鑰呴渶瑕侀獙璇佸€熻捶姹犱腑鐨?path[path.length-1] 鐨勮祫閲戣冻澶燂紒锛侊紒
    function swapExactTokensForTokensUnderlying(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        // console.log('swapExactTokensForTokensUnderlying ....');
        amounts = _swapExactTokensForTokensUnderlying(amountIn, amountOutMin, path, to, deadline, false, false);
        // address[] memory cpath = _path2cpath(path);
        // uint rate0 = _cTokenExchangeRate(cpath[0]);
        // uint rate1 = _cTokenExchangeRate(cpath[0]);
        // uint camtIn = _amount2CAmount(amountIn, rate0);
        // uint[] memory camounts = IDeBankFactory(factory).getAmountsOut(camtIn, path);
        // console.log(camounts[0], camounts[1]);
        // uint amountOut = _camount2Amount(camounts[camounts.length - 1], rate1);
        // require(amountOut >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // // _safeTransferCtoken(
        // //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // // );
        // _mintTransferCToken(path[0], cpath[0], pairFor(path[0], path[1]), amountIn);
        // // TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        // _swap(camounts, path, to);
        // uint idx = path.length - 1;
        // _redeemCTokenTransfer(cpath[idx], path[idx], to, camounts[idx]);

        // amounts = new uint[](path.length);
        // amounts[0] = amountIn;
        // amounts[idx] = amountOut;
    }

    struct SwapLocalVars {
        uint rate0;
        uint rate1;
        uint amountIn;
        uint amountOut;
    }

    function _swapTokensForExactTokensUnderlying(
        uint amountOut,
        uint amountInMax,
        address[] memory path,
        address to,
        uint deadline,
        bool ethIn,
        bool ethOut
    ) private ensure(deadline) returns (uint[] memory amounts) {
        // console.log('_swapTokensForExactTokensUnderlying ....');
        address[] memory cpath = _path2cpath(path);
        SwapLocalVars memory vars;

        vars.rate0 = _cTokenExchangeRate(cpath[0]);
        vars.rate1 = _cTokenExchangeRate(cpath[path.length-1]);
        uint camtOut = _amount2CAmount(amountOut, vars.rate1);
        uint[] memory camounts = IDeBankFactory(factory).getAmountsIn(camtOut, path, to);
        // console.log("camounts:", camounts[0], camounts[1], camtOut);
        
        vars.amountIn = _camount2Amount(camounts[0], vars.rate0);
        // 涓婁竴姝ヤ腑鑸嶅幓鐨?1
        vars.amountIn = vars.amountIn.add(1);
        // console.log("amountIn:", vars.amountIn);
        require(vars.amountIn <= amountInMax, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        if (ethIn) {
            _mintTransferEth(pairFor(path[0], path[1]), vars.amountIn);
        } else {
            _mintTransferCToken(path[0], cpath[0], pairFor(path[0], path[1]), vars.amountIn);
        }
        // TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        // 鍏堣浆缁?router, 鍐嶇敱 router redeem 鍚? 杞粰 to
        _swap(camounts, path, address(this));
        uint idx = path.length - 1;
        if (ethOut) {
            _redeemCETHTransfer(to, camounts[idx]);
        } else {
            _redeemCTokenTransfer(cpath[idx], path[idx], to, camounts[idx]);
        }

        amounts = new uint[](path.length);
        amounts[0] = vars.amountIn;
        amounts[idx] = amountOut;
    }

    // amount token 鍧囦负 ctoken
    function swapTokensForExactTokensUnderlying(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        // console.log('swapTokensForExactTokensUnderlying ....');
        amounts = _swapTokensForExactTokensUnderlying(amountOut, amountInMax, path, to, deadline, false, false);
        // address[] memory cpath = _path2cpath(path);
        // uint rate0 = _cTokenExchangeRate(cpath[0]);
        // uint rate1 = _cTokenExchangeRate(cpath[0]);
        // uint camtOut = _amount2CAmount(amountOut, rate1);
        // uint[] memory camounts = IDeBankFactory(factory).getAmountsIn(camtOut, path);
        
        // uint amountIn = _camount2Amount(camounts[0], rate0);
        // require(amountIn <= amountInMax, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // // _safeTransferCtoken(
        // //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // // );
        // _mintTransferCToken(path[0], cpath[0], pairFor(path[0], path[1]), amountIn);
        // // TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        // _swap(camounts, path, to);
        // uint idx = path.length - 1;
        // _redeemCTokenTransfer(cpath[idx], path[idx], to, camounts[idx]);

        // amounts = new uint[](path.length);
        // amounts[0] = amountIn;
        // amounts[idx] = amountOut;
    }

    function swapExactETHForTokensUnderlying(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // console.log('swapExactETHForTokensUnderlying ....');
        require(path[0] == WHT, 'Router: INVALID_PATH');
        amounts = _swapExactTokensForTokensUnderlying(msg.value, amountOutMin, path, to, deadline, true, false);
        // amounts = IDeBankFactory(factory).getAmountsOut(msg.value, path);
        // require(amounts[amounts.length - 1] >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // IWHT(WHT).deposit.value(amounts[0])();
        // assert(IWHT(WHT).transfer(pairFor(path[0], path[1]), amounts[0]));
        // _swap(amounts, path, to);
    }

    function swapTokensForExactETHUnderlying(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // console.log('swapTokensForExactETH ....');
        require(path[path.length - 1] == WHT, 'Router: INVALID_PATH');
        amounts = _swapTokensForExactTokensUnderlying(amountOut, amountInMax, path, to, deadline, false, true);
        // amounts = IDeBankFactory(factory).getAmountsIn(amountOut, path);
        // require(amounts[0] <= amountInMax, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        // _swap(amounts, path, address(this));
        // IWHT(WHT).withdraw(amounts[amounts.length - 1]);
        // TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETHUnderlying(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // console.log('swapExactTokensForETHUnderlying ....');
        require(path[path.length - 1] == WHT, 'Router: INVALID_PATH');
        amounts = _swapExactTokensForTokensUnderlying(amountIn, amountOutMin, path, to, deadline, false, true);
        // amounts = IDeBankFactory(factory).getAmountsOut(amountIn, path);
        // require(amounts[amounts.length - 1] >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        // _swap(amounts, path, address(this));
        // IWHT(WHT).withdraw(amounts[amounts.length - 1]);
        // TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokensUnderlying(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // console.log('swapETHForExactTokensUnderlying ....');
        require(path[0] == WHT, 'Router: INVALID_PATH');
        amounts = _swapTokensForExactTokensUnderlying(amountOut, msg.value, path, to, deadline, true, false);
        // amounts = IDeBankFactory(factory).getAmountsIn(amountOut, path);
        // require(amounts[0] <= msg.value, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // IWHT(WHT).deposit{value : amounts[0]}();
        // assert(IWHT(WHT).transfer(pairFor(path[0], path[1]), amounts[0]));
        // _swap(amounts, path, to);
        // // refund dust eth, if any
        // if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    function adminTransfer(address token, address to, uint amt) external onlyOwner {
        if (token == address(0)) {
          TransferHelper.safeTransferETH(to, amt);
        } else {
          TransferHelper.safeTransferFrom(token, address(this), to, amt);
        }
    }
    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    // function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal {
    //     for (uint i; i < path.length - 1; i++) {
    //         (address input, address output) = (path[i], path[i + 1]);
    //         (address token0,) = IDeBankFactory(factory).sortTokens(input, output);
    //         IDeBankPair pair = IDeBankPair(pairFor(input, output));
    //         uint amountInput;
    //         uint amountOutput;
    //         {// scope to avoid stack too deep errors
    //             (uint reserve0, uint reserve1,) = pair.getReserves();
    //             (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    //             amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
    //             amountOutput = IDeBankFactory(factory).getAmountOut(amountInput, reserveInput, reserveOutput);
    //         }
    //         if (swapMining != address(0)) {
    //             ISwapMining(swapMining).swap(msg.sender, input, output, amountOutput);
    //         }
    //         (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
    //         address to = i < path.length - 2 ? pairFor(output, path[i + 2]) : _to;
    //         pair.swap(amount0Out, amount1Out, to, new bytes(0));
    //     }
    // }

    // function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external ensure(deadline) {
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, pairFor(path[0], path[1]), amountIn
    //     );
    //     uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
    //     _swapSupportingFeeOnTransferTokens(path, to);
    //     require(
    //         IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
    //         'Router: INSUFFICIENT_OUTPUT_AMOUNT'
    //     );
    // }

    // function swapExactETHForTokensSupportingFeeOnTransferTokens(
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // )
    // external
    // payable
    // ensure(deadline)
    // {
    //     require(path[0] == WHT, 'Router: INVALID_PATH');
    //     uint amountIn = msg.value;
    //     IWHT(WHT).deposit.value(amountIn)();
    //     assert(IWHT(WHT).transfer(pairFor(path[0], path[1]), amountIn));
    //     uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
    //     _swapSupportingFeeOnTransferTokens(path, to);
    //     require(
    //         IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
    //         'Router: INSUFFICIENT_OUTPUT_AMOUNT'
    //     );
    // }

    // function swapExactTokensForETHSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // )
    // external
    // ensure(deadline)
    // {
    //     require(path[path.length - 1] == WHT, 'Router: INVALID_PATH');
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, pairFor(path[0], path[1]), amountIn
    //     );
    //     _swapSupportingFeeOnTransferTokens(path, address(this));
    //     uint amountOut = IERC20(WHT).balanceOf(address(this));
    //     require(amountOut >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
    //     IWHT(WHT).withdraw(amountOut);
    //     TransferHelper.safeTransferETH(to, amountOut);
    // }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public view returns (uint256 amountB) {
        return IDeBankFactory(factory).quote(amountA, reserveA, reserveB);
    }

    // function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view returns (uint256 amountOut){
    //     return IDeBankFactory(factory).getAmountOut(amountIn, reserveIn, reserveOut);
    // }

    // function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public view returns (uint256 amountIn){
    //     return IDeBankFactory(factory).getAmountIn(amountOut, reserveIn, reserveOut);
    // }

    function getAmountsOut(uint256 amountIn, address[] memory path, address to) public view returns (uint256[] memory amounts){
        return IDeBankFactory(factory).getAmountsOut(amountIn, path, to);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path, address to) public view returns (uint256[] memory amounts){
        return IDeBankFactory(factory).getAmountsIn(amountOut, path, to);
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
        (bool success,) = to.call.value(value)(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}
