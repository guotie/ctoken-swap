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

import "../../proxy/Initializable.sol";

// import "../../compound/ErrorReporter.sol";

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
  // owner: ????????????
  // fulfiled: ?????????token??????(tokenIn)
  // amt: ?????????token??????(tokenOut)
  function onFulfiled(address owner, address tokenOut, address tokenIn, uint fulfiled, uint amt) external;
  // tokenOut: ??????????????? srcToken
  // tokenIn: ??????????????? destToken
  // tokenReturn: tokenOut
  // amt: ?????????tokenOut??????
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

// ????????????
contract OrderBook is Initializable, IOrderBook, OBStorageV1 {
    using SafeMath for uint;
    using SafeMath for uint256;
    using OBPairConfig for DataTypes.OBPairConfigMap;

    // constructor(address _ctokenFactory, address _cETH, address _wETH, address _margin) public {
    //   cETH = _cETH;
    //   wETH = _wETH;
    //   marginAddr    = _margin;
    //   ctokenFactory = _ctokenFactory;
    //   _notEntered = true;
    // }

    // _ctokenFactory: ctoken ??????
    // _wETH: eth/bnb/ht
    // _margin: ??????????????????
    function initialize(address _ctokenFactory, address _cETH, address _wETH, address _margin) public initializer {
      cETH = _cETH;
      wETH = _wETH;
      marginAddr    = _margin;
      ctokenFactory = _ctokenFactory;
      _notEntered = true;
      _upgradeableOwnable();
    }
    // function initialize() public initializer {
    //   _notEntered = true;
    // }

    modifier whenOpen() {
        require(closed == false, "order book closed");
        _;
    }

    receive() external payable {
        //  cETH ?????????
        // assert(msg.sender == cWHT);
        // only accept HT via fallback from the WHT contract
    }

    uint public constant VERSION = 0x1;

    function _putOrder(DataTypes.OrderItem storage order) internal {
      uint orderId = order.orderId;
      uint flag = order.flag;
      bool margin = isMargin(flag);
      uint addrIdx;
      uint pairIdx;
      address owner = order.owner;

      if (margin) {
          // margin ????????? to ??????
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
          order.tokenAmt.amountOut,
          order.tokenAmt.guaranteeAmountIn,
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

            // ?????????????????????1
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

    // ???????????? addr ????????? etoken ??????, ?????? etoken ??????; ??????, addr ???????????? etoken, ?????? addr
    function _getOrCreateETokenAddress(address addr) internal returns (address) {
      if (addr == address(0) || addr == wETH) {
        return cETH;
      }
      address etoken = ICTokenFactory(ctokenFactory).getCTokenAddressPure(addr);
      if (etoken == address(0)) {
        // ??????????????? addr ????????? etoken mapping ???.
        // ?????????, ???????????? addr ??? etoken;
        // ????????????, ????????? token ?????????????????? etoken, ????????????????????? etoken
        address token = ICTokenFactory(ctokenFactory).getTokenAddress(addr);
        if (token != address(0)) {
          return addr;
        }
        // addr ??? token, ????????????????????? etoken, ??????????????? etoken
        return ICTokenFactory(ctokenFactory).getCTokenAddress(addr);
      }
      return etoken;
    }

    // ?????? token ???????????? etoken ??????
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

    // ?????? etoken ???????????? token ??????
    function  _getTokenAddress(address addr) internal view returns (address) {
      if (addr == cETH) {
        return address(0);
      }
      address token = ICTokenFactory(ctokenFactory).getTokenAddress(addr);
      require(token != address(0), "invalid etoken");
      return token;
    }

    // ????????????????????? ????????????, ?????????close??????
    function isOrderMarginClosed(uint id) external view returns (bool marginOrder, bool closed) {
      require(id < orderId, "invalid id");

      uint flag = orders[id].flag;
      marginOrder = isMargin(flag);
      closed = _orderClosed(flag);
    }

    // ????????????
    // ??????????????? approve
    function createOrder(
              address srcToken,
              address destToken,
              address to,             // ??????????????? token ????????????, ?????????????????????
              uint amountOut,
              uint guaranteeAmountIn,       // 
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
        // ?????? wETH
        require(msg.value >= amountOut, "not enough amountIn");
        // IWHT(wETH).deposit{value: msg.value}();
        // srcToken = wETH;
      } else {
        // should approve outside
        TransferHelper.safeTransferFrom(srcToken, msg.sender, address(this), amountOut);
      }

      address etoken = _getOrCreateETokenAddress(srcToken);
      {
        order.tokenAmt.srcToken = srcToken;
        order.tokenAmt.srcEToken = etoken;
        order.tokenAmt.amountOut = amountOut;
        if (srcToken != etoken) {
          order.tokenAmt.amountOutMint = _mintEToken(srcToken, etoken, amountOut);
        } else {
          order.tokenAmt.amountOutMint = amountOut;
        }
      }

      {
        // ?????????????????????
        require(order.tokenAmt.amountOutMint > minAmounts[etoken], "less than min amount");
      }

      order.tokenAmt.destToken = destToken;
      address destEToken = _getOrCreateETokenAddress(destToken);
      order.tokenAmt.destEToken = destEToken;
      order.tokenAmt.guaranteeAmountIn = guaranteeAmountIn;

      // src dest ??????????????? token ?????? etoken
      require((srcToken == etoken) == (destToken == destEToken), "both token or etoken");

      order.pair = _pairFor(etoken, destEToken);
      // ????????????
      // margin ?????????????????????????????? ????????????, ???, ????????????????????? margin ??????????????????
      if (msg.sender == marginAddr) {
        require(isMargin(flag), "flag should be margin");
        // ????????????????????? etoken
        require(etoken == srcToken, "src should be etoken");
        require(to != msg.sender, "to should be user's address");
        require(order.tokenAmt.destEToken == destToken, "dest should be etoken");
        // ????????????????????????????????????????????????
        uint count = marginUserOrderCount[to][order.pair];
        require(count < maxMarginOrder, "order count");
        marginUserOrderCount[to][order.pair] = count + 1;
      } else {
        require(isMargin(flag) == false, "should not be margin flag");
      }

      // ?????? ???????????? cancel withdraw ???????????????
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

    function pairForEToken(address srcEToken, address destEToken) public pure returns(uint pair) {
      return _pairFor(srcEToken, destEToken);
    }

    // ????????????????????? srcToken destToken ?????? etoken
    // ?????????hash ???????????? eth->usdt ??? usdt->eth ?????????????????????
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

    // ????????????????????????
    // ????????????????????????, ???????????????
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


    // 
    function _mintEToken(address token, address etoken, uint256 tokenAmt) private returns (uint mintAmt) {
      uint err;
      require(token != etoken, "token equal etoken");

      if (token == address(0)) {
        // uint balanceBefore = IERC20(cETH).balanceOf(address(this));
        (err, mintAmt) = ICETH(cETH).mint{value: tokenAmt}();
      } else {
        // uint balanceBefore = IERC20(etoken).balanceOf(address(this));
        IERC20(token).approve(etoken, tokenAmt);
        (err, mintAmt) = ICToken(etoken).mint(tokenAmt);
      }
      require(err == 0, "mint failed");
    }

    /// @dev ?????? etoken
    function _redeemTransfer(
                    address token,
                    address etoken,
                    address to,
                    uint256 redeemAmt
                ) private {
        require(token != etoken, "token should not equal etoken");
        // console.log("redeemAmt:", redeemAmt);

        (uint ret, uint amt, ) = ICToken(etoken).redeem(redeemAmt);
        // ?????????????????? token ???????????????, ??? etoken ??? to
        // TokenErrorReporter Error.TOKEN_INSUFFICIENT_CASH
        require(ret == 0 || ret == 14, "redeem failed");
        if (ret == 14) {
          // not enough token
          TransferHelper.safeTransfer(etoken, to, redeemAmt);
          return;
        }

        if (token == address(0)) {
            TransferHelper.safeTransferETH(to, amt); // address(this).balance);
        } else {
            // console.log("redeem token amt:", redeemAmt, amt, IERC20(token).balanceOf(address(this)));
            TransferHelper.safeTransfer(token, to, amt); // IERC20(token).balanceOf(address(this)));
        }
    }

    // ?????????????????????????????????
    function cancelPairMarginOrders(address etokenA, address etokenB, address to) public nonReentrant {
      require(msg.sender == marginAddr, "not margin addr");

      uint pairA = _pairFor(etokenA, etokenB);
      uint pairB = _pairFor(etokenB, etokenA);

      // ????????????????????? memory ????????????, copy ??????
      uint[] memory orderIds = marginOrders[to];
      uint totalA;
      uint totalB;

      // ????????????
      if (orderIds.length == 0) {
        return;
      }

      for (uint i = 0; i < orderIds.length; i ++) {
        // ????????????????????? storage ????????????, ??????
        DataTypes.OrderItem storage order = orders[orderIds[i]];
        uint _pair = order.pair;
        if (_pair == pairA) {
          totalA += order.tokenAmt.amountOutMint.sub(order.tokenAmt.fulfiled);
          // totalA += amt;
          order.flag |= _ORDER_CLOSED;
          _removeOrder(order);
        } else if (_pair == pairB) {
          totalB += order.tokenAmt.amountOutMint.sub(order.tokenAmt.fulfiled);
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

    // ????????????????????????????????? token ????????????
    function cancelOrder(uint orderId) public nonReentrant {
      DataTypes.OrderItem storage order = orders[orderId];
      bool margin = isMargin(order.flag);

      if (margin) {
        require(msg.sender == owner() || msg.sender == marginAddr, "cancelMarginOrder: no auth");
      } else {
        require(msg.sender == owner() || msg.sender == order.owner, "cancelOrder: no auth");
      }
      require(_orderClosed(order.flag) == false, "order has been closed");

      // ?????????????????????
      address srcToken = order.tokenAmt.srcToken;
      address srcEToken = order.tokenAmt.srcEToken;
      uint amt = order.tokenAmt.amountOutMint.sub(order.tokenAmt.fulfiled);
      // console.log("cancel order: srcEToken amt=%d", amt);

      if (amt > 0) {
        if (srcToken != srcEToken) {
          _redeemTransfer(srcToken, srcEToken, order.owner, amt);
          // console.log("redeem transfer ok");
        } else {
          TransferHelper.safeTransfer(srcToken, order.owner, amt);
        }
      }

      // ????????????????????????????????????????????????, ???????????????????????????????????????????????????
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
        // ???????????????????????? ?????? srcToken
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
      bool isToken;        // ????????? token
      address srcEToken;   // ????????? src etoken, taker ????????????, maker ????????????
      address destEToken;  // ????????? dest etoken, taker ????????????, makeer ????????????
      uint256 filled;      // ????????? srcEToken
      uint256 takerFee;    // taker ?????????
      uint256 makerFee;    // maker ?????????
      uint256 takerAmt;    // taker ????????? srcEToken = amtToTaken - fee
      uint256 takerAmtToken; // taker ????????? srcToken = takerAmt * srcEToken.exchangeRate
      uint256 makerAmt;      // maker ????????? destEToken
      uint256 amtDest;       // taker ?????? destEToken
      uint256 amtDestToken;  // taker ????????? destToken
    }

    // todo ?????????????????????????????????
    // todo ???????????????????????????????????????
    function fulfilOrders(
                uint[] memory orderIds,
                uint[] memory amtToTakens,
                address to,
                bool isToken,
                bool partialFill
              )
              external
              payable
              whenOpen {
        require(orderIds.length == amtToTakens.length, "invalid param");

        for (uint i = 0; i < orderIds.length; i ++) {
            fulfilOrder(orderIds[i], amtToTakens[i], to, isToken, partialFill, new bytes(0));
        }
    }

    /// @dev ?????? order id ????????? order ?????????
    /// @param id order id
    /// @return srcEToken ?????????????????????, ????????????; ?????????????????????, ????????????
    /// @return destEToken ?????????????????????, ????????????; ?????????????????????, ????????????
    /// @return amtOut ?????????????????????, ????????? etoken ??????
    /// @return fulfiled ?????????????????????, srcEToken ??????????????????
    /// @return guaranteeAmountIn ?????????????????????, ???????????? etoken ??????(????????????????????????)
    function getOrderTokens(uint id)
            public
            view
            returns (address srcEToken, address destEToken, uint amtOut, uint fulfiled, uint guaranteeAmountIn) {
        DataTypes.OrderItem memory order = orders[id];

        srcEToken = order.tokenAmt.srcEToken;
        destEToken = order.tokenAmt.destEToken;
        amtOut = order.tokenAmt.amountOutMint;
        fulfiled = order.tokenAmt.fulfiled;
        guaranteeAmountIn = order.tokenAmt.guaranteeAmountIn;
    }

    /// @dev fulfilOrder orderbook order, etoken in and etoken out
    // order ??????, ?????????????????????????????????, ????????????, maker ???????????????????????????; taker ??????????????????, amtToTaken ??? src EToken ?????????
    /// @param orderId order id
    /// @param amtToTaken ??????????????? (etoken)
    /// @param to ?????????????????? msg.sender
    /// @param isToken ???????????? token ????????? token, ???????????? approve ????????? srcEToken ??? cash ????????????
    /// @param partialFill ????????????????????????(??????????????????????????????taken)
    /// @param data flashloan ??????????????????
    /// @return fulFilAmt (??????????????????, ??????????????????)
    function fulfilOrder(
                uint orderId,
                uint amtToTaken,
                address to,
                bool isToken,
                bool partialFill,
                bytes memory data
              )
              public
              payable
              whenOpen
              nonReentrant
              returns (FulFilAmt memory fulFilAmt) {
      DataTypes.OrderItem storage order = orders[orderId];

      require(amtToTaken > 0, "zero amount");

      if ((order.flag & _ORDER_CLOSED) > 0) {
          return fulFilAmt;
      }

      DataTypes.TokenAmount memory tokenAmt = order.tokenAmt;
      if (to == address(0)) {
          to = msg.sender;
      }

      fulFilAmt.isToken = isToken;
      fulFilAmt.filled  = amtToTaken;  // ?????????????????????
      fulFilAmt.srcEToken = order.tokenAmt.srcEToken;
      fulFilAmt.destEToken = order.tokenAmt.destEToken;
      {
        uint left = tokenAmt.amountOutMint.sub(tokenAmt.fulfiled);
        if (amtToTaken > left) {
          require(partialFill, "not enough to fulfil");
          
          fulFilAmt.filled = left;
        }
      }
      _getFulfiledAmt(tokenAmt, fulFilAmt, order.pair);

      // ???????????? taker ??????
      address destEToken = tokenAmt.destEToken;
      address srcEToken = tokenAmt.srcEToken;

      // ???????????? taker
      if (isToken) {
            // redeem srcEToken
          // IERC20(srcEToken).approve(srcEToken, fulFilAmt.takerAmt);
          // uint ret = ICToken(srcEToken).redeem(fulFilAmt.takerAmt);
          // require(ret == 0, "redeem failed");
          // TransferHelper.safeTransfer(tokenAmt.srcToken, to, fulFilAmt.takerAmtToken);
          address srcToken = tokenAmt.srcToken;
          if (srcEToken == srcToken) {
              srcToken = _getTokenAddress(srcEToken);
          }
          _redeemTransfer(srcToken, srcEToken, to, fulFilAmt.takerAmt);
      } else {
          TransferHelper.safeTransfer(srcEToken, to, fulFilAmt.takerAmt);
      }
      // console.log("transfer srcToken to taker success: %s %d %d", tokenAmt.srcToken, fulFilAmt.takerAmt, fulFilAmt.takerAmtToken);

      // ??? taker ???????????? destToken / destEToken
      if (data.length > 0) {
          uint256 balanceBefore = IERC20(destEToken).balanceOf(address(this));
          IHswapV2Callee(to).hswapV2Call(msg.sender, fulFilAmt.takerAmt, fulFilAmt.amtDest, data);
          uint256 transferIn = IERC20(destEToken).balanceOf(address(this)).sub(balanceBefore);
          require(transferIn >= fulFilAmt.amtDest, "not enough");
      } else {
          if (isToken) {
            address destToken = tokenAmt.destToken;
            if (destEToken == destToken) {
              destToken = _getTokenAddress(destEToken);
            }
            if (destToken == address(0)) {
              // console.log("input eth: %d need: %d", msg.value, fulFilAmt.amtDestToken);
              if (msg.value >= fulFilAmt.amtDestToken) {
                // ???????????? eth ??????
                uint left = msg.value.sub(fulFilAmt.amtDestToken);
                if (left > 0) {
                  TransferHelper.safeTransferETH(msg.sender, left);
                }
              } else {
                revert("not enough eth in");
              }
              // require(msg.value >= , "not enough eth");
            } else {
              TransferHelper.safeTransferFrom(destToken, msg.sender, address(this), fulFilAmt.amtDestToken);
            }
            _mintEToken(destToken, destEToken, fulFilAmt.amtDestToken);
          } else {
            // taker ?????? srcEToken, maker ????????? destEToken, ????????? ?????????
            TransferHelper.safeTransferFrom(destEToken, msg.sender, address(this), fulFilAmt.amtDest);
          }
      }

      // ?????????????????? feeTo
      if (fulFilAmt.takerFee > 0 && feeTo != address(0)) {
        TransferHelper.safeTransfer(srcEToken, feeTo, fulFilAmt.takerFee);
      }
      if (fulFilAmt.makerFee > 0 && feeTo != address(0)) {
        TransferHelper.safeTransfer(destEToken, feeTo, fulFilAmt.makerFee);
      }

      // ?????????????????????
      // 1. ?????? maker ??? balance; ????????? margin, ????????? margin, ???????????????
      // 2. ??????order??????
      _updateOrder(order, fulFilAmt.filled, fulFilAmt.makerAmt);

      emit FulFilOrder(
              order.owner,
              msg.sender,
              orderId,
              fulFilAmt.filled,
              fulFilAmt.amtDest
            );
    }

    /// @dev ????????????
    function _updateOrder(
                DataTypes.OrderItem storage order,
                uint filled,
                uint makerGot
              ) private {
        address maker = order.to;
        address srcEToken = order.tokenAmt.srcEToken;
        address destEToken = order.tokenAmt.destEToken;

        if (isMargin(order.flag)) {
          // ?????? margin ??????
          TransferHelper.safeTransfer(destEToken, marginAddr, makerGot);
          // ?????? todo ??
          IMarginHolding(marginAddr).onFulfiled(maker, srcEToken, destEToken, makerGot, filled);
        } else {
          balanceOf[destEToken][maker] += makerGot;
        }

        // ?????????
        order.tokenAmt.fulfiled = order.tokenAmt.fulfiled.add(filled);
        order.tokenAmt.destFulfiled = order.tokenAmt.destFulfiled.add(makerGot);

        if (order.tokenAmt.fulfiled >= order.tokenAmt.amountOutMint) {
          //
          order.flag |= _ORDER_CLOSED;
          _removeOrder(order);
        }
    }

    /// @dev ??????????????????????????????????????? destEToken destToken ??????
    function calcTakerAmounts(uint[] memory orderIds) public view returns (uint totalEAmt, uint totalAmt) {
      for (uint i = 0;i < orderIds.length; i ++) {
        DataTypes.OrderItem memory order = orders[orderId];
        DataTypes.TokenAmount memory tokenAmt = order.tokenAmt;
        (uint eamt, uint amt) = OBPriceLogic.calcTakerAmount(
                                    tokenAmt.destToken,
                                    tokenAmt.destEToken,
                                    tokenAmt.amountOutMint,
                                    tokenAmt.guaranteeAmountIn,
                                    tokenAmt.amountOutMint.sub(tokenAmt.fulfiled)
                                );
        totalEAmt = totalEAmt.add(eamt);
        totalAmt = totalAmt.add(amt);
      }
    }

    /// @dev ?????????????????????????????????amt, ??????????????? destEToken destToken ??????
    function calcTakerAmount(uint id, uint amtToTaken) public view returns (uint takerEAmt, uint takerAmt) {
      DataTypes.OrderItem memory order = orders[id];
      DataTypes.TokenAmount memory tokenAmt = order.tokenAmt;
      return OBPriceLogic.calcTakerAmount(
                                  tokenAmt.destToken,
                                  tokenAmt.destEToken,
                                  tokenAmt.amountOutMint,
                                  tokenAmt.guaranteeAmountIn,
                                  amtToTaken
                              );
    }

    /// @dev ??????order???????????????, ?????????, ?????????????????????dest token???????????????. ?????? ??? token, ????????? EToken ??????????????? exchangeRate, ???????????????????????????????????????
    /// @param fulFilAmt ??????????????????, taker????????????????????? taker ????????????????????? maker ?????????????????????????????????
    function _getFulfiledAmt(
                DataTypes.TokenAmount memory tokenAmt,
                FulFilAmt memory fulFilAmt,
                uint256 pair
              )
              private {
      uint amtToTaken = fulFilAmt.filled;
      // ???????????????????????????????????????????????????????????????
      fulFilAmt.amtDest = OBPriceLogic.convertBuyAmountByETokenIn(tokenAmt, amtToTaken);

      if (feeTo != address(0)) {
        fulFilAmt.takerFee = amtToTaken.mul(getTakerFeeRate(pair)).div(DENOMINATOR);
        fulFilAmt.makerFee = amtToTaken.mul(getMakerFeeRate(pair)).div(DENOMINATOR);
      } else {
        fulFilAmt.takerFee = 0; // amtToTaken.mul(getTakerFeeRate(pair)).div(DENOMINATOR);
        fulFilAmt.makerFee = 0; // amtToTaken.mul(getMakerFeeRate(pair)).div(DENOMINATOR);
      }
      // taker??????????????????????????????
      fulFilAmt.takerAmt = amtToTaken.sub(fulFilAmt.takerFee);
      // maker ????????????????????????????????????
      fulFilAmt.makerAmt = fulFilAmt.amtDest.sub(fulFilAmt.makerFee);

      if (fulFilAmt.isToken) {
        // address srcEToken = tokenAmt.srcEToken;
        uint256 srcRate = OBPriceLogic.refreshTokenExchangeRate(ICToken(tokenAmt.srcEToken));
        uint256 destRate = OBPriceLogic.refreshTokenExchangeRate(ICToken(tokenAmt.destEToken));
        fulFilAmt.takerAmtToken = fulFilAmt.takerAmt.mul(srcRate).div(1e18);   // taker ?????????
        fulFilAmt.amtDestToken = fulFilAmt.amtDest.mul(destRate).div(1e18);    // taker ???????????????
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

    // ???????????????????????????????????????, ??????????????????????????? etoken
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

    // ???????????????????????????????????????, ??????????????????????????? token
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

    // ?????? ?????? ??????
    function closeOrderBook() external onlyOwner {
      closed = true;
    }

    function openOrderBook() external onlyOwner {
      closed = false;
    }

    // ???????????? token ??????????????????, ????????? etoken, ??? token
    function setMinOrderAmount(address etoken, uint amt) external onlyOwner {
      // ?????????????????? etoken ??????
      _getTokenAddress(etoken);
      minAmounts[etoken] = amt;
    }

    /// @dev ?????? feeTo ??????
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

    // pair ???????????????
    function setPairTakerFee(address src, address dest, uint fee) external onlyOwner {
      DataTypes.OBPairConfigMap storage conf = _getPairFee(src, dest);

      conf.setFeeTaker(fee);
    }
    
    // pair ???????????????
    function setPairMakerFee(address src, address dest, uint fee) external onlyOwner {
      DataTypes.OBPairConfigMap storage conf = _getPairFee(src, dest);

      conf.setFeeMaker(fee);
    }

    // ??????????????????????????????????????????
    function setMaxOrderCount(uint count) external onlyOwner {
      maxMarginOrder = count;
    }

    // ????????????????????????
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

