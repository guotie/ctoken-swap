// Sources flattened with hardhat v2.2.1 https://hardhat.org

// File contracts/swap/orderbook/Ownable.sol

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
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

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


// File contracts/swap/orderbook/ReentrancyGuard.sol

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
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;


contract ReentrancyGuard {
    bool private _notEntered;

    constructor () internal {
        // Storing an initial non-zero value makes deployment a bit more
        // expensive, but in exchange the refund on every call to nonReentrant
        // will be lower in amount. Since refunds are capped to a percetange of
        // the total transaction's gas, it is best to keep them low in cases
        // like this one, to increase the likelihood of the full refund coming
        // into effect.
        _notEntered = true;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_notEntered, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _notEntered = false;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _notEntered = true;
    }
}


// File contracts/swap/orderbook/DataTypes.sol

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
pragma solidity 0.6.12;

library DataTypes {
    uint constant internal  SRC_IS_ETOKEN = 0x00001; // prettier-ignore
    uint constant internal DEST_IS_ETOKEN = 0x00002;
 
    struct TokenAmount {
        // uint isEToken;            // 鎸傚崟鍗栧嚭鐨勫竵鏄惁鏄?eToken
        address srcToken;
        address destToken;
        address srcEToken;             // srcToken 瀵瑰簲鐨?eToken
        address destEToken;            // destToken 瀵瑰簲鐨?eToken
        uint amountIn;                 // 鍒濆鎸傚崟鏁伴噺
        uint amountInMint;             // 濡傛灉 srcToken 涓嶆槸 eToken, mint 鎴愪负 etoken 鐨勬暟閲?
        uint fulfiled;                 // 宸茬粡鎴愪氦閮ㄥ垎, 鍗曚綅 etoken
        uint guaranteeAmountOut;       // 鏈€浣庡厬鎹㈠悗瑕佹眰寰楀埌鐨勬暟閲?
        // uint guaranteeAmountOutEToken; // 鏈€浣庡厬鎹㈠悗瑕佹眰寰楀埌鐨?etoken 鏁伴噺
    }

    struct OrderItem {
      uint orderId;
      uint pairAddrIdx;        // pairIdx | addrIdx
      uint pair;               // hash(srcToken, destToken)
      uint timestamp;          // 杩囨湡鏃堕棿 | 鎸傚崟鏃堕棿 
      uint flag;
      address owner;
      address to;              // 鍏戞崲寰楀埌鐨則oken鍙戦€佸湴鍧€ 鏈娇鐢?
      TokenAmount tokenAmt;
    }

    struct OBPairConfigMap {
      // bit 0-127 min amount
      // bit 128-191 maker fee rate
      // bit 192-255 taker fee rate
      uint256 data;
    }
}


// File contracts/swap/orderbook/OBPairConfig.sol

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
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
library OBPairConfig {
    uint constant internal MASK_FEE_MAKER  = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff; // prettier-ignore
    uint constant internal MASK_FEE_TAKER  = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000; // prettier-ignore
    uint constant internal FEE_DENOMINATOR = 10000;

    uint constant internal MAX_FEE_RATE = 1000; // 10%

    uint constant internal SHIFT_FEE_TAKER = 128;

    /**
    * @dev Gets the maker fee of order book pair
    * @param self The order book pair configuration
    * @return The maker fee + 1 if fee exist or else 0
    **/
    function feeMaker(DataTypes.OBPairConfigMap storage self) public view returns (uint256) {
        return (self.data & MASK_FEE_MAKER);
    }

    /**
    * @dev Gets the taker fee of order book pair
    * @param self The order book pair configuration
    * @return The taker fee + 1 if fee exist or else 0
    **/
    function feeTaker(DataTypes.OBPairConfigMap storage self) public view returns (uint256) {
        return ((self.data & MASK_FEE_TAKER) >> SHIFT_FEE_TAKER);
    }
    
    /**
    * @dev Sets the maker fee of order book pair
    * @param self The order book pair configuration
    * @param fee taker fee to set
    **/
    function setFeeMaker(DataTypes.OBPairConfigMap storage self, uint fee) public {
        require(fee < MAX_FEE_RATE, "maker fee invalid");
        self.data = (self.data & ~MASK_FEE_MAKER) | (fee+1);
    }

    /**
    * @dev Sets the maker fee of order book pair
    * @param self The order book pair configuration
    * @param fee maker fee to set
    **/
    function setFeeTaker(DataTypes.OBPairConfigMap storage self, uint fee) public {
        require(fee < MAX_FEE_RATE, "taker fee invalid");
        self.data = (self.data & ~MASK_FEE_TAKER) | ((fee+1) << SHIFT_FEE_TAKER);
    }
}


