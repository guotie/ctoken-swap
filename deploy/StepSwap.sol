// Sources flattened with hardhat v2.2.1 https://hardhat.org

// File contracts/swap/aggressive2/library/SafeMath.sol

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
pragma solidity >=0.6.12;

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


// File contracts/swap/aggressive2/library/DataTypes.sol


pragma experimental ABIEncoderV2;

/**
 * @title DataTypes library
 * @author ebankex
 * @notice Provides data types and functions to perform step swap calculations
 * @dev DataTypes are used for aggressive swap within multi swap exchanges.
 **/

library DataTypes {
    // 步骤执行的动作类型
    uint256 public constant STEP_DEPOSIT_ETH           = 0x0000000001; // prettier-ignore
    uint256 public constant STEP_WITHDRAW_WETH         = 0x0000000002; // prettier-ignore
    uint256 public constant STEP_COMPOUND_MINT_CTOKEN  = 0x0000000003; // prettier-ignore
    uint256 public constant STEP_COMPOUND_MINT_CETH    = 0x0000000004; // prettier-ignore
    uint256 public constant STEP_COMPOUND_REDEEM_TOKEN = 0x0000000005; // prettier-ignore
    // uint256 public constant STEP_COMPOUND_REDEEM_ETH   = 0x0000000006; // prettier-ignore
    uint256 public constant STEP_AAVE_DEPOSIT_ATOKEN   = 0x0000000007; // prettier-ignore
    uint256 public constant STEP_AAVE_DEPOSIT_WETH     = 0x0000000008; // prettier-ignore
    uint256 public constant STEP_AAVE_WITHDRAW_TOKEN   = 0x0000000009; // prettier-ignore
    uint256 public constant STEP_AAVE_WITHDRAW_ETH     = 0x000000000a; // prettier-ignore

    uint256 public constant STEP_UNISWAP_PAIR_SWAP              = 0x0000000100; // prettier-ignore
    uint256 public constant STEP_UNISWAP_ROUTER_TOKENS_TOKENS   = 0x0000000101; // prettier-ignore
    uint256 public constant STEP_UNISWAP_ROUTER_ETH_TOKENS      = 0x0000000102; // prettier-ignore
    uint256 public constant STEP_UNISWAP_ROUTER_TOKENS_ETH      = 0x0000000103; // prettier-ignore
    uint256 public constant STEP_EBANK_ROUTER_CTOKENS_CTOKENS   = 0x0000000104;  // prettier-ignore
    uint256 public constant STEP_EBANK_ROUTER_TOKENS_TOKENS     = 0x0000000105;  // prettier-ignore
    uint256 public constant STEP_EBANK_ROUTER_ETH_TOKENS        = 0x0000000106;  // prettier-ignore
    uint256 public constant STEP_EBANK_ROUTER_TOKENS_ETH        = 0x0000000107;  // prettier-ignore

    struct SwapFlagMap {
        // bit 0-63: flag token in/out, 64 bit
        // bit 64-71 parts, 8 bit
        // bit 72-79 max main part, 8 bit
        // bit 80-81 complex level, 2 bit
        // bit 82    allow partial fill
        // bit 83    allow burnChi
        uint256 data;
    }

    /// @dev 询价 计算最佳兑换路径的入参
    struct QuoteParams {
        address to;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 tokenPriceGWei;
        address fromAddress;
        address dstReceiver;
        address[] midTokens;  // should always be token
        SwapFlagMap flag;
    }

    struct UniswapRouterParam {
        uint256 amount;
        address contractAddr;
        // address to;
        address[] path;
    }

    struct CompoundRedeemParam {
        uint256 amount;
        // address to;
        address ctoken;
    }

    struct UniswapPairParam {
        uint256 amount;
        // address to;
        address[] pairs;
    }

    // struct 
    struct StepExecuteParams {
        uint256 flag;           // step execute flag 指示用哪种步骤去执行
        // bytes[] data;           /// decode by executor
        bytes data;
    }

    /// @dev 兑换 入参
    struct SwapParams {
        // address to;
        // address tokenIn;
        // address tokenOut;
        // uint256 amountIn;
        // uint256 amountOut;
        // uint256 tokenPriceGWei;
        // address fromAddress;
        // address dstReceiver;
        // address[] midTokens;  // should always be token
        // SwapFlagMap flag;
        SwapFlagMap flag;
        uint256 minAmt;
        StepExecuteParams[] steps;
    }

    /// @dev Exchange 交易所合约地址及交易所类型
    struct Exchange {
        uint exFlag;
        address contractAddr;
    }


    /// @dev 计算各个交易所的每个parts的return
    struct SwapDistributes {
        bool        ctokenIn;     // 卖出的币是否是 ctoken
        bool        ctokenOut;    // 买到的币是否是 ctoken
        address     to;           // 交易者地址
        address     tokenIn;
        address     tokenOut;
        uint256     parts;        // 交易量拆分为多少份
        uint256     rateIn;       // token in exchange rate
        uint256     rateOut;      // token out exchange rate
        uint[]      amounts;      // split into parts
        uint[]      cAmounts;     // mint to ctoken amounts
        address[]   midTokens;    // middle token list
        address[]   midCTokens;   // middle ctoken list
        address[][] paths;        // 由 midTokens 和 复杂度计算得到的所有 path 列表
        address[][] cpaths;       // 由 midCTokens 和 复杂度计算得到的所有 cpath 列表
        
        uint[]      gases;          // gas 费用估算
        uint[]      pathIdx;        // 使用的 path 序号
        uint[][]    distributes;    // 一级为交易路径, 二级为该交易路径的所有parts对应的return
        int256[][]  netDistributes; // distributes - gases
        Exchange[]  exchanges;
    }
}


