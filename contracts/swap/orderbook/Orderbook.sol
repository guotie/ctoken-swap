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

// import "../aggressive/Ownable.sol";
// import "../aggressive/SafeMath.sol";

// import "hardhat/console.sol";

interface ISwapMining {
    function swap(address account, address input, address output, uint256 amount) external returns (bool);
}

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

// 存储
contract OBStorage is Ownable {
    uint private constant _PAIR_INDEX_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;   // 128 bit
    uint private constant _ADDR_INDEX_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   // 128 bit
    uint private constant _MARGIN_MASK     = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint private constant _EXPIRED_AT_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   // 128 bit
    uint private constant _ADDR_INDEX_OFFSET = 128;
    uint private constant _EXPIRED_AT_OFFSET = 128;

    struct TokenAmount {
        address srcToken;
        address destToken;
        uint amountIn;           // 初始挂单数量
        uint fulfiled;         // 部分成交时 剩余待成交金额
        uint guaranteeAmountOut;       // 最低兑换后要求得到的数量
        // uint guaranteeAmountOutLeft;   // 兑换一部分后, 剩下的需要兑换得到的数量
    }

    struct OrderItem {
      uint orderId;
      uint pairAddrIdx;        // pairIdx | addrIdx
      address owner;
      address to;              // 兑换得到的token发送地址 未使用
      uint pair;               // hash(srcToken, destToken)
      uint timestamp;          // 过期时间 | 挂单时间 
      uint flag;
      TokenAmount tokenAmt;
      // bool margin;             // 是否是杠杆合约的挂单
    }

    // 计算价格的乘数 price = token0 * priceRatio / token1, such as 1e30
    uint public priceRatio = 1e30; 

    uint public orderId;   // order Id 自增

    // 关闭订单薄功能
    bool public closed;
    address public router;
    address public wETH;
    address public ctokenFactory;
    address public marginAddr;  // 代持合约
    address public swapMining;  // 交易挖矿

    uint public minBuyAmt;
    uint public minSellAmt;
    uint public feeRate = 30; // 千分之三

    // token 最低挂单量
    mapping(address => uint) public minAmounts;
    mapping(address => mapping(address => uint)) public balanceOf;   // 代持用户的币

    // orders
    mapping (uint => OrderItem) public orders;
    mapping (address => uint[]) public marginOrders;   // 杠杆合约代持的挂单
    mapping (address => uint[]) public addressOrders;
    mapping (uint => uint[]) public pairOrders;

    function pairIndex(uint id) public pure returns(uint) {
        return (id & _PAIR_INDEX_MASK);
    }

    function addrIndex(uint id) public pure returns(uint) {
        return (id & _ADDR_INDEX_MASK) >> _ADDR_INDEX_OFFSET;
    }

    // pairIdx 不变, addrIdx 更新
    function updateAddrIdx(uint idx, uint addrIdx) public pure returns(uint) {
      return pairIndex(idx) | addrIndex(addrIdx);
    }

    // pairIdx 不变, addrIdx 更新
    function updatePairIdx(uint idx, uint pairIdx) public pure returns(uint) {
      return (idx & _ADDR_INDEX_MASK) | pairIdx;
    }

    function maskAddrPairIndex(uint pairIdx, uint addrIdx) public pure returns (uint) {
        return (pairIdx) | (addrIdx << _ADDR_INDEX_OFFSET);
    }

    function isMargin(uint flag) public pure returns (bool) {
      return (flag & _MARGIN_MASK) != 0;
    }

    function getExpiredAt(uint ts) public pure returns (uint) {
      return (ts & _EXPIRED_AT_MASK) >> _EXPIRED_AT_OFFSET;
    }

    function maskTimestamp(uint ts, uint expired) public pure returns (uint) {
      return (ts) | (expired << _EXPIRED_AT_OFFSET);
    }
    
    function setSwapMining(address _swapMininng) public onlyOwner {
        swapMining = _swapMininng;
    }
}

interface IWHT {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IMarginHolding {
  // owner: 杠杆用户
  // fulfiled: 买到的token数量
  // amt: 卖出的token数量
  function onFulfiled(address owner, uint fulfiled, uint amt) external;
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