// File contracts/swap/orderbook/OBStorage.sol

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
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
// 瀛樺偍
contract OBStorage is Ownable {
    using OBPairConfig for DataTypes.OBPairConfigMap;

    uint private constant _PAIR_INDEX_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;   // 128 bit
    uint private constant _ADDR_INDEX_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   // 128 bit
    uint private constant _MARGIN_MASK     = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint private constant _EXPIRED_AT_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   // 128 bit
    uint private constant _ADDR_INDEX_OFFSET = 128;
    // uint private constant _EXPIRED_AT_OFFSET = 128;

    uint256 public constant DENOMINATOR = 10000;

    // // 璁＄畻浠锋牸鐨勪箻鏁?price = token0 * priceRatio / token1, such as 1e30
    // uint public priceRatio = 1e30; 

    uint public orderId;   // order Id 鑷

    // 鍏抽棴璁㈠崟钖勫姛鑳?
    bool    public closed; // prettier-ignore
    // address public router;
    address public wETH;
    address public cETH;  // compound ETH token
    address public ctokenFactory;
    address public marginAddr;  // 浠ｆ寔鍚堢害

    // maker 鎵嬬画璐?&& taker 鎵嬬画璐?
    uint public defaultFeeMaker = 30;
    uint public defaultFeeTaker = 30;
    mapping(uint256 => DataTypes.OBPairConfigMap) public pairFeeRate;
    // 鏈€浣庢寕鍗曢噺
    mapping(address => uint256) public minAmounts;
    mapping(address => mapping(address => uint)) public balanceOf;   // 浠ｆ寔鐢ㄦ埛鐨勫竵

    // orders
    mapping (uint => DataTypes.OrderItem) public orders;
    mapping (address => uint[]) public marginOrders;   // 鏉犳潌鍚堢害浠ｆ寔鐨勬寕鍗?
    mapping (address => uint[]) public addressOrders;
    mapping (uint => uint[]) public pairOrders;

    function pairIndex(uint id) public pure returns(uint) {
        return (id & _PAIR_INDEX_MASK);
    }

    function addrIndex(uint id) public pure returns(uint) {
        return (id & _ADDR_INDEX_MASK) >> _ADDR_INDEX_OFFSET;
    }

    // pairIdx 涓嶅彉, addrIdx 鏇存柊
    function updateAddrIdx(uint idx, uint addrIdx) public pure returns(uint) {
      return pairIndex(idx) | addrIndex(addrIdx);
    }

    // pairIdx 涓嶅彉, addrIdx 鏇存柊
    function updatePairIdx(uint idx, uint pairIdx) public pure returns(uint) {
      return (idx & _ADDR_INDEX_MASK) | pairIdx;
    }

    function maskAddrPairIndex(uint pairIdx, uint addrIdx) public pure returns (uint) {
        return (pairIdx) | (addrIdx << _ADDR_INDEX_OFFSET);
    }

    function isMargin(uint flag) public pure returns (bool) {
      return (flag & _MARGIN_MASK) != 0;
    }

    // function getExpiredAt(uint ts) public pure returns (uint) {
    //   return (ts & _EXPIRED_AT_MASK) >> _EXPIRED_AT_OFFSET;
    // }

    // function maskTimestamp(uint ts, uint expired) public pure returns (uint) {
    //   return (ts) | (expired << _EXPIRED_AT_OFFSET);
    // }
    
    // function setSwapMining(address _swapMininng) public onlyOwner {
    //     swapMining = _swapMininng;
    // }
}


// File contracts/swap/orderbook/ICTokenFactory.sol

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
pragma solidity ^0.6.12;


interface ICTokenFactory {
    // 鏍规嵁 token 鍦板潃鑾峰彇瀵瑰簲鐨?ctoken 鍦板潃
    function getCTokenAddressPure(address token) external view returns (address);

    // 鏍规嵁 ctoken 鍦板潃鑾峰彇瀵瑰簲鐨?token 鍦板潃
    function getTokenAddress(address cToken) external view returns (address);
}


// File contracts/swap/orderbook/ICToken.sol

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

pragma solidity ^0.6.12;

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


// File contracts/swap/orderbook/ICETH.sol

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

pragma solidity ^0.6.12;

interface ICETH {