// File contracts/swap/aggressive2/library/SwapFlag.sol


library SwapFlag {
    uint256 public constant FLAG_TOKEN_IN_ETH          = 0x0000000001; // prettier-ignore
    uint256 public constant FLAG_TOKEN_IN_TOKEN        = 0x0000000002; // prettier-ignore
    uint256 public constant FLAG_TOKEN_IN_CTOKEN       = 0x0000000004; // prettier-ignore
    uint256 public constant FLAG_TOKEN_OUT_ETH         = 0x0000000008; // prettier-ignore
    uint256 public constant FLAG_TOKEN_OUT_TOKEN       = 0x0000000010; // prettier-ignore
    uint256 public constant FLAG_TOKEN_OUT_CTOKEN      = 0x0000000020; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_OUT_CETH        = 0x0000000040; // prettier-ignore

    uint256 internal constant _MASK_PARTS           = 0x0000ff0000000000000000; // prettier-ignore
    uint256 internal constant _MASK_MAIN_ROUTES     = 0x00ff000000000000000000; // prettier-ignore
    uint256 internal constant _MASK_COMPLEX_LEVEL   = 0x0300000000000000000000; // prettier-ignore
    uint256 internal constant _MASK_PARTIAL_FILL    = 0x0400000000000000000000; // prettier-ignore
    uint256 internal constant _MASK_BURN_CHI        = 0x0800000000000000000000; // prettier-ignore

    uint256 internal constant _SHIFT_PARTS          = 64; // prettier-ignore
    uint256 internal constant _SHIFT_MAIN_ROUTES    = 72; // prettier-ignore
    uint256 internal constant _SHIFT_COMPLEX_LEVEL  = 80; // prettier-ignore

    /// @dev if token in is ctoken
    function tokenInIsCToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_IN_CTOKEN) != 0;
    }

    /// @dev if token out is ctoken
    function tokenOutIsCToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_OUT_CTOKEN) != 0;
    }


    /// @dev get param split parts
    function getParts(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_PARTS) >> _SHIFT_PARTS;
    }

    /// @dev get param main routes max port
    function getMainRoutes(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_MAIN_ROUTES) >> _SHIFT_MAIN_ROUTES;
    }

    /// @dev get param complex level
    function getComplexLevel(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_COMPLEX_LEVEL) >> _SHIFT_COMPLEX_LEVEL;
    }

    /// @dev get param allow partial fill
    function allowPartialFill(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & _MASK_PARTIAL_FILL) != 0;
    }

    /// @dev get param burn CHI
    function burnCHI(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & _MASK_BURN_CHI) != 0;
    }
}


