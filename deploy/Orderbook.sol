
















pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; 
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    
    function owner() public view virtual returns (address) {
        return _owner;
    }

    
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}



















contract ReentrancyGuard {
    bool private _notEntered;

    constructor () internal {
        
        
        
        
        
        
        _notEntered = true;
    }

    
    modifier nonReentrant() {
        
        require(_notEntered, "ReentrancyGuard: reentrant call");

        
        _notEntered = false;

        _;

        
        
        _notEntered = true;
    }
}


















library DataTypes {
    struct TokenAmount {
        address srcToken;
        address destToken;
        address srcEToken;             
        address destEToken;            
        uint amountIn;                 
        uint amountInMint;             
        uint fulfiled;                 
        uint guaranteeAmountOut;       
    }

    struct OrderItem {
      uint orderId;
      uint pairAddrIdx;        
      uint pair;               
      uint timestamp;          
      uint flag;
      address owner;           
      address to;              
      TokenAmount tokenAmt;
    }

    struct OBPairConfigMap {
      
      
      
      uint256 data;
    }
}

















library OBPairConfig {
    uint constant internal MASK_FEE_MAKER  = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff; 
    uint constant internal MASK_FEE_TAKER  = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000; 
    

    uint constant internal MAX_FEE_RATE = 1000; 

    uint constant internal SHIFT_FEE_TAKER = 128;

    
    function feeMaker(DataTypes.OBPairConfigMap storage self) public view returns (uint256) {
        return (self.data & MASK_FEE_MAKER);
    }

    
    function feeTaker(DataTypes.OBPairConfigMap storage self) public view returns (uint256) {
        return ((self.data & MASK_FEE_TAKER) >> SHIFT_FEE_TAKER);
    }
    
    
    function setFeeMaker(DataTypes.OBPairConfigMap storage self, uint fee) public {
        require(fee < MAX_FEE_RATE, "maker fee invalid");
        self.data = (self.data & ~MASK_FEE_MAKER) | (fee+1);
    }

    
    function setFeeTaker(DataTypes.OBPairConfigMap storage self, uint fee) public {
        require(fee < MAX_FEE_RATE, "taker fee invalid");
        self.data = (self.data & ~MASK_FEE_TAKER) | ((fee+1) << SHIFT_FEE_TAKER);
    }
}


















contract OBStorage is Ownable {
    using OBPairConfig for DataTypes.OBPairConfigMap;

    uint private constant _PAIR_INDEX_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;   
    uint private constant _ADDR_INDEX_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   
    uint private constant _MARGIN_MASK     = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint private constant _EXPIRED_AT_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;   
    uint private constant _ADDR_INDEX_OFFSET = 128;
    

    uint256 public constant DENOMINATOR = 10000;

    
    

    uint public orderId;   

    
    bool    public closed; 
    
    address public wETH;
    address public cETH;  
    address public ctokenFactory;
    address public marginAddr;  
    address public feeTo;       

    
    uint public defaultFeeMaker = 30;
    uint public defaultFeeTaker = 30;
    mapping(uint256 => DataTypes.OBPairConfigMap) public pairFeeRate;
    
    mapping(address => uint256) public minAmounts;
    mapping(address => mapping(address => uint)) public balanceOf;   

    
    mapping (uint => DataTypes.OrderItem) public orders;
    mapping (address => uint[]) public marginOrders;   
    mapping (address => uint[]) public addressOrders;
    mapping (uint => uint[]) public pairOrders;

    function pairIndex(uint id) public pure returns(uint) {
        return (id & _PAIR_INDEX_MASK);
    }

    function addrIndex(uint id) public pure returns(uint) {
        return (id & _ADDR_INDEX_MASK) >> _ADDR_INDEX_OFFSET;
    }

    
    function updateAddrIdx(uint idx, uint addrIdx) public pure returns(uint) {
      return pairIndex(idx) | addrIndex(addrIdx);
    }

    
    function updatePairIdx(uint idx, uint pairIdx) public pure returns(uint) {
      return (idx & _ADDR_INDEX_MASK) | pairIdx;
    }

    function maskAddrPairIndex(uint pairIdx, uint addrIdx) public pure returns (uint) {
        return (pairIdx) | (addrIdx << _ADDR_INDEX_OFFSET);
    }

    function isMargin(uint flag) public pure returns (bool) {
      return (flag & _MARGIN_MASK) != 0;
    }

    
    
    

    
    
    
    
    
    
    
}



















interface ICTokenFactory {
    
