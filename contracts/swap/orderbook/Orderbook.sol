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

import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./OBStorage.sol";

// import "../aggressive/SafeMath.sol";

// import "hardhat/console.sol";

// interface ISwapMining {
//     function swap(address account, address input, address output, uint256 amount) external returns (bool);
// }

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

interface IMarginHolding {
  // owner: 杠杆用户
  // fulfiled: 买到的token数量(tokenIn)
  // amt: 卖出的token数量(tokenOut)
  function onFulfiled(address owner, address tokenOut, address tokenIn, uint fulfiled, uint amt) external;
  // tokenOut: 待卖出的币 srcToken
  // tokenIn: 待买入的币 destToken
  // tokenReturn: tokenOut
  // amt: 返还的tokenOut数量
  function onCanceled(address owner, address token0, address token1, address tokenReturn, uint amt) external;
}


interface ICTokenFactory {
    function getCTokenAddressPure(address cToken) external view returns (address);
    function getTokenAddress(address cToken) external view returns (address);
}

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

    // _ctokenFactory: ctoken 工厂
    // _wETH: eth/bnb/ht 白手套
    // _margin: 代持合约地址
    constructor(address _ctokenFactory, address _wETH, address _margin) public {
      ctokenFactory = _ctokenFactory;
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

    // 创建订单
    // 调用前需要 approve
    function createOrder(
        address srcToken,
        address destToken,
        address to,             // 兑换得到的token发送地址, 杠杆传用户地址
        uint amountIn,
        uint guaranteeAmountOut,       // 
        uint expiredAt,          // 过期时间
        uint flag) public payable whenOpen nonReentrant returns (uint) {
      require(srcToken != destToken, "identical token");
    //solium-disable-next-line
      require(expiredAt == 0 || expiredAt > block.timestamp, "invalid param expiredAt");

      if (srcToken == address(0)) {
        // 转入 wETH
        require(msg.value >= amountIn, "not enough amountIn");
        // IWHT(wETH).deposit{value: msg.value}();
        srcToken = wETH;
      } else {
        // should approve outside
        TransferHelper.safeTransferFrom(srcToken, msg.sender, address(this), amountIn);
      }

      {
        // 最低挂单量限制
        require(amountIn > minAmounts[srcToken], "less than min amount");
      }
      uint idx = orderId ++;
      DataTypes.OrderItem storage order = orders[idx];
      order.orderId = idx;
      order.owner = msg.sender;
      order.to = to == address(0) ? msg.sender : to;
      order.timestamp = maskTimestamp(block.timestamp, expiredAt);
      order.flag = flag;
      order.tokenAmt.srcToken = srcToken;
      order.tokenAmt.destToken = destToken;
      order.tokenAmt.amountIn = amountIn;
      order.tokenAmt.fulfiled = 0;
      order.tokenAmt.guaranteeAmountOut = guaranteeAmountOut;

      // (address token0, address token1) = srcToken < destToken ? (srcToken, destToken) : (destToken, srcToken);
      order.pair = pairFor(srcToken, destToken);

      _putOrder(order);

      return idx;
    }

    // 获取所有订单列表
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

    // 交易对hash
    function pairFor(address srcToken, address destToken) public view returns(uint pair) {
      if (srcToken == address(0)) {
          srcToken = wETH;
      }
      if (destToken == address(0)) {
          destToken = wETH;
      }
      (address token0, address token1) = srcToken < destToken ? (srcToken, destToken) : (destToken, srcToken);
      pair = uint(keccak256(abi.encodePacked(token0, token1)));
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
      uint amt = order.tokenAmt.amountIn.sub(order.tokenAmt.fulfiled);

      if (srcToken == address(0)) {
        TransferHelper.safeTransferETH(order.owner, amt);
      } else {
        TransferHelper.safeTransfer(srcToken, order.owner, amt);
      }

      // 杠杆用户成交的币已经转给代持合约, 这里只处理非杠杆用户的币，还给用户
      if (!margin) {
        address src = order.tokenAmt.srcToken;
        uint balance = balanceOf[src][order.to];
        _withdraw(order.to, src, balance, balance);
      } else {
        // 通知杠杆合约处理 挂单 srcToken
        IMarginHolding(marginAddr).onCanceled(order.to, order.tokenAmt.srcToken, order.tokenAmt.destToken, order.tokenAmt.srcToken, amt);
      }

      emit CancelOrder(order.owner, order.tokenAmt.srcToken, order.tokenAmt.destToken, orderId);
      order.flag |= _ORDER_CLOSED;
      _removeOrder(order);
    }

    // 剩余可成交部分
    function _amountRemaining(uint amtTotal, uint fulfiled) internal pure returns (uint) {
        // (amtTotal - fulfiled) * (1 - fee)
        return amtTotal.sub(fulfiled);
    }

    // buyAmt: 待买走的挂卖token的数量, 未扣除手续费
    // outAmt: 挂卖得到的token 的数量, 未扣除手续费
    function _swap(address srcToken, address destToken, address maker, address buyer, uint buyAmt, uint outAmt, bool margin) private {
      if (margin) {
        // 回调
        IMarginHolding(marginAddr).onFulfiled(maker, srcToken, destToken, outAmt, buyAmt);
      } else {
        balanceOf[destToken][maker] += outAmt;
      }

      // 买家得到的币
      if (srcToken == address(0)) {
        TransferHelper.safeTransferETH(buyer, buyAmt);
      } else {
        TransferHelper.safeTransfer(srcToken, buyer, buyAmt);
      }
    }

    // todo
    function getFeeRate() public view returns (uint) {
      return 10000 - 30;
    }

    // order 成交, 收取成交后的币的手续费
    // 普通订单, maker 成交的币由合约代持; taker 的币发给用户
    //
    function fulfilOrder(uint orderId, uint amtToTaken) external payable whenOpen nonReentrant returns (uint) {
      DataTypes.OrderItem storage order = orders[orderId];
      uint expired = getExpiredAt(order.timestamp);

      if ((expired != 0) && (expired < block.timestamp)) {
        // 已过期
        cancelOrder(orderId);
        return 0;
      }

      if ((order.flag & _ORDER_CLOSED) > 0) {
          return 0;
      }

      uint left = order.tokenAmt.amountIn.sub(order.tokenAmt.fulfiled);

      if(left < amtToTaken) {
        return 0;
      } // , "not enough");

      address destToken = order.tokenAmt.destToken;
      // 挂单者在不扣除手续费的情况下得到的币的数量
      uint amtDest = amtToTaken.mul(order.tokenAmt.guaranteeAmountOut).div(order.tokenAmt.amountIn);
      uint fee = getFeeRate();
      // 买家得到的
      uint _buyAmt = amtToTaken.mul(fee).div(10000);
      uint _outAmt = amtDest.mul(fee).div(10000);
      _swap(order.tokenAmt.srcToken, order.tokenAmt.destToken, order.to, msg.sender, _buyAmt, _outAmt, isMargin(order.flag));

      // 验证转移买家的币
      if (destToken == address(0)) {
        require(msg.value >= amtDest, "amount not transfer in");
      } else {
        TransferHelper.safeTransferFrom(destToken, msg.sender, address(this), amtDest);
      }

      left -= amtToTaken;
      order.tokenAmt.fulfiled += amtToTaken;

      emit FulFilOrder(order.owner, msg.sender, orderId, amtToTaken, amtDest, left);
      if (left == 0) {
        //
        order.flag |= _ORDER_CLOSED;
        _removeOrder(order);
      }
      return _buyAmt;
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

    function _withdraw(address user, address token, uint total, uint amt) private {
        if (token == address(0)) {
          TransferHelper.safeTransferETH(user, amt);
        } else {
          TransferHelper.safeTransfer(token, user, amt);
        }

        balanceOf[token][user] = total.sub(amt);
    }

    // 用户成交后，资金由合约代管, 用户提现得到自己的 token
    function withdraw(address token, uint amt) external {
        uint total = balanceOf[token][msg.sender];
        require(total >= amt, "not enough asset");

        _withdraw(msg.sender, token, total, amt);
    }

    function adminTransfer(address token, address to, uint amt) external onlyOwner {
        if (token == address(0)) {
          TransferHelper.safeTransferETH(to, amt);
        } else {
          TransferHelper.safeTransfer(token, to, amt);
        }
    }
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}


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