// File contracts/swap/aggressive2/library/PathFinder.sol



/// @dev 寻找最优路径

library PathFinder {
    function findBestDistribution(
        uint256 s,                // parts
        int256[][] memory amounts // exchangesReturns
    )
        public
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
}


// File contracts/swap/aggressive2/interface/IERC20.sol

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


// File contracts/swap/aggressive2/interface/IWETH.sol

abstract contract IWETH is IERC20 {
    function deposit() external virtual payable;

    function withdraw(uint256 amount) external virtual;
}


// File contracts/swap/aggressive2/interface/ICToken.sol

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


// File contracts/swap/aggressive2/interface/ILHT.sol

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


interface ILHT {

    function mint() external returns (uint);
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


// File contracts/swap/aggressive2/interface/ICTokenFactory.sol



interface ICTokenFactory {
    // 根据 token 地址获取对应的 ctoken 地址
    function getCTokenAddressPure(address token) external view returns (address);

    // 根据 ctoken 地址获取对应的 token 地址
    function getTokenAddress(address cToken) external view returns (address);
}


// File contracts/swap/aggressive2/interface/IFactory.sol

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


interface IFactory {

    function router() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}


// File contracts/swap/aggressive2/Ownable.sol



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
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
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
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


// File contracts/swap/aggressive2/interface/IRouter.sol

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


interface IRouter {
    function factory() external view returns (address);
    
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline)
        external
        payable
        returns (uint[] memory amounts);
}


// File contracts/swap/aggressive2/interface/IDeBankRouter.sol

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


interface IDeBankRouter {
    /// @dev getAmountsOut 对比 IRouter 增加了 to 参数, 可以根据 to 来决定手续费率
    function getAmountsOut(uint256 amountIn, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline)
        external
        payable
        returns (uint[] memory amounts);
}


// File contracts/swap/aggressive2/interface/ICurve.sol

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


interface ICurve {
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function get_dy_underlying(int128 i, int128 j, uint256 dx) external view returns (uint256);

    
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}


// File contracts/swap/aggressive2/Exchanges.sol


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


