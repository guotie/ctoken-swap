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

// import "./Ownable.sol";
import "./OBStorageV1.sol";
import "./ICTokenFactory.sol";
import "./ICToken.sol";
import "./ICETH.sol";
import "./OBPriceLogic.sol";
import "./OBPairConfig.sol";
import "./SafeMath.sol";

// import "hardhat/console.sol";

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
    event CreateOrder(
          address indexed owner,
          address indexed srcToken,
          address indexed destToken,
          uint orderId,
          uint amountIn,
          uint minAmountOut,
          uint flag
        );

    event FulFilOrder(
          address indexed maker,
          address indexed taker,
          uint orderId,
          uint amt,
          uint amtOut
        );
          // uint remaining);

    event CancelOrder(
          address indexed owner,
          address indexed srcToken,
          address indexed destToken,
          uint orderId
        );
    
    event CancelPairMarginOrder(
          address indexed to,
          address indexed srcEToken,
          address indexed dstEToken,
          uint totalA,
          uint totalB
        );
}

// 挂单合约
contract OrderBook is IOrderBook, OBStorageV1 {
    using SafeMath for uint;
    using SafeMath for uint256;
    using OBPairConfig for DataTypes.OBPairConfigMap;

    // _ctokenFactory: ctoken 工厂
    // _wETH: eth/bnb/ht
    // _margin: 代持合约地址
    // 这个地址必须是 payable !!!
    constructor(address _ctokenFactory, address _cETH, address _wETH, address _margin) public payable {
      cETH = _cETH;
      wETH = _wETH;
      marginAddr    = _margin;
      ctokenFactory = _ctokenFactory;
      feeTo = msg.sender;
    }

    modifier whenOpen() {
        require(closed == false, "order book closed");
        _;
    }

    receive() external payable {
        //  cETH 中赎回
        // assert(msg.sender == cWHT);
        // only accept HT via fallback from the WHT contract
    }

    function _putOrder(DataTypes.OrderItem storage order) internal {
      uint orderId = order.orderId;
      uint flag = order.flag;
      bool margin = isMargin(flag);
      uint addrIdx;
      uint pairIdx;
      address owner = order.owner;

      if (margin) {
          // margin 订单取 to 地址
          owner = order.to;
          addrIdx = marginOrders[owner].length;
          marginOrders[owner].push(orderId);
      } else {
          addrIdx = addressOrders[owner].length;
          addressOrders[owner].push(orderId);
      }

      pairIdx = pairOrders[order.pair].length;
      pairOrders[order.pair].push(orderId);

      order.pairAddrIdx = maskAddrPairIndex(pairIdx, addrIdx);

      emit CreateOrder(owner,
          order.tokenAmt.srcToken,
          order.tokenAmt.destToken,
          orderId,
          order.tokenAmt.amountIn,
          order.tokenAmt.guaranteeAmountOut,
          flag);
    }

    function _removeOrder(DataTypes.OrderItem memory order) private {
        // uint orderId = order.orderId;
        uint pairIdx = pairIndex(order.pairAddrIdx);
        uint addrIdx = addrIndex(order.pairAddrIdx);
        address owner = order.owner;
        uint rIdx;
        bool margin = isMargin(order.flag);

        if (margin) {
            owner = order.to;
            uint lastIdx = marginOrders[owner].length-1;
            if (addrIdx != lastIdx) {
              rIdx = marginOrders[owner][lastIdx];
              marginOrders[owner][addrIdx] = rIdx;
              orders[rIdx].pairAddrIdx = updateAddrIdx(orders[rIdx].pairAddrIdx, addrIdx);
            }
            marginOrders[owner].pop();

            // 用户订单量减少1
            marginUserOrderCount[owner][order.pair] --;
        } else {
            uint lastIdx = addressOrders[owner].length-1;
            if (addrIdx != lastIdx) {
              rIdx = addressOrders[owner][lastIdx];
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
      if (addr == address(0) || addr == wETH) {
        return cETH;
      }
      address etoken = ICTokenFactory(ctokenFactory).getCTokenAddressPure(addr);
      if (etoken == address(0)) {
        // 这里要判断 addr 是否在 etoken mapping 中.
        // 如果在, 才能说明 addr 是 etoken;
        // 如果不在, 说明该 token 还没有对应的 etoken, 需要创建对应的 etoken
        address token = ICTokenFactory(ctokenFactory).getTokenAddress(addr);
        if (token != address(0)) {
          return addr;
        }
        // addr 是 token, 当不存在对应的 etoken, 创建对应的 etoken
        return ICTokenFactory(ctokenFactory).getCTokenAddress(addr);
      }
      return etoken;
    }

    function _getETokenAddress(address addr) internal view returns (address) {
      if (addr == address(0) || addr == wETH) {
        return cETH;
      }
      address etoken = ICTokenFactory(ctokenFactory).getCTokenAddressPure(addr);
      if (etoken == address(0)) {
        return addr;
      }
      return etoken;
    }

    // 判断订单是否是 杠杆订单, 是否是close状态
    function isOrderMarginClosed(uint id) external view returns (bool marginOrder, bool closed) {
      require(id < orderId, "invalid id");

      uint flag = orders[id].flag;
      marginOrder = isMargin(flag);
      closed = _orderClosed(flag);
    }

    // 创建订单
    // 调用前需要 approve
    function createOrder(
              address srcToken,
              address destToken,
              address to,             // 兑换得到的 token 发送地址, 杠杆传用户地址
              uint amountIn,
              uint guaranteeAmountOut,       // 
              uint flag
          )
          public
          payable
          whenOpen
          nonReentrant
          returns (uint idx) {
      require(srcToken != destToken, "identical token");

      idx = orderId ++;
      DataTypes.OrderItem storage order = orders[idx];
      order.orderId = idx;
      order.owner = msg.sender;
      order.to = to == address(0) ? msg.sender : to;
      // solhint-disable-next-line
      order.timestamp = block.timestamp; // maskTimestamp(block.timestamp, expiredAt);
      order.flag = flag;
      order.tokenAmt.fulfiled = 0;

      if (srcToken == address(0)) {
        // 转入 wETH
        require(msg.value >= amountIn, "not enough amountIn");
        // IWHT(wETH).deposit{value: msg.value}();
        // srcToken = wETH;
      } else {
        // should approve outside
        TransferHelper.safeTransferFrom(srcToken, msg.sender, address(this), amountIn);
      }

      address etoken = _getOrCreateETokenAddress(srcToken);
      {
        order.tokenAmt.srcToken = srcToken;
        order.tokenAmt.srcEToken = etoken;
        order.tokenAmt.amountIn = amountIn;
        if (srcToken != etoken) {
          // order.isEToken = true;
          // mint to etoken
          if (srcToken == address(0)) {
            // uint balanceBefore = IERC20(cETH).balanceOf(address(this));
            (uint err, uint amt) = ICETH(cETH).mint{value: msg.value}();
            require(err == 0, "mint failed");
            order.tokenAmt.amountInMint = amt; // IERC20(cETH).balanceOf(address(this)).sub(balanceBefore);
          } else {
            // uint balanceBefore = IERC20(etoken).balanceOf(address(this));
            IERC20(srcToken).approve(etoken, amountIn);
            (uint err, uint amt) = ICToken(etoken).mint(amountIn);
            ICToken(etoken).approve(etoken, 0);
            require(err == 0, "mint failed");
            order.tokenAmt.amountInMint = amt; // IERC20(etoken).balanceOf(address(this)).sub(balanceBefore);
          }
        } else {
          order.tokenAmt.amountInMint = amountIn;
        }
      }

      {
        // 最低挂单量限制
        require(order.tokenAmt.amountInMint > minAmounts[etoken], "less than min amount");
      }

      order.tokenAmt.destToken = destToken;
      address destEToken = _getOrCreateETokenAddress(destToken);
      order.tokenAmt.destEToken = destEToken;
      order.tokenAmt.guaranteeAmountOut = guaranteeAmountOut;

      // src dest 必须同时为 token 或者 etoken
      require((srcToken == etoken) == (destToken == destEToken), "both token or etoken");

      order.pair = _pairFor(etoken, destEToken);
      // 严格限制
      // margin 合约地址的挂单必须是 杠杆订单, 且, 杠杆订单必须是 margin 合约地址发起
      if (msg.sender == marginAddr) {
        require(isMargin(flag), "flag should be margin");
        // 代持合约只能挂 etoken
        require(etoken == srcToken, "src should be etoken");
        require(to != msg.sender, "to should be user's address");
        require(order.tokenAmt.destEToken == destToken, "dest should be etoken");
        // 校验是否超过该用户的最大订单数量
        uint count = marginUserOrderCount[to][order.pair];
        require(count < maxMarginOrder, "order count");
        marginUserOrderCount[to][order.pair] = count + 1;
      } else {
        require(isMargin(flag) == false, "should not be margin flag");
      }

      // 授权 省去后续 cancel withdraw 授权的麻烦
      if (IERC20(destEToken).allowance(address(this), destEToken) < _HALF_MAX_UINT) {
          IERC20(destEToken).approve(destEToken, uint(-1));
      }
      if (IERC20(etoken).allowance(address(this), etoken) < _HALF_MAX_UINT) {
          IERC20(etoken).approve(destEToken, uint(-1));
      }

      _putOrder(order);
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
    // 订单数过多的情况, 可能会爆掉
    function getAllOrders(uint startIdx, uint endIdx) external view returns(DataTypes.OrderItem[] memory allOrders) {
      uint total = 0;
      if (endIdx == 0) {
        endIdx = orderId;
      }
      for (uint i = startIdx; i < endIdx; i ++) {
        uint flag = orders[i].flag;
        if (_orderClosed(flag) == false) {
          total ++;
        }
      }

      allOrders = new DataTypes.OrderItem[](total);
      uint id = 0;
      for (uint i = startIdx; i < endIdx; i ++) {
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
    
    /// @dev 赎回 etoken
    function _redeemTransfer(
                    address token,
                    address etoken,
                    address to,
                    uint256 redeemAmt
                ) private {
        // console.log("redeemAmt:", redeemAmt);
        (uint ret, , uint amt) = ICToken(etoken).redeem(redeemAmt);
        require(ret == 0, "redeem failed");

        if (token == address(0)) {
            TransferHelper.safeTransferETH(to, amt); // address(this).balance);
        } else {
            // console.log("redeem token amt:", redeemAmt, amt, IERC20(token).balanceOf(address(this)));
            TransferHelper.safeTransfer(token, to, amt); // IERC20(token).balanceOf(address(this)));
        }
    }

    // 取消用户所有的杠杆订单
    function cancelPairMarginOrders(address etokenA, address etokenB, address to) public nonReentrant {
      require(msg.sender == marginAddr, "not margin addr");

      uint pairA = _pairFor(etokenA, etokenB);
      uint pairB = _pairFor(etokenB, etokenA);

      // 状态变量赋值给 memory 局部变量, copy 操作
      uint[] memory orderIds = marginOrders[to];
      uint totalA;
      uint totalB;

      // 没有订单
      if (orderIds.length == 0) {
        return;
      }

      for (uint i = 0; i < orderIds.length; i ++) {
        // 状态变量赋值给 storage 局部变量, 引用
        DataTypes.OrderItem storage order = orders[orderIds[i]];
        uint _pair = order.pair;
        if (_pair == pairA) {
          totalA += order.tokenAmt.amountInMint.sub(order.tokenAmt.fulfiled);
          // totalA += amt;
          order.flag |= _ORDER_CLOSED;
          _removeOrder(order);
        } else if (_pair == pairB) {
          totalB += order.tokenAmt.amountInMint.sub(order.tokenAmt.fulfiled);
          order.flag |= _ORDER_CLOSED;
          _removeOrder(order);
        }
      }

      if (totalA > 0) {
        TransferHelper.safeTransfer(etokenA, marginAddr, totalA);
        IMarginHolding(marginAddr).onCanceled(to, etokenA, etokenB, etokenA, totalA);
      }
      if (totalB > 0) {
        TransferHelper.safeTransfer(etokenB, marginAddr, totalB);
        IMarginHolding(marginAddr).onCanceled(to, etokenB, etokenA, etokenB, totalB);
      }

      emit CancelPairMarginOrder(
                  to,
                  etokenA,
                  etokenB,
                  totalA,
                  totalB
              );
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
      // console.log("cancel order: srcEToken amt=%d", amt);

      if (amt > 0) {
        if (srcToken != srcEToken) {
          _redeemTransfer(srcToken, srcEToken, order.owner, amt);
          // console.log("redeem transfer ok");
        } else {
          TransferHelper.safeTransfer(srcToken, order.owner, amt);
        }
      }

      // 杠杆用户成交的币已经转给代持合约, 这里只处理非杠杆用户的币，还给用户
      if (!margin) {
        address dest = order.tokenAmt.destEToken;
        address destToken = order.tokenAmt.destToken;
        uint balance = balanceOf[dest][order.to];
        if (balance > 0) {
          // console.log("withdraw fulfiled to maker:", order.to, balance);
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

      order.flag |= _ORDER_CLOSED;
      _removeOrder(order);

      emit CancelOrder(
                  order.owner,
                  order.tokenAmt.srcToken,
                  order.tokenAmt.destToken,
                  orderId
              );
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

    struct FulFilAmt {
      bool isToken;        // 是否是 token
      address srcEToken;   // 挂单的 src etoken, taker 得到的币, maker 付出的币
      address destEToken;  // 挂单的 dest etoken, taker 付出的币, makeer 得到的币
      uint256 filled;      // 成交的 srcEToken
      uint256 takerFee;    // taker 手续费
      uint256 makerFee;    // maker 手续费
      uint256 takerAmt;    // taker 得到的 srcEToken = amtDest - fee
      uint256 takerAmtToken; // taker 得到的 srcToken = amtDestToken - fee
      uint256 makerAmt;      // maker 得到的 destEToken
      uint256 amtDest;       // taker 付出 srcEToken
      uint256 amtDestToken;  // taker 付出的 srcToken
    }

    // todo 限制最大交易的订单数量
    // todo 测试最多一次能吃多少个单子
    function fulfilOrders(
                uint[] memory orderIds,
                uint[] memory amtToTakens,
                address to,
                bool isToken,
                bool partialFill,
                bytes calldata data
              )
              external
              payable
              whenOpen {
        require(orderIds.length == amtToTakens.length, "invalid param");

        for (uint i = 0; i < orderIds.length; i ++) {
          fulfilOrder(orderIds[i], amtToTakens[i], to, isToken, partialFill, data);
        }
    }

    /// @dev 根据 order id 返回该 order 的信息
    /// @param id order id
    /// @return srcEToken 对于挂单者来说, 卖出币种; 对于吃单者来说, 买入币种
    /// @return destEToken 对于挂单者来说, 买入币种; 对于吃单者来说, 卖出币种
    /// @return amtIn 对于挂单者来说, 卖出的 etoken 数量
    /// @return fulfiled 对于挂单者来说, srcEToken 已成交的数量
    /// @return amtOut 对于挂单者来说, 要得到的 etoken 数量(未扣除挂单手续费)
    function getOrderTokens(uint id) public view returns (address srcEToken, address destEToken, uint amtIn, uint fulfiled, uint amtOut) {
      DataTypes.OrderItem memory order = orders[id];

      srcEToken = order.tokenAmt.srcEToken;
      destEToken = order.tokenAmt.destEToken;
      amtIn = order.tokenAmt.amountInMint;
      fulfiled = order.tokenAmt.fulfiled;
      amtOut = order.tokenAmt.guaranteeAmountOut;
    }

    /// @dev fulfilOrder orderbook order, etoken in and etoken out
    // order 成交, 收取成交后的币的手续费, 普通订单, maker 成交的币由合约代持; taker 的币发给用户, amtToTaken 是 src EToken 的数量
    /// @param orderId order id
    /// @param amtToTaken 成交多少量 (etoken)
    /// @param to 合约地址或者 msg.sender
    /// @param isToken 用户输入 token 且得到 token, 调用者须 approve 且确保 srcEToken 的 cash 足够兑付
    /// @param partialFill 是否允许部分成交(正好此时部分被其他人taken)
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
              public
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
      fulFilAmt.srcEToken = order.tokenAmt.srcEToken;
      fulFilAmt.destEToken = order.tokenAmt.destEToken;
      {
        uint left = tokenAmt.amountInMint.sub(tokenAmt.fulfiled);
        if (amtToTaken > left) {
          require(partialFill, "not enough to fulfil");
          
          fulFilAmt.filled = left;
        }
      }
      _getFulfiledAmt(tokenAmt, fulFilAmt, order.pair);

      // console.log("takerAmt=%d makerAmt=%d filled=%d", fulFilAmt.takerAmt, fulFilAmt.makerAmt, fulFilAmt.filled);
      
      // 验证转入 taker 的币
      address destEToken = tokenAmt.destEToken;
      address srcEToken = tokenAmt.srcEToken;

      // 先转币给 taker
      if (isToken) {
            // redeem srcEToken
          // IERC20(srcEToken).approve(srcEToken, fulFilAmt.takerAmt);
          // uint ret = ICToken(srcEToken).redeem(fulFilAmt.takerAmt);
          // require(ret == 0, "redeem failed");
          // TransferHelper.safeTransfer(tokenAmt.srcToken, to, fulFilAmt.takerAmtToken);
          _redeemTransfer(tokenAmt.srcToken, srcEToken, to, fulFilAmt.takerAmt);
      } else {
          TransferHelper.safeTransfer(srcEToken, to, fulFilAmt.takerAmt);
      }
      // console.log("transfer srcToken to taker success: %s %d %d", tokenAmt.srcToken, fulFilAmt.takerAmt, fulFilAmt.takerAmtToken);

      // 从 taker 哪里转入 destToken / destEToken
      if (data.length > 0) {
          uint256 balanceBefore = IERC20(destEToken).balanceOf(address(this));
          IHswapV2Callee(to).hswapV2Call(msg.sender, fulFilAmt.takerAmt, fulFilAmt.amtDest, data);
          uint256 transferIn = IERC20(destEToken).balanceOf(address(this)).sub(balanceBefore);
          require(transferIn >= fulFilAmt.amtDest, "not enough");
      } else {
          if (isToken) {
            address destToken = tokenAmt.destToken;
            TransferHelper.safeTransferFrom(destToken, msg.sender, address(this), fulFilAmt.amtDestToken);
            // mint
            IERC20(destToken).approve(destEToken, fulFilAmt.amtDestToken);
            (uint ret, ) = ICToken(destEToken).mint(fulFilAmt.amtDestToken);
            require(ret == 0, "mint failed");
          } else {
            // taker 得到 srcEToken, maker 得到的 destEToken, 暂存在 合约中
            TransferHelper.safeTransferFrom(destEToken, msg.sender, address(this), fulFilAmt.amtDest);
          }
      }

      // 将手续费转给 feeTo
      if (fulFilAmt.takerFee > 0) {
        TransferHelper.safeTransfer(srcEToken, feeTo, fulFilAmt.takerFee);
      }
      if (fulFilAmt.makerFee > 0) {
        TransferHelper.safeTransfer(destEToken, feeTo, fulFilAmt.makerFee);
      }

      // 更改相关的状态
      // 1. 增加 maker 的 balance; 如果是 margin, 转币给 margin, 并执行回调
      // 2. 修改order状态
      _updateOrder(order, fulFilAmt.filled, fulFilAmt.makerAmt);

      emit FulFilOrder(
              order.owner,
              msg.sender,
              orderId,
              fulFilAmt.filled,
              fulFilAmt.amtDest
            );
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

        // 已成交
        order.tokenAmt.fulfiled = order.tokenAmt.fulfiled.add(filled);
        order.tokenAmt.destFulfiled = order.tokenAmt.destFulfiled.add(makerGot);

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

      fulFilAmt.takerFee = amtToTaken.mul(getTakerFeeRate(pair)).div(DENOMINATOR);
      fulFilAmt.makerFee = amtToTaken.mul(getMakerFeeRate(pair)).div(DENOMINATOR);
      // taker得到的币，扣除手续费
      fulFilAmt.takerAmt = amtToTaken.sub(fulFilAmt.takerFee);
      // maker 得到的币数量，扣除手续费
      fulFilAmt.makerAmt = fulFilAmt.amtDest.sub(fulFilAmt.makerFee);

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

        _redeemTransfer(token, etoken, user, amt);
    }

    // 用户成交后，资金由合约代管, 用户提现得到自己的 etoken
    function withdraw(address etoken, uint amt) external whenOpen {
        uint total = balanceOf[etoken][msg.sender];
        require(total > 0, "no asset");
        if (amt == 0) {
            amt = total;
        } else {
            require(total >= amt, "not enough asset");
        }

        _withdraw(msg.sender, etoken, total, amt);
    }

    // 用户成交后，资金由合约代管, 用户提现得到自己的 token
    function withdrawUnderlying(address token, uint amt) external whenOpen {
        address etoken = _getETokenAddress(token);
        uint total = balanceOf[etoken][msg.sender];

        require(total > 0, "no asset");
        if (amt == 0) {
            amt = total;
        } else {
            require(total >= amt, "not enough asset");
        }

        _withdrawUnderlying(msg.sender, token, etoken, total, amt);
    }

    // 关闭 挂单 合约
    function closeOrderBook() external onlyOwner {
      closed = true;
    }

    function openOrderBook() external onlyOwner {
      closed = false;
    }

    // 设置某个 token 的最低挂单量, 参数为 etoken, 非 token
    function setMinOrderAmount(address etoken, uint amt) external onlyOwner {
      minAmounts[etoken] = amt;
    }

    /// @dev 设置 feeTo 地址
    function setFeeTo(address to) external onlyOwner {
      feeTo = to;
    }

    function _getPairFee(address src, address dest) internal view returns (DataTypes.OBPairConfigMap storage conf) {
      address srcEToken = _getETokenAddress(src);
      address destEToken = _getETokenAddress(dest);
      uint256 pair = _pairFor(srcEToken, destEToken);
      conf = pairFeeRate[pair];
      return conf;
    }

    // pair 吃单手续费
    function setPairTakerFee(address src, address dest, uint fee) external onlyOwner {
      DataTypes.OBPairConfigMap storage conf = _getPairFee(src, dest);

      conf.setFeeTaker(fee);
    }
    
    // pair 挂单手续费
    function setPairMakerFee(address src, address dest, uint fee) external onlyOwner {
      DataTypes.OBPairConfigMap storage conf = _getPairFee(src, dest);

      conf.setFeeMaker(fee);
    }

    // 杠杆用户单交易对最大挂单数量
    function setMaxOrderCount(uint count) external onlyOwner {
      maxMarginOrder = count;
    }

    // 设置杠杆合约地址
    function setMarginAddr(address addr) external onlyOwner {
      marginAddr = addr;
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

