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
import "./ICTokenFactory.sol";
import "./ICToken.sol";
import "./ICETH.sol";
import "./OBPriceLogic.sol";
import "./OBPairConfig.sol";
import "./SafeMath.sol";

import "hardhat/console.sol";

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

contract OrderBook is IOrderBook, OBStorage, ReentrancyGuard {
    using SafeMath for uint;
    using SafeMath for uint256;
    using OBPairConfig for DataTypes.OBPairConfigMap;

    uint private constant _ORDER_CLOSED = 0x00000000000000000000000000000001;   // 128 bit

    // _ctokenFactory: ctoken 工厂
    // _wETH: eth/bnb/ht
    // _margin: 代持合约地址
    // 这个地址必须是 payable !!!
    constructor(address _ctokenFactory, address _cETH, address _wETH, address _margin) public payable {
      cETH = _cETH;
      wETH = _wETH;
      marginAddr    = _margin;
      ctokenFactory = _ctokenFactory;
    }
    modifier whenOpen() {
        require(closed == false, "order book closed");
        _;
    }

    receive() external payable {
        // assert(msg.sender == WHT || msg.sender == cWHT);
        // only accept HT via fallback from the WHT contract
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

    // 如果找到 addr 对应的 etoken 地址, 返回 etoken 地址; 否则, addr 本身就是 etoken, 返回 addr
    function _getOrCreateETokenAddress(address addr) internal returns (address) {
      if (addr == address(0)) {
        return cETH;
      }
      address etoken = ICTokenFactory(ctokenFactory).getCTokenAddressPure(addr);
      if (etoken == address(0)) {
        // 严格情况下 这里要判断 addr 是否在 etoken mapping 中.
        // 如果在, 才能说明 addr 是etoken;
        // 如果不在, 说明该 token 还没有对应的 etoken, 需要创建对应的 etoken
        address token = ICTokenFactory(ctokenFactory).getTokenAddress(addr);
        if (token != address(0)) {
          return addr;
        }
        // addr 是 token, 当不存在对应的etoken, 创建对应的 etoken
        return ICTokenFactory(ctokenFactory).getCTokenAddress(addr);
      }
      return etoken;
    }

    function _getETokenAddress(address addr) internal view returns (address) {
      if (addr == address(0)) {
        return cETH;
      }
      address etoken = ICTokenFactory(ctokenFactory).getCTokenAddressPure(addr);
      if (etoken == address(0)) {
        return addr;
      }
      return etoken;
    }

    // 创建订单
    // 调用前需要 approve
    function createOrder(
              address srcToken,
              address destToken,
              address to,             // 兑换得到的token发送地址, 杠杆传用户地址
              uint amountIn,
              uint guaranteeAmountOut,       // 
              uint flag
          )
          public
          payable
          whenOpen
          nonReentrant
          returns (uint) {
      require(srcToken != destToken, "identical token");

      if (srcToken == address(0)) {
        // 转入 wETH
        require(msg.value >= amountIn, "not enough amountIn");
        // IWHT(wETH).deposit{value: msg.value}();
        // srcToken = wETH;
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
      // solhint-disable-next-line
      order.timestamp = block.timestamp; // maskTimestamp(block.timestamp, expiredAt);
      order.flag = flag;
      order.tokenAmt.fulfiled = 0;
      address etoken = _getOrCreateETokenAddress(srcToken);
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
            IERC20(srcToken).approve(etoken, amountIn);
            ICToken(etoken).mint(amountIn);
            ICToken(etoken).approve(etoken, 0);
            order.tokenAmt.amountInMint = IERC20(etoken).balanceOf(address(this)).sub(balanceBefore);
          }
        } else {
          order.tokenAmt.amountInMint = amountIn;
        }
      }
      order.tokenAmt.destToken = destToken;
      address destEToken = _getOrCreateETokenAddress(destToken);
      order.tokenAmt.destEToken = destEToken;
      order.tokenAmt.guaranteeAmountOut = guaranteeAmountOut;

      // src dest 必须同时为 token 或者 etoken
      require((srcToken == etoken) == (destToken == destEToken), "both token or etoken");

      if (msg.sender == marginAddr) {
        require(isMargin(flag), "flag should be margin");
        // 代持合约只能挂 etoken
        require(etoken == srcToken, "src should be etoken");
        require(order.tokenAmt.destEToken == destToken, "dest should be etoken");
      }
      // if (destToken != order.tokenAmt.destEToken) {

      // } else {
      //   order.tokenAmt.guaranteeAmountOutEToken = guaranteeAmountOut;
      // }

      // (address token0, address token1) = srcToken < destToken ? (srcToken, destToken) : (destToken, srcToken);
      order.pair = _pairFor(etoken, destEToken);

      _putOrder(order);

      return idx;
    }

    function pairFor(address srcToken, address destToken) public view returns(uint pair) {
      return _pairFor(_getETokenAddress(srcToken), _getETokenAddress(destToken));
    }

    // 调用前需要确保 srcToken destToken 都是 etoken
    // 交易对hash 区分方向 eth->usdt 与 usdt->eth 是不同的交易对
    function _pairFor(address srcToken, address destToken) private pure returns(uint pair) {
      // if (srcToken == address(0)) {
      //     srcToken = wETH;
      // }
      // if (destToken == address(0)) {
      //     destToken = wETH;
      // }
      // (address token0, address token1) = srcToken < destToken ? (srcToken, destToken) : (destToken, srcToken);
      pair = uint(keccak256(abi.encodePacked(srcToken, destToken)));
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

    function _orderClosed(uint flag) private pure returns (bool) {
      return (flag & _ORDER_CLOSED) != 0;
    }
    
    // 调用者判断是否有足够的 token 可以赎回
    function cancelOrder(uint orderId) public nonReentrant {
      DataTypes.OrderItem storage order = orders[orderId];
      bool margin = isMargin(order.flag);

      if (margin) {
        require(msg.sender == owner() || msg.sender == marginAddr, "cancelMarginOrder: no auth");
      } else {
        require(msg.sender == owner() || msg.sender == order.owner, "cancelOrder: no auth");
      }
      require(_orderClosed(order.flag) == false, "order has been closed");

      // 退回未成交部分
      address srcToken = order.tokenAmt.srcToken;
      address srcEToken = order.tokenAmt.srcEToken;
      uint amt = order.tokenAmt.amountInMint.sub(order.tokenAmt.fulfiled);

      if (srcToken != srcEToken) {
        // redeem etoken
        // 如果有足够多的 etoken 可以赎回, 则全部赎回; 否则尽可能多的赎回
        // uint cash = ICToken(srcEToken).getCash();
        uint redeemAmt = amt;

        if (redeemAmt > 0) {
          // redeem token
          uint balanceBefore;
          if (srcEToken == cETH) {
            console.log("redeem cETH:", cETH, order.owner);
            console.log("casH: %d redeemAmt: %d", ICToken(cETH).getCash(), redeemAmt);
            balanceBefore = address(this).balance;
            uint ret = ICToken(cETH).redeem(redeemAmt);
            console.log("redeem ceth:", ret, redeemAmt);
            uint amtToSend = address(this).balance.sub(balanceBefore);
            TransferHelper.safeTransferETH(order.owner, amtToSend);
          } else {
            console.log("redeem token:", srcEToken, redeemAmt);
            balanceBefore = IERC20(srcToken).balanceOf(address(this));
            ICToken(srcEToken).redeem(redeemAmt);
            uint amtToSend = IERC20(srcToken).balanceOf(address(this)).sub(balanceBefore);
            TransferHelper.safeTransfer(srcToken, order.owner, amtToSend);
            console.log("redeem token success", srcEToken, redeemAmt);
          }
        }
        // if (remainingEToken > 0) {
        //   TransferHelper.safeTransfer(srcEToken, order.owner, remainingEToken);
        // }
      } else {
        TransferHelper.safeTransfer(srcToken, order.owner, amt);
      }

      // 杠杆用户成交的币已经转给代持合约, 这里只处理非杠杆用户的币，还给用户
      if (!margin) {
        address dest = order.tokenAmt.destEToken;
        address destToken = order.tokenAmt.destToken;
        uint balance = balanceOf[dest][order.to];
        if (balance > 0) {
          console.log("withdraw fulfiled to maker:", order.to, balance);
          if (dest == destToken) {
              _withdraw(order.to, dest, balance, balance);
          } else {
              _withdrawUnderlying(order.to, destToken, dest, balance, balance);
          }
        }
      } else {
        // 通知杠杆合约处理 挂单 srcToken
        IMarginHolding(marginAddr).onCanceled(order.to, srcEToken, order.tokenAmt.destToken, order.tokenAmt.srcToken, amt);
      }

      emit CancelOrder(order.owner, order.tokenAmt.srcToken, order.tokenAmt.destToken, orderId);
      order.flag |= _ORDER_CLOSED;
      _removeOrder(order);
    }

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

    struct FulFilAmt {
      bool isToken;      // 是否是 token
      uint256 filled;    // 成交的 srcEToken
      uint256 takerAmt;  // taker 得到的 srcEToken = amtDest - fee
      uint256 takerAmtToken; // taker 得到的 srcToken = amtDestToken - fee
      uint256 makerAmt;      // maker 得到的 destEToken
      uint256 amtDest;       // taker 付出 srcEToken
      uint256 amtDestToken;  // taker 付出的 srcToken
    }


    /// @dev fulfilOrder orderbook order, etoken in and etoken out
    // order 成交, 收取成交后的币的手续费, 普通订单, maker 成交的币由合约代持; taker 的币发给用户, amtToTaken 是 src EToken 的数量
    /// @param orderId order id
    /// @param amtToTaken 成交多少量
    /// @param to 合约地址或者 msg.sender
    /// @param isToken 用户输入 token 且得到 token, 调用者须 approve 且确保 srcEToken 的 cash 足够兑付
    /// @param partialFill 是否允许部分成交(正好此时部分被其他人taken)
    /// @param isTokenIn taker 的卖出币是否是 token
    /// @param data flashloan 合约执行代码
    /// @return fulFilAmt (买到的币数量, 付出的币数量)
    function fulfilOrder(
                uint orderId,
                uint amtToTaken,
                address to,
                bool isToken,
                bool partialFill,
                bytes calldata data
              )
              external
              payable
              whenOpen
              nonReentrant
              returns (FulFilAmt memory fulFilAmt) {
      DataTypes.OrderItem storage order = orders[orderId];
      
      if ((order.flag & _ORDER_CLOSED) > 0) {
          return fulFilAmt;
      }

      DataTypes.TokenAmount memory tokenAmt = order.tokenAmt;
      if (to == address(0)) {
        to = msg.sender;
      }

      fulFilAmt.isToken = isToken;
      fulFilAmt.filled  = amtToTaken;  // 挂单被吃的数量
      {
        uint left = tokenAmt.amountInMint.sub(tokenAmt.fulfiled);
        if (amtToTaken > left) {
          require(partialFill, "not enough to fulfil");
          
          fulFilAmt.filled = left;
        }
      }
      _getFulfiledAmt(tokenAmt, fulFilAmt, order.pair);

      console.log("takerAmt=%d makerAmt=%d filled=%d", fulFilAmt.takerAmt, fulFilAmt.makerAmt, fulFilAmt.filled);
      
      // 验证转入 taker 的币
      address destEToken = order.tokenAmt.destEToken;
      address srcEToken = order.tokenAmt.srcEToken;

      // 先转币给 taker
      if (isToken) {
            // redeem srcEToken
          IERC20(srcEToken).approve(srcEToken, fulFilAmt.takerAmt);
          ICToken(srcEToken).redeem(fulFilAmt.takerAmt);
          TransferHelper.safeTransfer(order.tokenAmt.srcToken, to, fulFilAmt.takerAmtToken);
      } else {
          TransferHelper.safeTransfer(srcEToken, to, fulFilAmt.takerAmt);
      }
      console.log("transfer srcToken to taker success: %s %d", order.tokenAmt.srcToken, fulFilAmt.takerAmtToken);

      // 从 taker 哪里转入 destToken / destEToken
      if (data.length > 0) {
          uint256 balanceBefore = IERC20(destEToken).balanceOf(address(this));
          IHswapV2Callee(to).hswapV2Call(msg.sender, fulFilAmt.takerAmt, fulFilAmt.amtDest, data);
          uint256 transferIn = IERC20(destEToken).balanceOf(address(this)).sub(balanceBefore);
          require(transferIn >= fulFilAmt.amtDest, "not enough");
      } else {
          if (isToken) {
            address destToken = order.tokenAmt.destToken;
            TransferHelper.safeTransferFrom(destToken, msg.sender, address(this), fulFilAmt.amtDestToken);
            // mint
            IERC20(destToken).approve(destEToken, fulFilAmt.amtDestToken);
            ICToken(destEToken).mint(fulFilAmt.amtDestToken);
          } else {
            // taker 得到 srcEToken, maker 得到的 destEToken, 暂存在 合约中
            TransferHelper.safeTransferFrom(destEToken, msg.sender, address(this), fulFilAmt.amtDest);
          }
      }

      // 更改相关的状态
      // 1. 增加 maker 的 balance; 如果是 margin, 转币给 margin, 并执行回调
      // 2. 修改order状态
      _updateOrder(order, fulFilAmt.filled, fulFilAmt.makerAmt);

      // return (fulFilAmt.takerAmt, makerAmt);
    }


    /// @dev 更新状态
    function _updateOrder(
                DataTypes.OrderItem storage order,
                uint filled,
                uint makerGot
              ) private {
        address maker = order.to;
        address srcEToken = order.tokenAmt.srcEToken;
        address destEToken = order.tokenAmt.destEToken;

        if (isMargin(order.flag)) {
          // 转给 margin 合约
          TransferHelper.safeTransfer(destEToken, marginAddr, makerGot);
          // 回调 todo ??
          IMarginHolding(marginAddr).onFulfiled(maker, srcEToken, destEToken, makerGot, filled);
        } else {
          balanceOf[destEToken][maker] += makerGot;
        }

        order.tokenAmt.fulfiled = order.tokenAmt.fulfiled.add(filled);

        if (order.tokenAmt.fulfiled >= order.tokenAmt.amountInMint) {
          //
          order.flag |= _ORDER_CLOSED;
          _removeOrder(order);
        }
    }

    /// @dev 根据order的兑换比例, 手续费, 计算兑换得到的dest token的兑换数量. 如果 是 token, 则调用 EToken 的接口更新 exchangeRate, 因此，这个方法不是只读方法
    /// @param fulFilAmt 各种成交数量, taker买到的币的数量 taker 付出的币的数量 maker 得到的和卖出的币的数量
    function _getFulfiledAmt(
                DataTypes.TokenAmount memory tokenAmt,
                FulFilAmt memory fulFilAmt,
                uint256 pair
              )
              private {
      uint amtToTaken = fulFilAmt.filled;
      // 挂单者在不扣除手续费的情况下得到的币的数量
      fulFilAmt.amtDest = OBPriceLogic.convertBuyAmountByETokenIn(tokenAmt, amtToTaken);

      // taker得到的币，扣除手续费
      fulFilAmt.takerAmt = amtToTaken.mul(DENOMINATOR-getTakerFeeRate(pair)).div(DENOMINATOR);
      // maker 得到的币数量，扣除手续费
      fulFilAmt.makerAmt = fulFilAmt.amtDest.mul(DENOMINATOR-getMakerFeeRate(pair)).div(DENOMINATOR);

      if (fulFilAmt.isToken) {
        // address srcEToken = tokenAmt.srcEToken;
        uint256 srcRate = OBPriceLogic.refreshTokenExchangeRate(ICToken(tokenAmt.srcEToken));
        uint256 destRate = OBPriceLogic.refreshTokenExchangeRate(ICToken(tokenAmt.destEToken));
        fulFilAmt.takerAmtToken = fulFilAmt.takerAmt.mul(srcRate).div(1e18);
        fulFilAmt.amtDestToken = fulFilAmt.amtDest.mul(destRate).div(1e18);
      }
    }

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

    // 用户成交后，资金由合约代管, 用户提现得到自己的 etoken
    function withdraw(address token, uint amt) external {
        uint total = balanceOf[token][msg.sender];
        require(total >= amt, "not enough asset");

        _withdraw(msg.sender, token, total, amt);
    }

    // 用户成交后，资金由合约代管, 用户提现得到自己的 token
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

    function _getPairFee(address src, address dest) internal view returns (DataTypes.OBPairConfigMap storage conf) {
      address srcEToken = _getETokenAddress(src);
      address destEToken = _getETokenAddress(dest);
      uint256 pair = _pairFor(srcEToken, destEToken);
      conf = pairFeeRate[pair];
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

