// SPDX-License-Identifier: GPL-3.0-or-later





pragma solidity ^0.5.0;


contract Context {
    
    
    constructor () internal { }
    

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; 
        return msg.data;
    }
}






contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    
    function owner() public view returns (address) {
        return _owner;
    }

    
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}






library EnumerableSet {

    struct AddressSet {
        
        
        mapping (address => uint256) index;
        address[] values;
    }

    
    function add(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        if (!contains(set, value)){
            set.index[value] = set.values.push(value);
            return true;
        } else {
            return false;
        }
    }

    
    function remove(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        if (contains(set, value)){
            uint256 toDeleteIndex = set.index[value] - 1;
            uint256 lastIndex = set.values.length - 1;

            
            if (lastIndex != toDeleteIndex) {
                address lastValue = set.values[lastIndex];

                
                set.values[toDeleteIndex] = lastValue;
                
                set.index[lastValue] = toDeleteIndex + 1; 
            }

            
            delete set.index[value];

            
            set.values.pop();

            return true;
        } else {
            return false;
        }
    }

    
    function contains(AddressSet storage set, address value)
        internal
        view
        returns (bool)
    {
        return set.index[value] != 0;
    }

    
    function enumerate(AddressSet storage set)
        internal
        view
        returns (address[] memory)
    {
        address[] memory output = new address[](set.values.length);
        for (uint256 i; i < set.values.length; i++){
            output[i] = set.values[i];
        }
        return output;
    }

    
    function length(AddressSet storage set)
        internal
        view
        returns (uint256)
    {
        return set.values.length;
    }

   
    function get(AddressSet storage set, uint256 index)
        internal
        view
        returns (address)
    {
        return set.values[index];
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

      
      function getCTokenAddress(address token) external returns (address cToken);
      function getCTokenAddressPure(address cToken) external view returns (address);
      function getTokenAddress(address cToken) external view returns (address);
}

















interface IDeBankFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);

    function router() external view returns (address);

    function compAddr() external view returns (address);
    
    

    function lpFeeRate() external view returns (uint256);

    

    function anchorToken() external view returns (address);

    function feeRateOf(address to) external view returns (uint);

    function mintFreeAddress(address addr) external view returns (bool);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB, address ctoken0, address ctoken1) external returns (address pair);

    function setFeeTo(address) external;

    

    function setFeeToRate(uint256) external;

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    function pairFor(address tokenA, address tokenB) external view returns (address pair);

    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    

    

    function getAmountsOut(uint256 amountIn, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    
    

    function setPairFeeRate(address pair, uint feeRate) external;

    function getReservesFeeRate(address tokenA, address tokenB, address to) external view returns (uint reserveA, uint reserveB, uint feeRate, bool outAnchorToken);

    function getAmountOutFeeRate(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external view returns (uint amountOut);

    function getAmountInFeeRate(uint amountOut, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountIn);

    function getAmountOutFeeRateAnchorToken(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountOut);

    function setAnchorToken(address _token) external;

    function setUserFeeRate(address user, uint feeRate) external;
}


















interface IDeBankPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    

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

    
    function cToken0() external view returns (address);

    
    function cToken1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    
    function withdrawEBEReward(address to) external returns (uint);

    function mint(address to) external returns (uint liquidity);
    

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    function swapNoFee(uint amount0Out, uint amount1Out, address to, uint fee) external;

    function skim(address to) external;

    function sync() external;

    function price(address token, uint256 baseDecimal) external view returns (uint256);

    function initialize(address, address, address, address) external;
    function updateFeeRate(uint256 _feeRate) external;
    
    

    function getFee(uint256 amt) external view returns (uint256);
    function getFee(uint256 amt, uint fr) external view returns (uint256);

    
}






interface IEBEToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function mint(address _to, uint256 _amount) external returns (bool);
    
    function reward(uint256 ebePerBlock, uint256 blockNumber) external view returns (uint256);
    function getEbeReward(uint256 ebePerBlock, uint256 _lastRewardBlock) external view returns (uint256);
}