// File contracts/swap/aggressive2/StepSwap.sol


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
    ILHT public ceth;  // compound eth
    ICTokenFactory public ctokenFactory;
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

        for (uint i = 0; i < amounts.length; i ++) {
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

    /// @dev 计算uniswap类似的交易所的 return
    function _calcUnoswapExchangeReturn(
                DataTypes.Exchange memory ex,
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint tokenPriceGWei
            ) internal view returns (uint) {
        uint gas = 106000;  // uniswap v2

        for (uint i = 0; i < sd.paths.length; i ++) {
            address[] memory path = sd.paths[i];
            uint[] memory amts;

            // 是否是 ebankex 及 tokenIn, tokenOut 是否是 ctoken
            if (sd.ctokenIn == false) {
                amts = Exchanges.calcDistributes(ex, path, sd.amounts, sd.to);
                if (sd.ctokenOut == true) {
                    // 转换为 ctoken
                    for (uint j = 0; j < sd.amounts.length; j ++) {
                        amts[j] = amts[j].mul(1e18).div(sd.rateOut);
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
                    for (uint j = 0; j < sd.amounts.length; j ++) {
                        amts[j] = amts[j].mul(1e18).div(sd.rateOut);
                    }
                    // deposit token 193404
                    // deposit eth   160537
                    gas += 193404;
                }
            }
            sd.pathIdx[idx + i] = i;
            sd.distributes[idx + i] = amts;
            sd.exchanges[idx + i] = ex;
            sd.netDistributes[idx + i] = _deductGasFee(amts, gas, tokenPriceGWei);
        }

        sd.gases[idx] = gas;
    }

    /// @dev ebankex 兑换数量
    function _calcEbankExchangeReturn(
                DataTypes.Exchange memory ex,
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint tokenPriceGWei
            ) internal view returns (uint)  {
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
                for (uint j = 0; j < sd.amounts.length; j ++) {
                    amts[j] = amts[j].mul(sd.rateOut).div(1e18);
                }
                // deposit token 193404
                // deposit eth   160537
                gas += 203573;
            }
        
            sd.pathIdx[idx + i] = i;
            sd.distributes[idx + i] = amts;
            sd.exchanges[idx + i] = ex;
            sd.netDistributes[idx + i] = _deductGasFee(amts, gas, tokenPriceGWei);
        }

        sd.gases[idx] = gas;
    }

    /// @dev _makeSwapDistributes 构造参数
    function _makeSwapDistributes(
                DataTypes.QuoteParams calldata args,
                uint distributeCounts
            )
            internal
            view
            returns (DataTypes.SwapDistributes memory swapDistributes) {
        swapDistributes.to = args.to;
        swapDistributes.tokenIn = args.tokenIn;
        swapDistributes.tokenOut = args.tokenOut;
        swapDistributes.ctokenIn = args.flag.tokenInIsCToken();
        swapDistributes.ctokenOut = args.flag.tokenOutIsCToken();
        uint parts = args.flag.getParts();
        swapDistributes.parts = parts;

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

        swapDistributes.gases          = new uint[]  (distributeCounts); // prettier-ignore
        swapDistributes.pathIdx        = new uint[]  (distributeCounts); // prettier-ignore
        swapDistributes.distributes    = new uint[][](distributeCounts); // prettier-ignore
        swapDistributes.netDistributes = new int[][](distributeCounts);  // prettier-ignore
        swapDistributes.exchanges      = new DataTypes.Exchange[](distributeCounts);
        
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
    function getExpectedReturnWithGas(
                DataTypes.QuoteParams calldata args
            )
            external
            view
            returns (DataTypes.SwapParams memory) {
        DataTypes.SwapFlagMap memory flag = args.flag;
        require(flag.tokenInIsCToken() == flag.tokenOutIsCToken(), "both token or ctoken"); // 输入输出必须同时为 token 或 ctoken

        // bool ctokenIn = flag.tokenInIsCToken();
        // bool ctokenOut = flag.tokenOutIsCToken();
        uint distributeCounts = calcExchangeRoutes(args.midTokens.length, args.flag.getComplexLevel());
        uint distributeIdx = 0;
        uint tokenPriceGWei = args.tokenPriceGWei;
        DataTypes.SwapDistributes memory swapDistributes = _makeSwapDistributes(args, distributeCounts);

        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange memory ex = exchanges[i];

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
        // todo desposit eth withdraw eth 的 gas 费用

        // 根据 dist 构建交易步骤
        DataTypes.SwapParams memory params;
        params.flag = args.flag;
        _makeSwapSteps(args.amountIn, swapDistributes, params);
        return params;
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

        uint routes = 0;
        uint routeIdx = 0;
        for (uint i = 0; i < dists.length; i ++) {
            if (dists[i] > 0) {
                routes ++;
            }
        }

        bool allEbank = _allSwapByEBank(sd, dists);
        if (allEbank) {
            // 全部都是由 ebank
            // if (sd.ctokenIn != sd.ctokenOut) {
            //     // 如果全部由 ebank 兑换
            //     routes ++;
            // }
            return _buildEBankSteps(routes, amountIn, dists, sd, params);
        }

        if (sd.ctokenIn) {
            // redeem ctoken, mint token
            routes += 2;
        }
        DataTypes.StepExecuteParams[] memory stepArgs = new DataTypes.StepExecuteParams[](routes);

        if (sd.ctokenIn) {
            /*
            address ctokenIn = sd.cpaths[0][0];
            address ctokenOut = sd.cpaths[0][sd.cpaths[0].length-1];
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
            // (int256 lastUniswapIdx, int256 lastEbankIdx) = _getLastSwapIndex(sd, dists);
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
            */
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

    /// amt * part / totalParts
    function _partAmount(uint amt, uint part, uint totalParts) private pure returns (uint) {
        return amt.mul(part).div(totalParts);
    }

    function _getEBankContract() private view returns (address ebank) {
        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange memory ex = exchanges[i];
            if (ex.exFlag == Exchanges.EXCHANGE_EBANK_EX && ex.contractAddr != address(0)) {
                ebank = ex.contractAddr;
                break;
            }
        }
        require(ebank != address(0), "not found ebank");
        return ebank;
    }

    function _buildUniswapLikeSteps(
                uint amt,
                uint idx,
                bool useRouter,
                DataTypes.SwapDistributes memory sd
            )
            private
            view
            returns (DataTypes.StepExecuteParams memory params) {
        if (useRouter) {
            _makeUniswapLikeRouteStep(amt, idx, sd);
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
                uint routes,
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
        params.steps = new DataTypes.StepExecuteParams[](routes);


        // if (sd.ctokenIn == sd.ctokenOut) {
            for (uint i = 0; i < dists.length; i ++) {
                if (dists[i] > 0) {
                    // swap
                    uint amt;
                    if (routeIdx == routes - 1) {
                        amt = remaining;
                    } else {
                        amt = _partAmount(amountIn, dists[i], parts);
                        remaining -= amt;
                    }
                    if (sd.ctokenIn) {
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
        // }
        // not allowed !!!
        // sd.ctokenIn != sd.ctokenOut
        // if (sd.ctokenIn) {
        //     // ctoken in, token out: swapExactTokensForTokens, redeem / redeemCETH
        //     for (uint i = 0; i < dists.length; i ++) {
        //         if (dists[i] > 0) {
        //             // swap
        //             uint amt;
        //             if (routeIdx == routes - 1) {
        //                 amt = remaining;
        //             } else {
        //                 amt = _partAmount(amountIn, dists[i], parts);
        //                 remaining -= amt;
        //             }
        //         }
        //         params.steps[routeIdx] = _makeEBankRouteStep(
        //                                     DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
        //                                     amt,
        //                                     sd.exchanges[i].contractAddr,
        //                                     sd.cpath[sd.pathIdx[i]]
        //                                 );
        //         routeIdx ++;
        //     }
        //     // redeem
        //     params.steps[routeIdx] =_makeCompoundRedeemStep(0, sd.tokenOut);
        // } else {
        //     // token in, ctoken out
        //     for (uint i = 0; i < dists.length; i ++) {
        //         if (dists[i] > 0) {
        //             // swap
        //             uint amt;
        //             if (routeIdx == routes - 1) {
        //                 amt = remaining;
        //             } else {
        //                 amt = _partAmount(amountIn, dists[i], parts);
        //                 remaining -= amt;
        //             }
        //         }
        //         uint flag;
        //         if (sd.tokenIn == address(0)) {
        //             // ht in
        //             flag = DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS;
        //         } else {
        //             flag = 
        //         }
        //         params.steps[routeIdx] = _makeEBankRouteStep(
        //                                     flag,
        //                                     amt,
        //                                     sd.exchanges[i].contractAddr,
        //                                     sd.cpath[sd.pathIdx[i]]
        //                                 );
        //     }
        // }
    }

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
        //     ctoken = ctokenFactory.getCTokenAddressPure(tokenOut);
        // }
        // eth 和 token 都是调用同一个方法 redeem, 且参数相同, 因此，使用同一个 flag
        step.flag = DataTypes.STEP_COMPOUND_REDEEM_TOKEN;
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
        // todo flag 根据 输入 token 输出 token 决定
        step.flag = sd.exchanges[idx].exFlag;

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

        step.flag = sd.exchanges[idx].exFlag;
        step.data = abi.encode(rp);
    }

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
                returns (bool) {
        for (uint i = 0; i < distributes.length; i ++) {
            if (distributes[i] > 0) {
                // 该 swap 不是 ebank
                if (Exchanges.isEBankExchange(sd.exchanges[i].exFlag) == false) {
                    return false;
                }
            }
        }

        return true;
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

    function setCETH(address _ceth) external onlyOwner {
        ceth = ILHT(_ceth);
    }

    function setCtokenFactory(address factory) external onlyOwner {
        ctokenFactory = ICTokenFactory(factory);
    }
}