    event CancelOrder(address indexed owner, uint orderId);
}

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

contract OrderBook is OBStorage, IOrderBook, ReentrancyGuard {
    using SafeMath for uint;
    using SafeMath for uint256;
    uint private constant _ORDER_CLOSED = 0x00000000000000000000000000000001;   // 128 bit

    // _router: swap 路由
    // _ctokenFactory: ctoken 工厂
    // _wETH: eth/bnb/ht 白手套
    // _margin: 代持合约地址
    constructor(address _router, address _ctokenFactory, address _wETH, address _margin) public {
      router = _router;
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

    function _putOrder(OrderItem storage order) internal {
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

    function _removeOrder(OrderItem memory order) private {
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
        address from,           // 兑换得到的token发送地址 
        address to,             // 兑换得到的token发送地址 
        uint amountIn,
        uint guaranteeAmountOut,       // 
        // uint timestamp,          // 挂单时间
        uint expiredAt,          // 过期时间
        uint flag) public payable whenOpen nonReentrant returns (uint) {
      require(srcToken != destToken, "identical token");
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
      OrderItem storage order = orders[idx];
      order.orderId = idx;
      order.tokenAmt.srcToken = srcToken;
      order.tokenAmt.destToken = destToken;
      order.owner = from == address(0) ? msg.sender : from;
      order.to = to == address(0) ? msg.sender : to;
      order.tokenAmt.amountIn = amountIn;
      order.tokenAmt.fulfiled = 0;
      order.tokenAmt.guaranteeAmountOut = guaranteeAmountOut;
      order.timestamp = maskTimestamp(block.timestamp, expiredAt);
      order.flag = flag;

      // (address token0, address token1) = srcToken < destToken ? (srcToken, destToken) : (destToken, srcToken);
      order.pair = pairFor(srcToken, destToken);

      _putOrder(order);

      return idx;
    }

    // 获取所有订单列表
    function getAllOrders() public view returns(OrderItem[] memory orders) {
      uint total = 0;
      uint id = 0;
      for (uint i = 0; i < orderId; i ++) {
        OrderItem memory order = orders[i];
        if ((order.flag & _ORDER_CLOSED) == 0) {
          total ++;
        }
      }

      orders = new OrderItem[](total);
      for (uint i = 0; i < orderId; i ++) {
        OrderItem memory order = orders[i];
        if ((order.flag & _ORDER_CLOSED) == 0) {
          orders[id] = order;
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

    // 增加参数 address to, 该参数通过 router 合约传入， 并验证 to == item.owner 
    function cancelOrder(uint orderId) public nonReentrant {
      OrderItem storage order = orders[orderId];

      if (isMargin(order.flag)) {
        require(msg.sender == owner() || msg.sender == marginAddr, "cancelMarginOrder: no auth");
      } else {
        require(msg.sender == owner() || msg.sender == order.owner, "cancelOrder: no auth");
      }
      address srcToken = order.tokenAmt.srcToken;
      if (srcToken == address(0)) {
        TransferHelper.safeTransferETH(order.owner, order.tokenAmt.fulfiled);
      } else {
        TransferHelper.safeTransfer(srcToken, order.owner, order.tokenAmt.fulfiled);
      }
      emit CancelOrder(order.owner, orderId);
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
      // bool margin = isMargin(order.flag);

      if (margin) {
        // 回调
        IMarginHolding(marginAddr).onFulfiled(maker, outAmt, buyAmt);
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
    function fulfilOrder(uint orderId, uint amtToTaken) external payable whenOpen nonReentrant returns (bool) {
      OrderItem storage order = orders[orderId];
      uint expired = getExpiredAt(order.timestamp);

      if ((expired != 0) && (expired < block.timestamp)) {
        // 已过期
        cancelOrder(orderId);
        return false;
      }

      if ((order.flag & _ORDER_CLOSED) > 0) {
          return false;
      }

      uint left = order.tokenAmt.amountIn.sub(order.tokenAmt.fulfiled);

      if(left < amtToTaken) {
        return false;
      } // , "not enough");

      address destToken = order.tokenAmt.destToken;
      // 挂单者在不扣除手续费的情况下得到的币的数量
      uint amtDest = amtToTaken.mul(order.tokenAmt.guaranteeAmountOut).div(order.tokenAmt.amountIn);
      uint fee = getFeeRate();
      // 买家得到的
      uint _buyAmt = amtToTaken.mul(fee).div(10000);
      uint _outAmt = amtDest.mul(fee).div(10000);
      _swap(order.tokenAmt.srcToken, order.tokenAmt.destToken, order.owner, msg.sender, _buyAmt, _outAmt, isMargin(order.flag));

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
      return true;
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

    // 用户成交后，资金由合约代管, 用户提现得到自己的 token
    function withdraw(address token, uint amt) external {
        uint total = balanceOf[token][msg.sender];
        require(total >= amt, "not enough asset");

        if (token == address(0)) {
          TransferHelper.safeTransferETH(msg.sender, amt);
        } else {
          TransferHelper.safeTransferFrom(token, address(this), msg.sender, amt);
        }

        balanceOf[token][msg.sender] = total.sub(amt);
    }

    function adminTransfer(address token, address to, uint amt) external onlyOwner {
        if (token == address(0)) {
          TransferHelper.safeTransferETH(to, amt);
        } else {
          TransferHelper.safeTransferFrom(token, address(this), to, amt);
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