contract SwapMining is Ownable {
    using SafeMath for uint256;
    
    

    
    uint256 public ebePerBlock;
    
    uint256 public startBlock;
    
    uint256 public halvingPeriod = 5256000;
    
    uint256 public totalAllocPoint = 0;
    
    
    
    
    address public router;
    
    
    
    IEBEToken public ebe;
    
    
    
    

    struct UserInfo {
        uint256 quantity;       
        uint256 blockNumber;    
    }

    struct PoolInfo {
        
        uint256 quantity;       
        uint256 totalQuantity;  
        
        uint256 allocEbeAmount; 
        uint256 lastRewardBlock;
    }

    PoolInfo public pool;
    
    mapping(address => UserInfo) public userInfo;


    constructor(
        address _ebe,
        
        
        address _router,
        
        uint256 _ebePerBlock,
        uint256 _startBlock
    ) public {
        ebe = IEBEToken(_ebe);
        
        
        router = _router;
        
        ebePerBlock = _ebePerBlock;
        startBlock = _startBlock;
    }

    
    
    


    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    

    
    function setEbePerBlock(uint256 _newPerBlock) public onlyOwner {
        
        mint();
        ebePerBlock = _newPerBlock;
    }

    
    
    
    
    

    
    
    
    

    
    
    

    
    
    

    
    
    
    

    
    
    

    function setRouter(address newRouter) public onlyOwner {
        require(newRouter != address(0), "SwapMining: new router is the zero address");
        router = newRouter;
    }

    
    
    
    

    
    
    
    
    

    
    
    
    
    

    
    
    

    
    
    
    

    
    
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    function mint() public returns (bool) {
        
        if (block.number <= pool.lastRewardBlock) {
            return false;
        }
        uint256 blockReward = ebe.getEbeReward(ebePerBlock, pool.lastRewardBlock);
        if (blockReward <= 0) {
            return false;
        }
        
        
        ebe.mint(address(this), blockReward);
        
        
        pool.lastRewardBlock = block.number;
        return true;
    }

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    function swap(address account, address input, address output, uint256 fee) public onlyRouter returns (bool) {
        require(account != address(0), "SwapMining: taker swap account is the zero address");
        input;
        output;
        
        

        
        
        

        
        
        

        

        
        
        
        
        

        uint256 quantity = fee; 
        if (quantity <= 0) {
            return false;
        }

        mint();

        pool.quantity = pool.quantity.add(quantity);
        pool.totalQuantity = pool.totalQuantity.add(quantity);
        UserInfo storage user = userInfo[account];
        user.quantity = user.quantity.add(quantity);
        user.blockNumber = block.number;
        return true;
    }

    
    function takerWithdraw() public {
        uint256 userSub;
        
        
            
            UserInfo storage user = userInfo[msg.sender];
            if (user.quantity > 0) {
                mint();
                
                uint256 userReward = pool.allocEbeAmount.mul(user.quantity).div(pool.quantity);
                pool.quantity = pool.quantity.sub(user.quantity);
                pool.allocEbeAmount = pool.allocEbeAmount.sub(userReward);
                user.quantity = 0;
                user.blockNumber = block.number;
                userSub = userSub.add(userReward);
            }
        
        if (userSub <= 0) {
            return;
        }
        ebe.transfer(msg.sender, userSub);
    }

    
    function getUserReward() public view returns (uint256, uint256){
        
        uint256 userSub;
        
        UserInfo memory user = userInfo[msg.sender];
        if (user.quantity > 0) {
            uint256 ebeReward = ebe.getEbeReward(ebePerBlock, pool.lastRewardBlock);
            
            
            userSub = (pool.allocEbeAmount.add(ebeReward)).mul(user.quantity).div(pool.quantity);
        }
        
        return (userSub, user.quantity);
    }

    
    
    
    
    
    
    
    
    
    
    
    
    

    modifier onlyRouter() {
        require(msg.sender == router, "SwapMining: caller is not the router");
        _;
    }

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

}