    function getCTokenAddress(address token) external returns (address);

    
    function getCTokenAddressPure(address token) external view returns (address);

    
    function getTokenAddress(address cToken) external view returns (address);
}



















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
    
    
    

}



















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
    
    
    

}


















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
        
        require(b > 0, errorMessage);
        uint256 c = a / b;
        

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




















library OBPriceLogic {
    using SafeMath for uint;
    using SafeMath for uint256;

    
    
    
    
    
    
    
    
    
    
    
    

    

    function getCurrentExchangeRate(ICToken ctoken) public view returns (uint256) {
        uint rate = ctoken.exchangeRateStored();
        uint supplyRate = ctoken.supplyRatePerBlock();
        uint lastBlock = ctoken.accrualBlockNumber();
        uint blocks = block.number.sub(lastBlock);
        uint inc = rate.mul(supplyRate).mul(blocks);
        return rate.add(inc);
    }

    function refreshTokenExchangeRate(ICToken ctoken) public returns (uint256) {
        return ctoken.exchangeRateCurrent();
    }

    
    
    
    
    function convertBuyAmountByETokenIn(
                    DataTypes.TokenAmount memory data,
                    uint amtToTaken
                )
                public
                view
                returns (uint) {
        
        
        address dst = data.destToken;
        address dstEToken = data.destEToken;
        
        

        if (dst == dstEToken) {
            
            return amtToTaken.mul(data.guaranteeAmountOut).div(data.amountInMint);
        }
        uint destRate = getCurrentExchangeRate(ICToken(dstEToken));
        uint destEAmt = data.guaranteeAmountOut.mul(1e18).div(destRate);
        return amtToTaken.mul(destEAmt).div(data.amountInMint);

        
        
        
        
        
        
        

        
        
        
    }


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

interface IWHT {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IHswapV2Callee {
    function hswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

interface IMarginHolding {
  
  
  
  function onFulfiled(address owner, address tokenOut, address tokenIn, uint fulfiled, uint amt) external;
  
  
  
  
  function onCanceled(address owner, address token0, address token1, address tokenReturn, uint amt) external;
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
          uint amtOut);
          

    event CancelOrder(address indexed owner,
          address indexed srcToken,
          address indexed destToken,
          uint orderId);
}

contract OrderBook is IOrderBook, OBStorage, ReentrancyGuard {
    using SafeMath for uint;
    using SafeMath for uint256;
    using OBPairConfig for DataTypes.OBPairConfigMap;

    uint private constant _ORDER_CLOSED  = 0x00000000000000000000000000000001;   
    uint private constant _HALF_MAX_UINT = uint(-1) >> 1;                            

    
    
    
    
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
      uint flag = order.flag;
      bool margin = isMargin(flag);
      uint addrIdx;
      uint pairIdx;
      address owner = order.owner;

      if (margin) {
          
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

    
    function _getOrCreateETokenAddress(address addr) internal returns (address) {
      if (addr == address(0) || addr == wETH) {
        return cETH;
      }
      address etoken = ICTokenFactory(ctokenFactory).getCTokenAddressPure(addr);
      if (etoken == address(0)) {
        
        
        
        address token = ICTokenFactory(ctokenFactory).getTokenAddress(addr);
        if (token != address(0)) {
          return addr;
        }
        
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

    
    
    function createOrder(
              address srcToken,
              address destToken,
              address to,             
              uint amountIn,
              uint guaranteeAmountOut,       
              uint flag
          )
          public
          payable
          whenOpen
          nonReentrant
          returns (uint idx) {
      require(srcToken != destToken, "identical token");

      if (srcToken == address(0)) {
        
        require(msg.value >= amountIn, "not enough amountIn");
        
        
      } else {
        
        TransferHelper.safeTransferFrom(srcToken, msg.sender, address(this), amountIn);
      }

      {
        
        require(amountIn > minAmounts[srcToken], "less than min amount");
      }
      idx = orderId ++;
      DataTypes.OrderItem storage order = orders[idx];
      order.orderId = idx;
      order.owner = msg.sender;
      order.to = to == address(0) ? msg.sender : to;
      
      order.timestamp = block.timestamp; 
      order.flag = flag;
      order.tokenAmt.fulfiled = 0;
      address etoken = _getOrCreateETokenAddress(srcToken);
      {
        order.tokenAmt.srcToken = srcToken;
        order.tokenAmt.srcEToken = etoken;
        order.tokenAmt.amountIn = amountIn;
        if (srcToken != etoken) {
          
          
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

      
      require((srcToken == etoken) == (destToken == destEToken), "both token or etoken");

      if (msg.sender == marginAddr) {
        require(isMargin(flag), "flag should be margin");
        
        require(etoken == srcToken, "src should be etoken");
        require(to != msg.sender, "to should be user's address");
        require(order.tokenAmt.destEToken == destToken, "dest should be etoken");
      }

      order.pair = _pairFor(etoken, destEToken);

      
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

    
    
    function _pairFor(address srcToken, address destToken) private pure returns(uint pair) {
      
      
      
      
      
      
      
      pair = uint(keccak256(abi.encodePacked(srcToken, destToken)));
    }

    
    function getAllOrders() external view returns(DataTypes.OrderItem[] memory allOrders) {
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
    
    
    function _redeemTransfer(
                    address token,
                    address etoken,
                    address to,
                    uint256 redeemAmt
                ) private {
        uint ret = ICToken(etoken).redeem(redeemAmt);
        require(ret == 0, "redeem failed");
        

        if (token == address(0)) {
            TransferHelper.safeTransferETH(to, address(this).balance);
        } else {
            TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        }
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
      uint amt = order.tokenAmt.amountInMint.sub(order.tokenAmt.fulfiled);

      if (srcToken != srcEToken) {
        
        
        
        

        if (amt > 0) {
          _redeemTransfer(srcToken, srcEToken, order.owner, amt);
          
        }
        
        
        
      } else {
        TransferHelper.safeTransfer(srcToken, order.owner, amt);
      }

      
      if (!margin) {
        address dest = order.tokenAmt.destEToken;
        address destToken = order.tokenAmt.destToken;
        uint balance = balanceOf[dest][order.to];
        if (balance > 0) {
          
          if (dest == destToken) {
              _withdraw(order.to, dest, balance, balance);
          } else {
              _withdrawUnderlying(order.to, destToken, dest, balance, balance);
          }
        }
      } else {
        
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

    
    function getMakerFeeRate(uint256 pair) public view returns (uint) {
      uint fee = pairFeeRate[pair].feeMaker();
      if (fee == 0) {
        return defaultFeeMaker;
      }
      return fee - 1;
    }

    
    function getTakerFeeRate(uint256 pair) public view returns (uint) {
      uint fee = pairFeeRate[pair].feeTaker();
      if (fee == 0) {
        return defaultFeeTaker;
      }

      return fee - 1;
    }

    struct FulFilAmt {
      bool isToken;      
      uint256 filled;    
      uint256 takerFee;  
      uint256 makerFee;  
      uint256 takerAmt;  
      uint256 takerAmtToken; 
      uint256 makerAmt;      
      uint256 amtDest;       
      uint256 amtDestToken;  
    }

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
              whenOpen
              nonReentrant {
        require(orderIds.length == amtToTakens.length, "invalid param");

        for (uint i = 0; i < orderIds.length; i ++) {
          fulfilOrder(orderIds[i], amtToTakens[i], to, isToken, partialFill, data);
        }
    }

    
    
    
    
    
    
    
    
    
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
      fulFilAmt.filled  = amtToTaken;  
      {
        uint left = tokenAmt.amountInMint.sub(tokenAmt.fulfiled);
        if (amtToTaken > left) {
          require(partialFill, "not enough to fulfil");
          
          fulFilAmt.filled = left;
        }
      }
      _getFulfiledAmt(tokenAmt, fulFilAmt, order.pair);

      
      
      
      address destEToken = tokenAmt.destEToken;
      address srcEToken = tokenAmt.srcEToken;

      
      if (isToken) {
            
          
          
          
          
          _redeemTransfer(tokenAmt.srcToken, srcEToken, to, fulFilAmt.takerAmt);
      } else {
          TransferHelper.safeTransfer(srcEToken, to, fulFilAmt.takerAmt);
      }
      

      
      if (data.length > 0) {
          uint256 balanceBefore = IERC20(destEToken).balanceOf(address(this));
          IHswapV2Callee(to).hswapV2Call(msg.sender, fulFilAmt.takerAmt, fulFilAmt.amtDest, data);
          uint256 transferIn = IERC20(destEToken).balanceOf(address(this)).sub(balanceBefore);
          require(transferIn >= fulFilAmt.amtDest, "not enough");
      } else {
          if (isToken) {
            address destToken = tokenAmt.destToken;
            TransferHelper.safeTransferFrom(destToken, msg.sender, address(this), fulFilAmt.amtDestToken);
            
            IERC20(destToken).approve(destEToken, fulFilAmt.amtDestToken);
            uint ret = ICToken(destEToken).mint(fulFilAmt.amtDestToken);
            require(ret == 0, "mint failed");
          } else {
            
            TransferHelper.safeTransferFrom(destEToken, msg.sender, address(this), fulFilAmt.amtDest);
          }
      }

      
      if (fulFilAmt.takerFee > 0) {
        TransferHelper.safeTransfer(srcEToken, feeTo, fulFilAmt.takerFee);
      }
      if (fulFilAmt.makerFee > 0) {
        TransferHelper.safeTransfer(destEToken, feeTo, fulFilAmt.makerFee);
      }

      
      
      
      _updateOrder(order, fulFilAmt.filled, fulFilAmt.makerAmt);

      emit FulFilOrder(
              order.owner,
              msg.sender,
              orderId,
              fulFilAmt.filled,
              fulFilAmt.amtDest
            );
    }

    
    function _updateOrder(
                DataTypes.OrderItem storage order,
                uint filled,
                uint makerGot
              ) private {
        address maker = order.to;
        address srcEToken = order.tokenAmt.srcEToken;
        address destEToken = order.tokenAmt.destEToken;

        if (isMargin(order.flag)) {
          
          TransferHelper.safeTransfer(destEToken, marginAddr, makerGot);
          
          IMarginHolding(marginAddr).onFulfiled(maker, srcEToken, destEToken, makerGot, filled);
        } else {
          balanceOf[destEToken][maker] += makerGot;
        }

        
        order.tokenAmt.fulfiled = order.tokenAmt.fulfiled.add(filled);

        if (order.tokenAmt.fulfiled >= order.tokenAmt.amountInMint) {
          
          order.flag |= _ORDER_CLOSED;
          _removeOrder(order);
        }
    }

    
    
    function _getFulfiledAmt(
                DataTypes.TokenAmount memory tokenAmt,
                FulFilAmt memory fulFilAmt,
                uint256 pair
              )
              private {
      uint amtToTaken = fulFilAmt.filled;
      
      fulFilAmt.amtDest = OBPriceLogic.convertBuyAmountByETokenIn(tokenAmt, amtToTaken);

      fulFilAmt.takerFee = amtToTaken.mul(getTakerFeeRate(pair)).div(DENOMINATOR);
      fulFilAmt.makerFee = amtToTaken.mul(getMakerFeeRate(pair)).div(DENOMINATOR);
      
      fulFilAmt.takerAmt = amtToTaken.sub(fulFilAmt.takerFee);
      
      fulFilAmt.makerAmt = fulFilAmt.amtDest.sub(fulFilAmt.makerFee);

      if (fulFilAmt.isToken) {
        
        uint256 srcRate = OBPriceLogic.refreshTokenExchangeRate(ICToken(tokenAmt.srcEToken));
        uint256 destRate = OBPriceLogic.refreshTokenExchangeRate(ICToken(tokenAmt.destEToken));
        fulFilAmt.takerAmtToken = fulFilAmt.takerAmt.mul(srcRate).div(1e18);
        fulFilAmt.amtDestToken = fulFilAmt.amtDest.mul(destRate).div(1e18);
      }
    }

    
    
    function _withdraw(address user, address etoken, uint total, uint amt) private {
        TransferHelper.safeTransfer(etoken, user, amt);

        balanceOf[etoken][user] = total.sub(amt);
    }

    function _withdrawUnderlying(address user, address token, address etoken, uint total, uint amt) private {
        balanceOf[etoken][user] = total.sub(amt);

        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        _redeemTransfer(token, etoken, user, amt);
    }

    
    function withdraw(address etoken, uint amt) external {
        uint total = balanceOf[etoken][msg.sender];
        require(total > 0, "no asset");
        if (amt == 0) {
            amt = total;
        } else {
            require(total >= amt, "not enough asset");
        }

        _withdraw(msg.sender, etoken, total, amt);
    }

    
    function withdrawUnderlying(address token, uint amt) external {
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

    function setPairTakerFee(address src, address dest, uint fee) external onlyOwner {
      DataTypes.OBPairConfigMap storage conf = _getPairFee(src, dest);

      conf.setFeeTaker(fee);
    }
    
    function setPairMakerFee(address src, address dest, uint fee) external onlyOwner {
      DataTypes.OBPairConfigMap storage conf = _getPairFee(src, dest);

      conf.setFeeMaker(fee);
    }
}


library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        
        
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        
        
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        
        
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}