    function mint() external payable;
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


// File contracts/swap/orderbook/SafeMath.sol

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
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

library SafeMath {
    uint256 constant internal WAD = 10 ** 18;
    uint256 constant internal RAY = 10 ** 27;

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


// File contracts/swap/orderbook/OBPriceLogic.sol

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
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
// 鏍规嵁compound 鏈€鏂扮殑 exchange rate 鎹㈢畻 鎸傚崟鏃剁殑浠锋牸, 鏍规嵁 taker 鐨勫悆鍗曢噺鎹㈢畻鎸傚崟鑰?
// 1. tokenIn 鍜?tokenOut閮芥槸 etoken: 涓嶉渶瑕佹崲绠?
// 2. tokenIn tokenOut 閮芥槸 token: 
library OBPriceLogic {
    using SafeMath for uint;
    using SafeMath for uint256;

    // struct OBPrice {
    //     address src;
    //     address srcEToken;
    //     address dst;
    //     address dstEToken;
    //     uint256 amtIn;
    //     uint256 eAmtIn;
    //     uint256 amtOut;
    //     uint256 eAmtOut;
    //     // uint256 feeTaker;
    //     // uint256 feeMaker;
    // }

    // uint256 constant public DENOMINATOR = 10000;

    function getCurrentExchangeRate(ICToken ctoken) public view returns (uint256) {
        uint rate = ctoken.exchangeRateStored();
        uint supplyRate = ctoken.supplyRatePerBlock();
        uint lastBlock = ctoken.accrualBlockNumber();
        uint blocks = block.number.sub(lastBlock);
        uint inc = rate.mul(supplyRate).mul(blocks);
        return rate.add(inc);
    }

    /// @dev 鏍规嵁浠锋牸璁＄畻 amtToTaken 瀵瑰簲鐨?amtOut
    /// @param data OBPrice to calcutation
    /// @param amtToTaken amount to taken, in etoken
    /// @return maker 寰楀埌鐨勫竵鏁伴噺; 鍗曚綅 etoken 
    function convertBuyAmountByETokenIn(DataTypes.TokenAmount memory data, uint amtToTaken) public view returns (uint) {
        address src = data.srcToken;
        address srcEToken = data.srcEToken;
        address dst = data.destToken;
        address dstEToken = data.destEToken;
        // uint256 feeTaker = DENOMINATOR - data.feeTaker;
        // uint256 feeMaker = DENOMINATOR - data.feeMaker;

        if (src == srcEToken && dst == dstEToken) {
            // 鎸傚崟灏辨槸浠?etoken 鏉ユ寕鐨?
            return amtToTaken.mul(data.guaranteeAmountOut).div(data.amountIn);
            // return amtToSent;
        }

        // 鐢变簬鐩墠 create order宸茬粡闄愬埗浜嗗繀椤诲悓鏃朵负 token 鎴栬€?etoken
        require(src != srcEToken && dst != dstEToken, "invalid orderbook tokens");
        
        // price = amtOut/amtIn = eAmtOut*rateOut/(eAmtIn*rateIn)
        // eprice = (price*rateIn)/rateOut = (amtOut*rateIn)/(amtIn*rateOut)
        uint256 rateIn = getCurrentExchangeRate(ICToken(srcEToken));
        uint256 rateOut = getCurrentExchangeRate(ICToken(dstEToken));

        // 鍚冨崟鑰呴渶瑕佽浆鍏ョ殑甯佺殑鏁伴噺
        return amtToTaken.mul(rateIn).mul(data.guaranteeAmountOut).div(data.amountIn).div(rateOut);
        // return (amtToSendByEToken, amtToTaken);
    }


}


// File contracts/swap/orderbook/Orderbook.sol

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
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
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

interface IWHT {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IHswapV2Callee {
    function hswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

interface IMarginHolding {
  // owner: 鏉犳潌鐢ㄦ埛
  // fulfiled: 涔板埌鐨則oken鏁伴噺(tokenIn)
  // amt: 鍗栧嚭鐨則oken鏁伴噺(tokenOut)
  function onFulfiled(address owner, address tokenOut, address tokenIn, uint fulfiled, uint amt) external;
  // tokenOut: 寰呭崠鍑虹殑甯?srcToken
  // tokenIn: 寰呬拱鍏ョ殑甯?destToken
  // tokenReturn: tokenOut
  // amt: 杩旇繕鐨則okenOut鏁伴噺
  function onCanceled(address owner, address token0, address token1, address tokenReturn, uint amt) external;
}


// interface ICTokenFactory {
//     function getCTokenAddressPure(address cToken) external view returns (address);
//     function getTokenAddress(address cToken) external view returns (address);
// }

interface IOrderBook {
    event CreateOrder(address indexed owner,
          address indexed srcToken,
          address indexed destToken,
          uint orderId,
          uint amountIn,
          uint minAmountOut,
          uint flag);

    event FulFilOrder(address indexed maker,
          address indexed taker,
          uint orderId,
          uint amt,
          uint amtOut,
          uint remaining);

    event CancelOrder(address indexed owner,
          address indexed srcToken,
          address indexed destToken,
          uint orderId);
}

contract OrderBook is OBStorage, IOrderBook, ReentrancyGuard {
    using SafeMath for uint;
    using SafeMath for uint256;

    uint private constant _ORDER_CLOSED = 0x00000000000000000000000000000001;   // 128 bit

    // _ctokenFactory: ctoken 宸ュ巶
    // _wETH: eth/bnb/ht
    // _margin: 浠ｆ寔鍚堢害鍦板潃
    constructor(address _ctokenFactory, address _cETH, address _wETH, address _margin) public {
      ctokenFactory = _ctokenFactory;
      cETH = _cETH;
      wETH = _wETH;
      marginAddr = _margin;
    }

    modifier whenOpen() {
        require(closed == false, "order book closed");
        _;
    }

    function closeOrderBook() external onlyOwner {
      closed = true;
    }

    function openOrderBook() external onlyOwner {
      closed = false;
    }

    function setMinOrderAmount(address token, uint amt) external onlyOwner {
      minAmounts[token] = amt;
    }

    function _putOrder(DataTypes.OrderItem storage order) internal {
      uint orderId = order.orderId;
      bool margin = isMargin(order.flag);
      uint addrIdx;
      uint pairIdx;

      if (margin) {
          addrIdx = marginOrders[order.owner].length;
          marginOrders[order.owner].push(orderId);
      } else {
          addrIdx = addressOrders[order.owner].length;
          addressOrders[order.owner].push(orderId);
      }

      pairIdx = pairOrders[order.pair].length;
      pairOrders[order.pair].push(orderId);

      order.pairAddrIdx = maskAddrPairIndex(pairIdx, addrIdx);

      emit CreateOrder(order.owner,
          order.tokenAmt.srcToken,
          order.tokenAmt.destToken,
          orderId,
          order.tokenAmt.amountIn,
          order.tokenAmt.guaranteeAmountOut,
          order.flag);
    }

    function _removeOrder(DataTypes.OrderItem memory order) private {
        // uint orderId = order.orderId;
        uint pairIdx = pairIndex(order.pairAddrIdx);
        uint addrIdx = addrIndex(order.pairAddrIdx);
        address owner = order.owner;
        uint rIdx;
        bool margin = isMargin(order.flag);
        
        if (margin) {
            if ((marginOrders[owner].length > 1) && (addrIdx != marginOrders[owner].length-1)) {
              rIdx = marginOrders[owner][marginOrders[owner].length - 1];
              marginOrders[owner][addrIdx] = rIdx;
              orders[rIdx].pairAddrIdx = updateAddrIdx(orders[rIdx].pairAddrIdx, addrIdx);
            }
            marginOrders[owner].pop();
        } else {
            if ((addressOrders[owner].length > 1) && (addrIdx != addressOrders[owner].length-1)) {
              rIdx = addressOrders[owner][addressOrders[owner].length - 1];
              addressOrders[owner][addrIdx] = rIdx;
              orders[rIdx].pairAddrIdx = updateAddrIdx(orders[rIdx].pairAddrIdx, addrIdx);
            }
            addressOrders[owner].pop();
        }

        if ((pairOrders[order.pair].length > 1) && (pairIdx != pairOrders[order.pair].length-1)) {
          rIdx = pairOrders[order.pair][pairOrders[order.pair].length - 1];
          pairOrders[order.pair][pairIdx] = rIdx;
          orders[rIdx].pairAddrIdx = updatePairIdx(orders[rIdx].pairAddrIdx, pairIdx);
        }
        pairOrders[order.pair].pop();
    }

    // 濡傛灉鎵惧埌 addr 瀵瑰簲鐨?etoken 鍦板潃, 杩斿洖 etoken 鍦板潃; 鍚﹀垯, addr 鏈韩灏辨槸 etoken, 杩斿洖 addr
    function _getETokenAddress(address addr) internal view returns (address) {
      address etoken = ICTokenFactory(ctokenFactory).getCTokenAddressPure(addr);
      if (etoken == address(0)) {
        return addr;
      }
      return etoken;
    }

    // 鍒涘缓璁㈠崟
    // 璋冪敤鍓嶉渶瑕?approve
    function createOrder(
        address srcToken,
        address destToken,
        address to,             // 鍏戞崲寰楀埌鐨則oken鍙戦€佸湴鍧€, 鏉犳潌浼犵敤鎴峰湴鍧€
        uint amountIn,
        uint guaranteeAmountOut,       // 
        // uint expiredAt,          // 杩囨湡鏃堕棿
        uint flag) public payable whenOpen nonReentrant returns (uint) {
      require(srcToken != destToken, "identical token");

      if (srcToken == address(0)) {
        // 杞叆 wETH
        require(msg.value >= amountIn, "not enough amountIn");
        // IWHT(wETH).deposit{value: msg.value}();
        // srcToken = wETH;
      } else {
        // should approve outside
        TransferHelper.safeTransferFrom(srcToken, msg.sender, address(this), amountIn);
      }

      {
        // 鏈€浣庢寕鍗曢噺闄愬埗
        require(amountIn > minAmounts[srcToken], "less than min amount");
      }
      uint idx = orderId ++;
      DataTypes.OrderItem storage order = orders[idx];
      order.orderId = idx;
      order.owner = msg.sender;
      order.to = to == address(0) ? msg.sender : to;
      // solhint-disable-next-line
      order.timestamp = block.timestamp; // maskTimestamp(block.timestamp, expiredAt);
      order.flag = flag;
      order.tokenAmt.fulfiled = 0;
      address etoken = _getETokenAddress(srcToken);
      {
        order.tokenAmt.srcToken = srcToken;
        order.tokenAmt.srcEToken = etoken;
        order.tokenAmt.amountIn = amountIn;
        if (srcToken != etoken) {
          // order.isEToken = true;
          // mint to etoken
          if (srcToken == address(0)) {
            uint balanceBefore = IERC20(cETH).balanceOf(address(this));
            ICETH(cETH).mint{value: msg.value}();
            order.tokenAmt.amountInMint = IERC20(cETH).balanceOf(address(this)).sub(balanceBefore);
          } else {
            uint balanceBefore = IERC20(etoken).balanceOf(address(this));
            ICToken(etoken).mint(amountIn);
            order.tokenAmt.amountInMint = IERC20(etoken).balanceOf(address(this)).sub(balanceBefore);
          }
        } else {
          order.tokenAmt.amountInMint = amountIn;
        }
      }
      order.tokenAmt.destToken = destToken;
      order.tokenAmt.destEToken = _getETokenAddress(destToken);
      order.tokenAmt.guaranteeAmountOut = guaranteeAmountOut;

      // src dest 蹇呴』鍚屾椂涓?token 鎴栬€?etoken
      require((srcToken == etoken) == (destToken == order.tokenAmt.destToken), "both token or etoken");

      if (msg.sender == marginAddr) {
        // 浠ｆ寔鍚堢害鍙兘鎸?etoken
        require(etoken == srcToken, "src should be etoken");
        require(order.tokenAmt.destEToken == destToken, "dest should be etoken");
      }
      // if (destToken != order.tokenAmt.destEToken) {

      // } else {
      //   order.tokenAmt.guaranteeAmountOutEToken = guaranteeAmountOut;
      // }

      // (address token0, address token1) = srcToken < destToken ? (srcToken, destToken) : (destToken, srcToken);
      order.pair = _pairFor(srcToken, destToken);

      _putOrder(order);

      return idx;
    }

    // 鑾峰彇鎵€鏈夎鍗曞垪琛?
    function getAllOrders() public view returns(DataTypes.OrderItem[] memory allOrders) {
      uint total = 0;
      uint id = 0;
      for (uint i = 0; i < orderId; i ++) {
        uint flag = orders[i].flag;
        if (_orderClosed(flag) == false) {
          total ++;
        }
      }

      allOrders = new DataTypes.OrderItem[](total);
      for (uint i = 0; i < orderId; i ++) {
        DataTypes.OrderItem memory order = orders[i];
        if (_orderClosed(order.flag) == false) {
          allOrders[id] = order;
          id ++;
        }
      }
    }

    function pairFor(address srcToken, address destToken) public view returns(uint pair) {
      return _pairFor(_getETokenAddress(srcToken), _getETokenAddress(destToken));
    }

    // 璋冪敤鍓嶉渶瑕佺‘淇?srcToken destToken 閮芥槸 etoken
    // 浜ゆ槗瀵筯ash 鍖哄垎鏂瑰悜 eth->usdt 涓?usdt->eth 鏄笉鍚岀殑浜ゆ槗瀵?
    function _pairFor(address srcToken, address destToken) private view returns(uint pair) {
      // if (srcToken == address(0)) {
      //     srcToken = wETH;
      // }
      // if (destToken == address(0)) {
      //     destToken = wETH;
      // }
      // (address token0, address token1) = srcToken < destToken ? (srcToken, destToken) : (destToken, srcToken);
      pair = uint(keccak256(abi.encodePacked(srcToken, destToken)));
    }

    function _orderClosed(uint flag) private pure returns (bool) {
      return (flag & _ORDER_CLOSED) != 0;
    }

    function cancelOrder(uint orderId) public nonReentrant {
      DataTypes.OrderItem storage order = orders[orderId];
      bool margin = isMargin(order.flag);

      if (margin) {
        require(msg.sender == owner() || msg.sender == marginAddr, "cancelMarginOrder: no auth");
      } else {
        require(msg.sender == owner() || msg.sender == order.owner, "cancelOrder: no auth");
      }
      require(_orderClosed(order.flag) == false, "order has been closed");
      address srcToken = order.tokenAmt.srcToken;
      address srcEToken = order.tokenAmt.srcEToken;
      uint amt = order.tokenAmt.amountIn.sub(order.tokenAmt.fulfiled);

      if (srcToken != srcEToken) {
        // redeem etoken
        // 濡傛灉鏈夎冻澶熷鐨?etoken 鍙互璧庡洖, 鍒欏叏閮ㄨ祹鍥? 鍚﹀垯灏藉彲鑳藉鐨勮祹鍥?
        uint cash = ICToken(srcEToken).getCash();
        uint redeemAmt = amt;
        uint remainingEToken = 0;
        if (cash < amt) {
          redeemAmt = cash;
          remainingEToken = amt.sub(cash);
        }

        if (redeemAmt > 0) {
          // redeem token
          uint balanceBefore;
          if (srcEToken == cETH) {
            balanceBefore = address(this).balance;
            ICToken(cETH).redeem(redeemAmt);
            uint amt = address(this).balance.sub(balanceBefore);
            TransferHelper.safeTransferETH(order.owner, amt);
          } else {
            balanceBefore = IERC20(srcToken).balanceOf(address(this));
            ICToken(srcEToken).redeem(redeemAmt);
            uint amt = IERC20(srcToken).balanceOf(address(this)).sub(balanceBefore);
            TransferHelper.safeTransfer(srcToken, order.owner, amt);
          }
        }
        if (remainingEToken > 0) {
          TransferHelper.safeTransfer(srcEToken, order.owner, remainingEToken);
        }
      } else {
        TransferHelper.safeTransfer(srcToken, order.owner, amt);
      }

      // 鏉犳潌鐢ㄦ埛鎴愪氦鐨勫竵宸茬粡杞粰浠ｆ寔鍚堢害, 杩欓噷鍙鐞嗛潪鏉犳潌鐢ㄦ埛鐨勫竵锛岃繕缁欑敤鎴?
      if (!margin) {
        address dest = order.tokenAmt.destEToken;
        uint balance = balanceOf[dest][order.to];
        if (balance > 0) {
          _withdraw(order.to, srcEToken, balance, balance);
        }
      } else {
        // 閫氱煡鏉犳潌鍚堢害澶勭悊 鎸傚崟 srcToken
        IMarginHolding(marginAddr).onCanceled(order.to, srcEToken, order.tokenAmt.destToken, order.tokenAmt.srcToken, amt);
      }


      emit CancelOrder(order.owner, order.tokenAmt.srcToken, order.tokenAmt.destToken, orderId);
      order.flag |= _ORDER_CLOSED;
      _removeOrder(order);
    }

    // // 鍓╀綑鍙垚浜ら儴鍒?
    // function _amountRemaining(uint amtTotal, uint fulfiled) internal pure returns (uint) {
    //     // (amtTotal - fulfiled) * (1 - fee)
    //     return amtTotal.sub(fulfiled);
    // }

    /// @dev get maker fee rate
    function getMakerFeeRate(uint256 pair) public view returns (uint) {
      uint fee = pairFeeRate[pair].feeMaker();
      if (fee == 0) {
        return defaultFeeMaker;
      }
      return fee - 1;
    }

    /// @dev get taker fee rate
    function getTakerFeeRate(uint256 pair) public view returns (uint) {
      uint fee = pairFeeRate[pair].feeTaker();
      if (fee == 0) {
        return defaultFeeTaker;
      }

      return fee - 1;
    }

    function _discountFee(uint256 amt, uint256 fee) private pure returns (uint256) {
        return amt.mul(fee).div(DENOMINATOR);
    }


    // srcToken destToken 閮藉繀椤绘槸 etoken
    // buyAmt: 寰呬拱璧扮殑鎸傚崠token鐨勬暟閲? 鏈墸闄ゆ墜缁垂
    // outAmt: 鎸傚崠寰楀埌鐨則oken 鐨勬暟閲? 鏈墸闄ゆ墜缁垂
    function _swap(address srcToken,
            address destToken,
            address maker,
            address taker,
            uint takerAmt,
            uint makerAmt,
            bool margin) private {
      if (margin) {
        // 鍥炶皟
        IMarginHolding(marginAddr).onFulfiled(maker, srcToken, destToken, makerAmt, takerAmt);
      } else {
        balanceOf[destToken][maker] += makerAmt;
      }

      // 涔板寰楀埌鐨勫竵
      // if (srcToken == address(0)) {
      //   TransferHelper.safeTransferETH(buyer, buyAmt);
      // } else {
        TransferHelper.safeTransfer(srcToken, taker, takerAmt);
      // }
    }

    /// @dev fulfil orderbook order, token in and token out is token
    // function fulfilOrderUnderlying(uint orderId,
    //         bool partialFill,
    //         uint amtToTaken,
    //         address to,
    //         bytes calldata data) external payable whenOpen nonReentrant returns (uint, uint) {
    //   DataTypes.OrderItem storage order = orders[orderId];
    //   if ((order.flag & _ORDER_CLOSED) > 0) {
    //       return (0, 0);
    //   }

    //   uint left = order.tokenAmt.amountInMint.sub(order.tokenAmt.fulfiled);

    //   if(left < amtToTaken) {
    //     if (partialFill == false) {
    //       return (0, 0);
    //     } else {
    //       amtToTaken = left;
    //     }
    //   } // , "not enough");


    //   if (to == address(0)) {
    //     to = msg.sender;
    //   }

    // }

    struct TransferMintParam {
      bool isTokenIn;
      address srcToken;
      address srcEToken;
      address destEToken;
      uint amtToTaken;
      uint amtDest;
      address to;
    }
    /// @dev fulfil orderbook order, etoken in and etoken out
    // order 鎴愪氦, 鏀跺彇鎴愪氦鍚庣殑甯佺殑鎵嬬画璐? 鏅€氳鍗? maker 鎴愪氦鐨勫竵鐢卞悎绾︿唬鎸? taker 鐨勫竵鍙戠粰鐢ㄦ埛, amtToTaken 鏄?src EToken 鐨勬暟閲?
    /// @param orderId order id
    /// @param amtToTaken 鎴愪氦澶氬皯閲?
    /// @param to 鍚堢害鍦板潃鎴栬€?msg.sender
    /// @param partialFill 鏄惁鍏佽閮ㄥ垎鎴愪氦(姝ｅソ姝ゆ椂閮ㄥ垎琚叾浠栦汉taken)
    /// @param isTokenIn taker 鐨勫崠鍑哄竵鏄惁鏄?token
    /// @param data flashloan 鍚堢害鎵ц浠ｇ爜
    /// @return (涔板埌鐨勫竵鏁伴噺, 浠樺嚭鐨勫竵鏁伴噺)
    function fulfilOrder(uint orderId,
            uint amtToTaken,
            address to,
            bool partialFill,
            bool isTokenIn,        // amount in is token, should mint to eToken
            bytes calldata data) external payable whenOpen nonReentrant returns (uint, uint) {
      DataTypes.OrderItem storage order = orders[orderId];

      if ((order.flag & _ORDER_CLOSED) > 0) {
          return (0, 0);
      }

      uint left = order.tokenAmt.amountInMint.sub(order.tokenAmt.fulfiled);
      if(left < amtToTaken) {
        if (partialFill == false) {
          return (0, 0);
        } else {
          amtToTaken = left;
        }
      }


      if (to == address(0)) {
        to = msg.sender;
      }

      (uint takerAmt, uint makerAmt, uint amtDest) = _fulfil(order, to, amtToTaken, left);

      // // 鎸傚崟鑰呭湪涓嶆墸闄ゆ墜缁垂鐨勬儏鍐典笅寰楀埌鐨勫竵鐨勬暟閲?
      // DataTypes.TokenAmount memory tokenAmt = order.tokenAmt;
      // uint amtDest = OBPriceLogic.convertBuyAmountByETokenIn(tokenAmt, amtToTaken);

      // uint pair = order.pair;
      // address destToken = order.tokenAmt.destEToken;
      // // taker寰楀埌鐨勫竵锛屾墸闄ゆ墜缁垂
      // uint takerAmt = amtToTaken.mul(DENOMINATOR-getTakerFeeRate(pair)).div(DENOMINATOR);
      // // maker 寰楀埌鐨勫竵鏁伴噺锛屾墸闄ゆ墜缁垂
      // uint makerAmt = amtDest.mul(DENOMINATOR-getMakerFeeRate(pair)).div(DENOMINATOR);
      // _swap(order.tokenAmt.srcEToken, destToken, order.to, to, takerAmt, makerAmt, isMargin(order.flag));
      
      // left -= amtToTaken;
      // order.tokenAmt.fulfiled += amtToTaken;

      // emit FulFilOrder(order.owner, to, orderId, amtToTaken, amtDest, left);
      // if (left == 0) {
      //   //
      //   order.flag |= _ORDER_CLOSED;
      //   _removeOrder(order);
      // }
      
      // 楠岃瘉杞叆 taker 鐨勫竵
      if (data.length > 0) {
        address destEToken = order.tokenAmt.destEToken;
        uint256 balanceBefore = IERC20(destEToken).balanceOf(address(this));
        IHswapV2Callee(to).hswapV2Call(msg.sender, takerAmt, makerAmt, data);
        uint256 transferIn = IERC20(destEToken).balanceOf(address(this)).sub(balanceBefore);
        require(transferIn >= amtDest, "not enough");
      } else {
        // if (isTokenIn) {
        //   // mint
        //   address srcToken = order.tokenAmt.srcToken;

        //   if (srcToken == address(0)) {
        //     uint balanceBefore = IERC20(cETH).balanceOf(address(this));
        //     ICETH(cETH).mint{value: msg.value}();
        //     uint minted = IERC20(cETH).balanceOf(address(this)).sub(balanceBefore);
        //     require(minted > amtToTaken, "mint not enough cETH");
        //   } else {
        //     address srcEToken = order.tokenAmt.srcEToken;
        //     uint rateIn = OBPriceLogic.getCurrentExchangeRate(ICToken(srcEToken));
        //     uint amtIn = amtToTaken.mul(rateIn).div(1e18);
        //     TransferHelper.safeTransferFrom(srcToken, to, srcEToken, amtIn);
        //     ICToken(srcEToken).mint(amtIn);
        //   }
        // } else {
        //   address destEToken = order.tokenAmt.destEToken;
        //   TransferHelper.safeTransferFrom(destEToken, to, address(this), amtDest);
        // }
        TransferMintParam memory param;
        param.isTokenIn = isTokenIn;
        param.srcToken = order.tokenAmt.srcToken;
        param.srcEToken = order.tokenAmt.srcEToken;
        param.destEToken = order.tokenAmt.destEToken;
        param.amtToTaken = amtToTaken;
        param.amtDest = amtDest;
        param.to = to;
        _tranferOrMint(param);
      }

      return (takerAmt, makerAmt);
    }


    function _tranferOrMint(TransferMintParam memory param) private {
        address to = param.to;

        if (param.isTokenIn) {
          // mint
          address srcToken = param.srcToken;
          uint amtToTaken = param.amtToTaken;

          if (srcToken == address(0)) {
            uint balanceBefore = IERC20(cETH).balanceOf(address(this));
            ICETH(cETH).mint{value: msg.value}();
            uint minted = IERC20(cETH).balanceOf(address(this)).sub(balanceBefore);
            require(minted > amtToTaken, "mint not enough cETH");
          } else {
            address srcEToken = param.srcEToken;
            uint rateIn = OBPriceLogic.getCurrentExchangeRate(ICToken(srcEToken));
            uint amtIn = amtToTaken.mul(rateIn).div(1e18);
            TransferHelper.safeTransferFrom(srcToken, to, srcEToken, amtIn);
            ICToken(srcEToken).mint(amtIn);
          }
        } else {
          address destEToken = param.destEToken;
          TransferHelper.safeTransferFrom(destEToken, to, address(this), param.amtDest);
        }
    }

    function _fulfil(DataTypes.OrderItem storage order, address taker, uint256 amtToTaken, uint256 left) private returns (uint, uint, uint) {
      DataTypes.TokenAmount memory tokenAmt = order.tokenAmt;
      // 鎸傚崟鑰呭湪涓嶆墸闄ゆ墜缁垂鐨勬儏鍐典笅寰楀埌鐨勫竵鐨勬暟閲?
      uint amtDest = OBPriceLogic.convertBuyAmountByETokenIn(tokenAmt, amtToTaken);

      address srcEToken = tokenAmt.srcEToken;
      address destEToken = tokenAmt.destEToken;
      address maker = order.to;
      uint256 pair = order.pair;
      // taker寰楀埌鐨勫竵锛屾墸闄ゆ墜缁垂
      uint takerAmt = amtToTaken.mul(DENOMINATOR-getTakerFeeRate(pair)).div(DENOMINATOR);
      // maker 寰楀埌鐨勫竵鏁伴噺锛屾墸闄ゆ墜缁垂
      uint makerAmt = amtDest.mul(DENOMINATOR-getMakerFeeRate(pair)).div(DENOMINATOR);
      
      if (isMargin(order.flag)) {
        // 鍥炶皟
        IMarginHolding(marginAddr).onFulfiled(maker, srcEToken, destEToken, makerAmt, takerAmt);
      } else {
        balanceOf[destEToken][maker] += makerAmt;
      }

      // todo 涔板甯屾湜寰楀埌鐨勬槸閭ｇ甯?
      // 涔板寰楀埌鐨勫竵
      // if (srcToken == address(0)) {
      //   TransferHelper.safeTransferETH(buyer, buyAmt);
      // } else {
      TransferHelper.safeTransfer(srcEToken, taker, takerAmt);

      // _swap(tokenAmt.srcEToken, destToken, order.to, to, takerAmt, makerAmt, isMargin(order.flag));

      left -= amtToTaken;
      order.tokenAmt.fulfiled += amtToTaken;

      if (left == 0) {
        //
        order.flag |= _ORDER_CLOSED;
        _removeOrder(order);
      }

      return (takerAmt, makerAmt, amtDest);
    }

    // function fulfilOrders(uint[] memory orderIds, uint[] memory amtToTaken) external whenOpen {
    //     require(orderIds.length == amtToTaken.length, "array length should equal");

    //     for (uint i = 0; i < orderIds.length; i ++) {
    //       try fulfilOrder(orderIds[i], amtToTaken[i]) {
    //       } catch {
    //         // nothing
    //       }
    //     }
    // }

    // withdraw etoken
    // token should be etoken
    function _withdraw(address user, address etoken, uint total, uint amt) private {
        TransferHelper.safeTransfer(etoken, user, amt);

        balanceOf[etoken][user] = total.sub(amt);
    }

    function _withdrawUnderlying(address user, address token, address etoken, uint total, uint amt) private {
        balanceOf[etoken][user] = total.sub(amt);

        if (etoken == cETH) {
          uint balanceBefore = address(this).balance;
          ICETH(cETH).redeem(amt);
          uint redeemAmt = address(this).balance.sub(balanceBefore);
          TransferHelper.safeTransferETH(user, redeemAmt);
        } else {
          uint balanceBefore = IERC20(token).balanceOf(address(this));
          ICToken(etoken).redeem(amt);
          uint redeemAmt = IERC20(token).balanceOf(address(this)).sub(balanceBefore);
          TransferHelper.safeTransfer(token, user, redeemAmt);
        }
    }

    // 鐢ㄦ埛鎴愪氦鍚庯紝璧勯噾鐢卞悎绾︿唬绠? 鐢ㄦ埛鎻愮幇寰楀埌鑷繁鐨?etoken
    function withdraw(address token, uint amt) external {
        uint total = balanceOf[token][msg.sender];
        require(total >= amt, "not enough asset");

        _withdraw(msg.sender, token, total, amt);
    }

    // 鐢ㄦ埛鎴愪氦鍚庯紝璧勯噾鐢卞悎绾︿唬绠? 鐢ㄦ埛鎻愮幇寰楀埌鑷繁鐨?token
    function withdrawUnderlying(address token, uint amt) external {
        address etoken = _getETokenAddress(token);
        uint total = balanceOf[etoken][msg.sender];
        require(total >= amt, "not enough asset");

        _withdrawUnderlying(msg.sender, token, etoken, total, amt);
    }

    function adminTransfer(address token, address to, uint amt) external onlyOwner {
        if (token == address(0)) {
          TransferHelper.safeTransferETH(to, amt);
        } else {
          TransferHelper.safeTransfer(token, to, amt);
        }
    }

    function _getPairFee(address src, address dest) internal returns (DataTypes.OBPairConfigMap storage conf) {
      address srcEToken = _getETokenAddress(src);
      address destEToken = _getETokenAddress(dest);
      uint256 pair = _pairFor(srcEToken, destEToken);
      DataTypes.OBPairConfigMap storage conf = pairFeeRate[pair];
      return conf;
    }

    function setPairTakerFee(address src, address dest, uint fee) external onlyOwner {
      DataTypes.OBPairConfigMap storage conf = _getPairFee(src, dest);

      conf.setFeeTaker(fee);
    }
    
    function setPairMakerFee(address src, address dest, uint fee) external onlyOwner {
      DataTypes.OBPairConfigMap storage conf = _getPairFee(src, dest);

      conf.setFeeMaker(fee);
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
