



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


















interface IDeBankRouter {
    function factory() external view returns (address);

    function WHT() external view returns (address);

    function swapFeeTotal() external view returns (uint);

    function reward(uint256 blockNumber) external view returns (uint256);

    function rewardToken() external view returns (address);

    
    function swapFeeCurrent() external view returns(uint256);

    function pendingEBE() external view returns (uint256);

    function mintEBEToken(address token0, address token1, uint256 _amount) external returns (uint);

    
    
    

    

    function swapMining() external view returns (address);

    

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
    ) external returns (uint[] memory amounts, uint fee);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts, uint fee);

    function swapExactTokensForTokensUnderlying(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    
    
    
    
    
    
    

    function swapExactETHForTokensUnderlying(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    
    
    

    function swapExactTokensForETHUnderlying(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    
    
    
    
    
    
    
    

    
    
    

    
    
    

    
    
    
    

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external view returns (uint256 amountB);

    

    

    function getAmountsOut(uint256 amountIn, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    

    
    
    
    
    
    

    
    
    
    
    
    
    
}


















interface IWHT {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}



















interface ICToken {

    function mint(uint mintAmount) external returns (uint, uint);
    function redeem(uint redeemTokens) external returns (uint, uint, uint);

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






interface IEBEToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function mint(address _to, uint256 _amount) external returns (bool);
    
    function reward(uint256 ebePerBlock, uint256 blockNumber) external view returns (uint256);
    function getEbeReward(uint256 ebePerBlock, uint256 _lastRewardBlock) external view returns (uint256);
}




















interface ILHT {
    function mint() external payable returns (uint, uint);
}

interface ISwapMining {
    function swap(address account, address input, address output, uint256 fee) external returns (bool);
}





contract DeBankRouter is IDeBankRouter, Ownable {
    using SafeMath for uint256;

    address public factory;
    address public WHT;
    address public swapMining;
    address public cWHT;
    address[] public quoteTokens;
    LErc20DelegatorInterface public ctokenFactory;

    
    
    
    
    
    
    
    

    address public rewardToken;     

    uint256 public swapFeeTotal;       
    uint256 public swapFeeCurrent;     
    uint256 public swapFeeLastBlock;   
    uint256 public ebeRewards;         
    
    
    
    uint256 public ebePerBlock;        
    
    
    uint256 public feeAlloc;        
    
    

    modifier ensure(uint deadline) {
        
        require(deadline >= block.timestamp, 'DeBankRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _wht, address _cwht, address _ctokenFactory) public {
        factory = _factory;
        WHT = _wht;
        cWHT = _cwht;
        ctokenFactory = LErc20DelegatorInterface(_ctokenFactory);
        
        
        quoteTokens.push(IDeBankFactory(_factory).anchorToken()); 
        
        quoteTokens.push(WHT); 
        
    }

    function() external payable {
        assert(msg.sender == WHT || msg.sender == cWHT);
        
    }

    function pairFor(address tokenA, address tokenB) public view returns (address pair) {
        
        pair = IDeBankFactory(factory).getPair(tokenA, tokenB);
    }

    function setFeeAlloc(uint _feeAlloc) public onlyOwner {
        require(_feeAlloc == 0 || _feeAlloc == 1, "invalid param feeAlloc");
        feeAlloc = _feeAlloc;
    }

    function setSwapMining(address _swapMininng) public onlyOwner {
        swapMining = _swapMininng;
    }

    function setCtokenFactory(address _ctokenFactory) public onlyOwner {
        ctokenFactory = LErc20DelegatorInterface(_ctokenFactory);
    }

    function resetQuoteTokens(address[] memory tokens) public onlyOwner {
        for (uint i; i < quoteTokens.length; i ++) {
            quoteTokens.pop();
        }
        
        for (uint i; i < tokens.length; i ++) {
            quoteTokens.push(tokens[i]);
        }
    }

    function addQuoteToken(address token) public onlyOwner {
        quoteTokens.push(token);
    }

    
    function setRewardToken(address _reword) external onlyOwner {
        rewardToken = _reword;
        
    }

    function setEbePerBlock(uint256 _ebePerBlock) external onlyOwner {
        ebePerBlock = _ebePerBlock;
    }

    
    
    
    
    
    
    
    
    

    
    function reward(uint256 blockNumber) public view returns (uint256) {
        if (rewardToken == address(0) || feeAlloc == 0) {
            return 0;
        }
        return IEBEToken(rewardToken).reward(ebePerBlock, blockNumber);
    }

    function pendingEBE() public view returns (uint256) {
        if (rewardToken == address(0)) {
            return 0;
        }
        return IEBEToken(rewardToken).getEbeReward(ebePerBlock, swapFeeLastBlock);
    }

    
    function mintEBEToken(address token0, address token1, uint256 _amount) external returns (uint) {
        
        if (rewardToken == address(0) || feeAlloc == 0) {
            return 0;
        }

        address pair = pairFor(token0, token1);
        require(msg.sender == pair, "pair not equal");

        if (swapFeeLastBlock < block.number) {
            uint amt = IEBEToken(rewardToken).getEbeReward(ebePerBlock, swapFeeLastBlock);
            IEBEToken(rewardToken).mint(address(this), amt);
            swapFeeLastBlock = block.number;
        }

        if (_amount == 0) {
            return 0;
        }

        
        uint ebeBalance = IERC20(rewardToken).balanceOf(address(this));
        if (swapFeeCurrent >= _amount) {
            uint part = _amount.mul(ebeBalance).div(swapFeeCurrent);
            IEBEToken(rewardToken).transfer(pair, part);
            return part;
        }
        return 0;
    }

    function _getOrCreateCtoken(address token) private returns (address ctoken) {
        
        ctoken = ctokenFactory.getCTokenAddress(token);
        require(ctoken != address(0), "get or create etoken failed");
    }

    function _getCtoken(address token) private view returns (address ctoken) {
        
        ctoken = ctokenFactory.getCTokenAddressPure(token);
        require(ctoken != address(0), "get etoken failed");
    }

    function _getTokenByCtoken(address ctoken) private view returns (address token) {
        
        token = ctokenFactory.getTokenAddress(ctoken);
        require(token != address(0), "get token failed");
    }

    
    
    

    

    struct LiquidityLocalVars {
        
        
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

    
    function _addLiquidity(
        LiquidityLocalVars memory liquidity
    ) internal returns (uint amountA, uint amountB) {
        address ctokenA = liquidity.ctokenA;
        address ctokenB = liquidity.ctokenB;
        uint amountADesired  = liquidity.camountDesiredA;
        uint amountBDesired = liquidity.camountDesiredB;
        uint amountAMin = liquidity.camountMinA;
        uint amountBMin = liquidity.camountMinB;
        address tokenA =  liquidity.tokenA; 
        address tokenB =  liquidity.tokenB; 

        
        if (IDeBankFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IDeBankFactory(factory).createPair(tokenA, tokenB, ctokenA, ctokenB);
        }
        (uint reserveA, uint reserveB) = IDeBankFactory(factory).getReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = IDeBankFactory(factory).quote(amountADesired, reserveA, reserveB);
            
            if (amountBOptimal <= amountBDesired) {
                
                
                require(amountBOptimal >= amountBMin, 'AddLiquidity: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = IDeBankFactory(factory).quote(amountBDesired, reserveB, reserveA);
                
                
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'AddLiquidity: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidityAmt) {
        
        
        
        LiquidityLocalVars memory liquidity;
        liquidity.camountDesiredA = amountADesired;
        liquidity.camountDesiredB = amountBDesired;
        liquidity.camountMinA = amountAMin;
        liquidity.camountMinB = amountBMin;
        liquidity.ctokenA = tokenA;
        liquidity.ctokenB = tokenB;
        liquidity.tokenA = _getTokenByCtoken(tokenA);
        liquidity.tokenB = _getTokenByCtoken(tokenB);
        (amountA, amountB) = _addLiquidity(liquidity); 
        address pair = pairFor(tokenA, tokenB);
        
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        
        
        liquidityAmt = IDeBankPair(pair).mint(to);
    }

    function _cTokenExchangeRate(address ctoken) private view returns(uint) {
        uint rate = ICToken(ctoken).exchangeRateStored();
        uint256 supplyRate = ICToken(ctoken).supplyRatePerBlock();
        uint256 prevBlock = ICToken(ctoken).accrualBlockNumber();
        rate += rate.mul(supplyRate).mul(block.number - prevBlock);
        return rate;
    }

    
    
    
    
    
    function _mintTransferCToken(address token, address ctoken, address pair, uint amt) private {
        
        

        
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amt);
        
        
        
        ICToken(token).approve(address(ctoken), amt);
        (uint ret, uint mintCAmt) = ICToken(ctoken).mint(amt);
        ICToken(ctoken).approve(address(ctoken), 0);
        
        require(ret == 0, "mint failed");
        
        
        

        

        if (address(this) != pair) {
            TransferHelper.safeTransferFrom(ctoken, address(this), pair, mintCAmt);
        }
    }

    function _mintTransferEth(address pair, uint amt) private {
        
        (uint ret, uint mintCAmt) = ILHT(cWHT).mint.value(amt)();
        require(ret == 0, "mint failed");
        
        
        
        if (address(this) != pair) {
            TransferHelper.safeTransferFrom(cWHT, address(this), pair, mintCAmt);
        }
    }

    function _amount2CAmount(uint amt, uint rate) private pure returns (uint) {
        return amt.mul(10**18).div(rate);
    }

    function _camount2Amount(uint camt, uint rate) private pure returns (uint) {
        return camt.mul(rate).div(10**18);
    }

    
    
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
        vars.tokenA = tokenA;
        vars.tokenB = tokenB;
        vars.rateA = _cTokenExchangeRate(vars.ctokenA);
        vars.rateB = _cTokenExchangeRate(vars.ctokenB);
        vars.camountDesiredA = _amount2CAmount(amountADesired, vars.rateA);
        vars.camountDesiredB = _amount2CAmount(amountBDesired, vars.rateB);
        vars.camountMinA = _amount2CAmount(amountAMin, vars.rateA);
        vars.camountMinB = _amount2CAmount(amountBMin, vars.rateB);

        (vars.camountA, vars.camountB) = _addLiquidity(vars); 
                
                
                
                
                
        address pair = pairFor(tokenA, tokenB);
        
        amountA = _camount2Amount(vars.camountA, vars.rateA);
        amountB = _camount2Amount(vars.camountB, vars.rateB);
        
        _mintTransferCToken(tokenA, vars.ctokenA, pair, amountA);
        _mintTransferCToken(tokenB, vars.ctokenB, pair, amountB);
        
        
        
        
        
        liquidity = IDeBankPair(pair).mint(to);
    }

    
    
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
        vars.ctokenA = ctoken;
        vars.ctokenB = cWHT;
        vars.tokenA = token;
        vars.tokenB = WHT;
        (uint amountCToken, uint amountCETH) = _addLiquidity(vars);
        
        
        
        
        
        
        
        address pair = pairFor(token, WHT);

        amountToken = _camount2Amount(amountCToken, vars.rateA);
        amountETH = _camount2Amount(amountCETH, vars.rateB);
        
        _mintTransferCToken(token, ctoken, pair, amountToken);
        
        
        
        _mintTransferEth(pair, amountETH);
        
        
        liquidity = IDeBankPair(pair).mint(to);
        
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    
    
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
        
        
        (uint amount0, uint amount1) = IDeBankPair(pair).burn(to);
        address tokenA = _getTokenByCtoken(ctokenA);
        address tokenB = _getTokenByCtoken(ctokenB);
        (address token0,) = IDeBankFactory(factory).sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'RemoveLiquidity: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'RemoveLiquidity: INSUFFICIENT_B_AMOUNT');
    }

    
    function _redeemCToken(address ctoken, uint camt) private returns (uint) {
        
        
        (uint err, uint amt, ) = ICToken(ctoken).redeem(camt);
        require(err == 0, "redeem failed");
        return amt;
        
        
        
        
        
    }

    
    function _redeemCEth(uint camt) private returns (uint) {
        
        (uint err, uint amt, ) = ICToken(cWHT).redeem(camt);
        require(err == 0, "redeem failed");
        return amt;
        
        
    }

    function _redeemCTokenTransfer(address ctoken, address token, address to, uint camt) private returns (uint)  {
        
        uint amt = _redeemCToken(ctoken, camt);
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
        
        

        IDeBankPair(pair).transferFrom(msg.sender, pair, liquidity);
        LiquidityLocalVars memory vars;
        {
            vars.tokenA = tokenA;
            vars.tokenB = tokenB;
            
            (uint camount0, uint camount1) = IDeBankPair(pair).burn(address(this));
            (address token0,) = IDeBankFactory(factory).sortTokens(vars.tokenA, vars.tokenB);
            (vars.camountA, vars.camountB) = tokenA == token0 ? (camount0, camount1) : (camount1, camount0);
        }
        
        amountA = _redeemCTokenTransfer(_getCtoken(tokenA), tokenA, to, vars.camountA);
        amountB = _redeemCTokenTransfer(_getCtoken(tokenB), tokenB, to, vars.camountB);

        
        
        
        
        
        

        require(amountA >= amountAMin, 'RemoveLiquidityUnderlying: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'RemoveLiquidityUnderlying: INSUFFICIENT_B_AMOUNT');
    }

    
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
        
        
        amountETH = _redeemCETHTransfer(to, amountCETH);
        
        
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

    
    function _swapFee(address input, address pair, uint feeIn, address feeTo) internal returns (uint feeOut) {
        (uint reserve0, uint reserve1, ) = IDeBankPair(pair).getReserves();
        address token0 = IDeBankPair(pair).token0();
        if (input == token0) {
            feeOut = feeIn.mul(reserve1).div(reserve0.add(feeIn));
            IDeBankPair(pair).swapNoFee(0, feeOut, feeTo, 0);
        } else {
            feeOut = feeIn.mul(reserve0).div(reserve1.add(feeIn));
            IDeBankPair(pair).swapNoFee(feeOut, 0, feeTo, 0);
        }
        
    }

    struct SwapAnchorParam {
        uint fr;            
        address input;
        address cinput;
        address pair;
        address feeTo;
        address anchorToken;
    }

    
    
    
    function _swapToCAnchorToken(
                    SwapAnchorParam memory param,
                    uint amountIn
                )
                internal
                returns (uint feeIn, uint fee) {
        
        
        uint feeRate = param.fr;
        address pair = param.pair;
        address input = param.input;
        address anchorToken = param.anchorToken;
        address feeTo = param.feeTo;

        
        if (feeRate == 0) {
            feeIn = IDeBankPair(pair).getFee(amountIn);
        } else {
            feeIn = IDeBankPair(pair).getFee(amountIn, feeRate - 1);
        }
        

        if (input == anchorToken) {
            
            fee = feeIn;
            IERC20(param.cinput).transfer(feeTo, fee);
            
        } else {
            
            address cinput = param.cinput; 
            for (uint i; i < quoteTokens.length; i ++) {
                address token = quoteTokens[i];
                address tPair = IDeBankFactory(factory).getPair(input, token);

                
                if (tPair != address(0)) {
                    if (token == anchorToken) {
                        
                        IERC20(cinput).transfer(tPair, feeIn);
                        fee = _swapFee(input, tPair, feeIn, feeTo);
                    } else {
                        
                        
                        address pair2 = IDeBankFactory(factory).getPair(token, anchorToken);
                        require(pair2 != address(0), "quote coin has no pair to anchorToken");
                        IERC20(cinput).transfer(tPair, feeIn);
                        uint fee1 = _swapFee(input, tPair, feeIn, pair2);
                        
                        fee = _swapFee(token, pair2, fee1, feeTo);
                    }
                    break;
                }
            }
        }

        
    }

    function _updatePairFee(uint fee) private {
        
        
        
        
        
        
        
        
        
        swapFeeTotal += fee;
        swapFeeCurrent += fee;
    }


    
    
    function _swap2(uint amtIn, address[] memory path, address _to) internal returns (uint256 amtOut, uint feeTotal) {
        SwapAnchorParam memory param;

        param.feeTo = IDeBankFactory(factory).feeTo();
        require(param.feeTo != address(0), "feeTo not set");
        param.anchorToken = IDeBankFactory(factory).anchorToken();
        param.fr = IDeBankFactory(factory).feeRateOf(_to);

        uint amountIn = amtIn;
        uint fee;
        
        for (uint i; i < path.length - 1; i++) {
            param.input = path[i];
            param.cinput = _getCtoken(param.input);
            param.pair = IDeBankFactory(factory).getPair(path[i], path[i+1]);
            
            
            
            
            
            
            
            
            

            

            
            
            
            
            address to = i < path.length - 2 ? address(this) : _to;
            
            
            
            
            (amtOut, fee) = _doSwapAnchorToken(param, amountIn, to);
            feeTotal += fee;
            amountIn = amtOut;
        }

        if (swapMining != address(0)) {
            
            ISwapMining(swapMining).swap(msg.sender, path[0], path[1], feeTotal);
        }

        if (feeTotal > 0) {
            _updatePairFee(feeTotal);
        }
        
    }

    function _doSwapAnchorToken(
                    SwapAnchorParam memory param,
                    uint amountIn,
                    address to
                )
                internal
                returns (uint, uint) {
        address input = param.input;
        address pair = param.pair;
        
        

        
        (uint feeIn, uint fee) = _swapToCAnchorToken(param, amountIn);
        

        amountIn = amountIn.sub(feeIn);
        
        (uint amount0Out, uint amount1Out, uint amountOut) = _calcAmountOut(input, pair, amountIn);
        
        
        IERC20(param.cinput).transfer(pair, amountIn);
        
        
        IDeBankPair(pair).swapNoFee(
            amount0Out, amount1Out, to, fee
        );
        
        
        return (amountOut, fee);
    }

    function _calcAmountOut(
                    address input,
                    address pair,
                    uint amtIn
                )
                internal
                view
                returns (uint out0, uint out1, uint out) {
        address token0 = IDeBankPair(pair).token0(); 
        (uint reserve0, uint reserve1,) = IDeBankPair(pair).getReserves();
        if (input == token0) {
            out0 = 0;
            out1 = amtIn.mul(reserve1) / (reserve0 + amtIn);
            out = out1;
        } else {
            out1 = 0;
            out0 = amtIn.mul(reserve0) / (reserve1 + amtIn);
            out = out0;
        }
    }

    
    
    
    
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        
        
        

        
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = IDeBankFactory(factory).sortTokens(input, output);
            
            
            
            uint amountOut = amounts[i + 1];
            
            

            
            
            
            

            
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? pairFor(output, path[i + 2]) : _to;
            
            
            
            
            
            
            

            
            
            
            

            
            
            
            
            
                IDeBankPair(pairFor(input, output)).swap(
                    amount0Out, amount1Out, to, new bytes(0)
                );
            
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

    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata cpath,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts, uint fee) {
        
        address[] memory path = _cpath2path(cpath);
        amounts = IDeBankFactory(factory).getAmountsOut(amountIn, path, to);
        
        require(amounts[amounts.length - 1] >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        
        
        
        if (feeAlloc == 0) {
            TransferHelper.safeTransferFrom(cpath[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
            _swap(amounts, path, to);
        } else {
            TransferHelper.safeTransferFrom(cpath[0], msg.sender, address(this), amounts[0]);
            (, fee) = _swap2(amountIn, path, to);
        }
    }

    
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata cpath,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts, uint fee) {
        
        address[] memory path = _cpath2path(cpath);
        amounts = IDeBankFactory(factory).getAmountsIn(amountOut, path, to);
        require(amounts[0] <= amountInMax, 'Router: EXCESSIVE_INPUT_AMOUNT');
        
        
        
        if (feeAlloc == 0) {
            TransferHelper.safeTransferFrom(cpath[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
            _swap(amounts, path, to);
        } else {
            TransferHelper.safeTransferFrom(cpath[0], msg.sender, address(this), amounts[0]);
            (, fee) = _swap2(amounts[0], path, to);
        }
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
        
        address[] memory cpath = _path2cpath(path);
        address mintTo;
        if (feeAlloc == 0) {
            mintTo = pairFor(path[0], path[1]);
        } else {
            mintTo = address(this);
        }
        if (ethIn) {
            _mintTransferEth(mintTo, amountIn);
        } else {
            _mintTransferCToken(path[0], cpath[0], mintTo, amountIn);
        }
        

        SwapLocalVars memory vars;
        vars.amountIn = amountIn;
        vars.rate0 = _cTokenExchangeRate(cpath[0]);
        vars.rate1 = _cTokenExchangeRate(cpath[0]);
        uint camtIn = _amount2CAmount(amountIn, vars.rate0);
        uint camtOut;
        
        
        

        
        
        if (feeAlloc == 0) {
            uint[] memory camounts = IDeBankFactory(factory).getAmountsOut(camtIn, path, to);
            

            
            camtOut = camounts[camounts.length-1];
            vars.amountOut = _camount2Amount(camtOut, vars.rate1);
            require(vars.amountOut >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
            _swap(camounts, path, address(this));
        } else {
            (camtOut, ) = _swap2(camtIn, path, address(this));
            require(vars.amountOut >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        }

        
        uint idx = path.length - 1;
        if (ethOut) {
            _redeemCETHTransfer(to, camtOut);
        } else {
            _redeemCTokenTransfer(cpath[idx], path[idx], to, camtOut);
        }

        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[idx] = _camount2Amount(camtOut, vars.rate1);
    }

    
    
    function swapExactTokensForTokensUnderlying(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        
        amounts = _swapExactTokensForTokensUnderlying(amountIn, amountOutMin, path, to, deadline, false, false);
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        

        
        
        
    }

    struct SwapLocalVars {
        uint rate0;
        uint rate1;
        uint amountIn;
        uint amountOut;
    }

    

    function swapExactETHForTokensUnderlying(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        
        require(path[0] == WHT, 'Router: INVALID_PATH');
        amounts = _swapExactTokensForTokensUnderlying(msg.value, amountOutMin, path, to, deadline, true, false);
        
        
        
        
        
    }

    

    function swapExactTokensForETHUnderlying(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        
        require(path[path.length - 1] == WHT, 'Router: INVALID_PATH');
        amounts = _swapExactTokensForTokensUnderlying(amountIn, amountOutMin, path, to, deadline, false, true);
        
        
        
        
        
        
        
        
    }

    

    function adminTransfer(address token, address to, uint amt) external onlyOwner {
        if (token == address(0)) {
          TransferHelper.safeTransferETH(to, amt);
        } else {
          TransferHelper.safeTransferFrom(token, address(this), to, amt);
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public view returns (uint256 amountB) {
        return IDeBankFactory(factory).quote(amountA, reserveA, reserveB);
    }

    
    
    

    
    
    

    function getAmountsOut(uint256 amountIn, address[] memory path, address to) public view returns (uint256[] memory amounts) {
        return IDeBankFactory(factory).getAmountsOut(amountIn, path, to);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path, address to) public view returns (uint256[] memory amounts) {
        return IDeBankFactory(factory).getAmountsIn(amountOut, path, to);
    }

}

library SwapExchangeRate {
    using SafeMath for uint;
    using SafeMath for uint256;

    function getCurrentExchangeRate(address _ctoken) public view returns (uint256) {
        ICToken ctoken = ICToken(_ctoken);

        uint rate = ctoken.exchangeRateStored();
        uint supplyRate = ctoken.supplyRatePerBlock();
        uint lastBlock = ctoken.accrualBlockNumber();
        uint blocks = block.number.sub(lastBlock);
        uint inc = rate.mul(supplyRate).mul(blocks);
        return rate.add(inc);
    }

    
    
    
    

    function path2cpath(
                    address ctokenFactory,
                    address[] memory path
                )
                public
                view
                returns (address[] memory) {
        address[] memory cpath = new address[](path.length);

        for (uint i = 0; i < path.length; i ++) {
            cpath[i] = LErc20DelegatorInterface(ctokenFactory).getCTokenAddressPure(path[i]);
        }
        return cpath;
    }


    
    function getLiquidityAmountUnderlying(
                    address factory,
                    address ctokenFactory,
                    uint256 amountA,
                    address tokenA,
                    address tokenB
                )
                public
                view
                returns (uint256) {
        (uint ra, uint rb) = IDeBankFactory(factory).getReserves(tokenA, tokenB);
        uint rateA;
        uint rateB;
        {
            
            address ctokenA = LErc20DelegatorInterface(ctokenFactory).getCTokenAddressPure(tokenA);
            address ctokenB = LErc20DelegatorInterface(ctokenFactory).getCTokenAddressPure(tokenB);
            rateA = getCurrentExchangeRate(ctokenA);
            rateB = getCurrentExchangeRate(ctokenB);
        }
        
        
        
        

        return amountA.mul(rb).mul(rateB).div(rateA).div(ra);
    }

    
    
    function getAmountsOutUnderlying(
                    address factory,
                    address ctokenFactory,
                    uint256 amountIn,
                    address[] memory path,
                    address to
                )
                public
                view
                returns (uint256[] memory amounts, uint256 amountOut) {
        
        address[] memory cpath = path2cpath(ctokenFactory, path);
        uint256 rateIn = getCurrentExchangeRate(cpath[0]);
        uint256 cAmtIn = amountIn.mul(1e18).div(rateIn);
        amounts = IDeBankFactory(factory).getAmountsOut(cAmtIn, path, to);
        
        uint256 rateOut = getCurrentExchangeRate(cpath[cpath.length-1]);
        amountOut = amounts[amounts.length-1].mul(rateOut).div(1e18);
    }

    
    
    function getAmountsInUnderlying(
                    address factory,
                    address ctokenFactory,
                    uint256 amountOut,
                    address[] memory path,
                    address to
                )
                public
                view
                returns (uint256[] memory amounts, uint256 amountIn) {
        
        address[] memory cpath = path2cpath(ctokenFactory, path);
        uint256 rateOut = getCurrentExchangeRate(cpath[cpath.length-1]);
        uint256 cAmtOut = amountOut.mul(1e18).div(rateOut);
        amounts = IDeBankFactory(factory).getAmountsIn(cAmtOut, path, to);
        uint256 rateIn = getCurrentExchangeRate(cpath[0]);
        amountIn = amounts[0].mul(rateIn).div(1e18);
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
        
        (bool success,) = to.call.value(value)(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}