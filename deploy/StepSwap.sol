
















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






pragma experimental ABIEncoderV2;



library DataTypes {
    
    uint256 public constant STEP_DEPOSIT_ETH           = 0x0000000001; 
    uint256 public constant STEP_WITHDRAW_WETH         = 0x0000000002; 
    uint256 public constant STEP_COMPOUND_MINT_CTOKEN  = 0x0000000003; 
    uint256 public constant STEP_COMPOUND_MINT_CETH    = 0x0000000004; 
    uint256 public constant STEP_COMPOUND_REDEEM_TOKEN = 0x0000000005; 
    
    uint256 public constant STEP_AAVE_DEPOSIT_ATOKEN   = 0x0000000007; 
    uint256 public constant STEP_AAVE_DEPOSIT_WETH     = 0x0000000008; 
    uint256 public constant STEP_AAVE_WITHDRAW_TOKEN   = 0x0000000009; 
    uint256 public constant STEP_AAVE_WITHDRAW_ETH     = 0x000000000a; 

    uint256 public constant STEP_UNISWAP_PAIR_SWAP              = 0x0000000100; 
    uint256 public constant STEP_UNISWAP_ROUTER_TOKENS_TOKENS   = 0x0000000101; 
    uint256 public constant STEP_UNISWAP_ROUTER_ETH_TOKENS      = 0x0000000102; 
    uint256 public constant STEP_UNISWAP_ROUTER_TOKENS_ETH      = 0x0000000103; 
    uint256 public constant STEP_EBANK_ROUTER_CTOKENS_CTOKENS   = 0x0000000104;  
    uint256 public constant STEP_EBANK_ROUTER_TOKENS_TOKENS     = 0x0000000105;  
    uint256 public constant STEP_EBANK_ROUTER_ETH_TOKENS        = 0x0000000106;  
    uint256 public constant STEP_EBANK_ROUTER_TOKENS_ETH        = 0x0000000107;  

    struct SwapFlagMap {
        
        
        
        
        
        
        uint256 data;
    }

    
    struct QuoteParams {
        address to;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 tokenPriceGWei;
        address fromAddress;
        address dstReceiver;
        address[] midTokens;  
        SwapFlagMap flag;
    }

    struct UniswapRouterParam {
        uint256 amount;
        address contractAddr;
        
        address[] path;
    }

    struct CompoundRedeemParam {
        uint256 amount;
        
        address ctoken;
    }

    struct UniswapPairParam {
        uint256 amount;
        
        address[] pairs;
    }

    
    struct StepExecuteParams {
        uint256 flag;           
        
        bytes data;
    }

    
    struct SwapParams {
        
        
        
        
        
        
        
        
        
        
        SwapFlagMap flag;
        uint256 minAmt;
        StepExecuteParams[] steps;
    }

    
    struct Exchange {
        uint exFlag;
        address contractAddr;
    }


    
    struct SwapDistributes {
        bool        ctokenIn;     
        bool        ctokenOut;    
        address     to;           
        address     tokenIn;
        address     tokenOut;
        uint256     parts;        
        uint256     rateIn;       
        uint256     rateOut;      
        uint[]      amounts;      
        uint[]      cAmounts;     
        address[]   midTokens;    
        address[]   midCTokens;   
        address[][] paths;        
        address[][] cpaths;       
        
        uint[]      gases;          
        uint[]      pathIdx;        
        uint[][]    distributes;    
        int256[][]  netDistributes; 
        Exchange[]  exchanges;
    }
}






library SwapFlag {
    uint256 public constant FLAG_TOKEN_IN_ETH          = 0x0000000001; 
    uint256 public constant FLAG_TOKEN_IN_TOKEN        = 0x0000000002; 
    uint256 public constant FLAG_TOKEN_IN_CTOKEN       = 0x0000000004; 
    uint256 public constant FLAG_TOKEN_OUT_ETH         = 0x0000000008; 
    uint256 public constant FLAG_TOKEN_OUT_TOKEN       = 0x0000000010; 
    uint256 public constant FLAG_TOKEN_OUT_CTOKEN      = 0x0000000020; 
    

    uint256 internal constant _MASK_PARTS           = 0x0000ff0000000000000000; 
    uint256 internal constant _MASK_MAIN_ROUTES     = 0x00ff000000000000000000; 
    uint256 internal constant _MASK_COMPLEX_LEVEL   = 0x0300000000000000000000; 
    uint256 internal constant _MASK_PARTIAL_FILL    = 0x0400000000000000000000; 
    uint256 internal constant _MASK_BURN_CHI        = 0x0800000000000000000000; 

    uint256 internal constant _SHIFT_PARTS          = 64; 
    uint256 internal constant _SHIFT_MAIN_ROUTES    = 72; 
    uint256 internal constant _SHIFT_COMPLEX_LEVEL  = 80; 

    
    function tokenInIsCToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_IN_CTOKEN) != 0;
    }

    
    function tokenOutIsCToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_OUT_CTOKEN) != 0;
    }


    
    function getParts(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_PARTS) >> _SHIFT_PARTS;
    }

    
    function getMainRoutes(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_MAIN_ROUTES) >> _SHIFT_MAIN_ROUTES;
    }

    
    function getComplexLevel(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_COMPLEX_LEVEL) >> _SHIFT_COMPLEX_LEVEL;
    }

    
    function allowPartialFill(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & _MASK_PARTIAL_FILL) != 0;
    }

    
    function burnCHI(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & _MASK_BURN_CHI) != 0;
    }
}









library PathFinder {
    function findBestDistribution(
        uint256 s,                
        int256[][] memory amounts 
    )
        public
        pure
        returns(
            int256 returnAmount,
            uint256[] memory distribution
        )
    {
        uint256 n = amounts.length;

        int256[][] memory answer = new int256[][](n); 
        uint256[][] memory parent = new uint256[][](n); 

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





abstract contract IWETH is IERC20 {
    function deposit() external virtual payable;

    function withdraw(uint256 amount) external virtual;
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
    
    
    

}







interface ICTokenFactory {
    
    function getCTokenAddressPure(address token) external view returns (address);

    
    function getTokenAddress(address cToken) external view returns (address);
}



















interface IFactory {

    function router() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}








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



















interface IDeBankRouter {
    
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



















interface ICurve {
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function get_dy_underlying(int128 i, int128 j, uint256 dx) external view returns (uint256);

    
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}










library Exchanges {
    using SafeMath for uint;
    using SafeMath for uint256;
    using SwapFlag for DataTypes.SwapFlagMap;

    uint constant public MAX_COMPLEX_LEVEL = 3;

    uint constant public EXCHANGE_UNISWAP_V2 = 1;  
    uint constant public EXCHANGE_UNISWAP_V3 = 2;  
    uint constant public EXCHANGE_EBANK_EX   = 3;  
    uint constant public EXCHANGE_CURVE      = 4;  

    uint constant public SWAP_EBANK_CTOKENS_CTOKENS      = 1;  
    uint constant public SWAP_EBANK_TOKENS_TOKENS        = 1;  
    uint constant public SWAP_EBANK_ETH_TOKENS           = 1;  
    uint constant public SWAP_EBANK_TOKENS_ETH           = 1;  

    
    
    
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
            
        }
    }

    
    function _itemInArray(address[] memory vec, address item) private pure returns (bool) {
        for (uint i = 0; i < vec.length; i ++) {
            if (item == vec[i]) {
                return true;
            }
        }
        return false;
    }

    
    function allPaths(
                address tokenIn,
                address tokenOut,
                address[] memory midTokens,
                uint complexLevel
            )
                internal
                pure
                returns (address[][] memory paths) {
        
        uint mids = midTokens.length;
        
        
        
        if (complexLevel > MAX_COMPLEX_LEVEL) {
            complexLevel = MAX_COMPLEX_LEVEL;
        }

        if (complexLevel >= mids) {
            complexLevel = mids;
        }

        uint total = uniswapRoutes(mids, complexLevel);
        uint idx = 0;
        paths = new address[][](total);
        
        

        address[] memory initialPath = new address[](1);
        initialPath[0] = tokenIn;

        
        
        
        

        for (uint i = 0; i <= complexLevel; i ++) {
            idx = calcPathComplex(paths, idx, i, tokenOut, midTokens, initialPath);
        }
    }

    function getExchangeRoutes(uint flag, uint midTokens, uint complexLevel) public pure returns (uint)  {
        if (isUniswapLikeExchange(flag)) {
            return uniswapRoutes(midTokens, complexLevel);
        }
        
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
            
        }
        
    }

    
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


    
    function depositETH(IWETH weth) public returns (uint256) {
        weth.deposit();

        return weth.balanceOf(address(this));
    }

    
    function withdrawWETH(IWETH weth, uint256 amount) public {
        weth.withdraw(amount);
    }

    
    function _calcExchangeRate(ICToken ctoken) private view returns (uint) {
        uint rate = ctoken.exchangeRateStored();
        uint supplyRate = ctoken.supplyRatePerBlock();
        uint lastBlock = ctoken.accrualBlockNumber();
        uint blocks = block.number.sub(lastBlock);
        uint inc = rate.mul(supplyRate).mul(blocks);
        return rate.add(inc);
    }

    
    function convertCompoundCtokenMinted(address ctoken, uint[] memory amounts, uint parts) public view returns (uint256[] memory) {
        uint256 rate = _calcExchangeRate(ICToken(ctoken));
        uint256[] memory cAmts = new uint256[](parts);

        for (uint i = 0; i < parts; i ++) {
            cAmts[i] = amounts[i].mul(1e18).div(rate);
        }
        return cAmts;
    }

    
    function convertCompoundTokenRedeemed(address ctoken, uint[] memory cAmounts, uint parts) public view returns (uint256[] memory) {
        uint256 rate = _calcExchangeRate(ICToken(ctoken));
        uint256[] memory amts = new uint256[](parts);

        for (uint i = 0; i < parts; i ++) {
            amts[i] = cAmounts[i].mul(rate).div(1e18);
        }
        return amts;
    }

    
    
    
    function compoundMintToken(address ctoken, uint256 amount) public returns (uint256) {
        uint256 balanceBefore = IERC20(ctoken).balanceOf(address(this));
        ICToken(ctoken).mint(amount);

        return IERC20(ctoken).balanceOf(address(this)).sub(balanceBefore);
    }

    
    function compoundMintETH(address weth, uint amount) public returns (uint256) {
        IWETH(weth).deposit{value: amount}();

        return compoundMintToken(address(weth), amount);
    }

    
    
    
    function compoundRedeemCToken(address ctoken, uint256 amount) public {
        ICToken(ctoken).redeem(amount);
    }

    
    function aaveDepositToken(address aToken) public pure {
        aToken;
    }

    
    function aaveWithdrawToken(address aToken, uint256 amt) public pure {
        aToken;
        amt;
    }

    
    

    

    
    function uniswapLikeSwap(address router, address[] memory path, uint256 amountIn) public view returns (uint) {
        uint[] memory amounts = IRouter(router).getAmountsOut(amountIn, path);
        return amounts[amounts.length - 1];
    }

    
    function ebankSwap(address router, address[] memory path, uint256 amountIn, address to) public view returns (uint) {
        uint[] memory amounts = IDeBankRouter(router).getAmountsOut(amountIn, path, to);
        return amounts[amounts.length - 1];
    }

    
    function curveSwap(address addr, uint i, uint j, uint dx) public view returns (uint) {
        return ICurve(addr).get_dy(int128(i), int128(j), dx);
    }
}








































contract StepSwapStorage {
    mapping(uint => DataTypes.Exchange) public exchanges;  
    uint public exchangeCount;  
    IWETH public weth;
    ILHT public ceth;  
    ICTokenFactory public ctokenFactory;
}


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
            
                deducted[i] = int256(amt) - int256(val);
            
                
                
            
        }

        return deducted;
    }

    
    function _calcUnoswapExchangeReturn(
                DataTypes.Exchange memory ex,
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint tokenPriceGWei
            ) internal view returns (uint) {
        uint gas = 106000;  

        for (uint i = 0; i < sd.paths.length; i ++) {
            address[] memory path = sd.paths[i];
            uint[] memory amts;

            
            if (sd.ctokenIn == false) {
                amts = Exchanges.calcDistributes(ex, path, sd.amounts, sd.to);
                if (sd.ctokenOut == true) {
                    
                    for (uint j = 0; j < sd.amounts.length; j ++) {
                        amts[j] = amts[j].mul(1e18).div(sd.rateOut);
                    }
                    gas += 193404;
                }
            } else {
                
                
                gas += 203573;
                amts = Exchanges.calcDistributes(ex, path, sd.cAmounts, sd.to);
                if (sd.ctokenOut == true) {
                    
                    for (uint j = 0; j < sd.amounts.length; j ++) {
                        amts[j] = amts[j].mul(1e18).div(sd.rateOut);
                    }
                    
                    
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

    
    function _calcEbankExchangeReturn(
                DataTypes.Exchange memory ex,
                DataTypes.SwapDistributes memory sd,
                uint idx,
                uint tokenPriceGWei
            ) internal view returns (uint)  {
        uint gas = 106000;  
        if (sd.ctokenIn == false) {
            
            gas += 193404;
        }

        for (uint i = 0; i < sd.paths.length; i ++) {
            address[] memory path = sd.paths[i];
            uint[] memory amts;

            

            
            
            
            amts = Exchanges.calcDistributes(ex, path, sd.cAmounts, sd.to);
            if (sd.ctokenOut != true) {
                
                for (uint j = 0; j < sd.amounts.length; j ++) {
                    amts[j] = amts[j].mul(sd.rateOut).div(1e18);
                }
                
                
                gas += 203573;
            }
        
            sd.pathIdx[idx + i] = i;
            sd.distributes[idx + i] = amts;
            sd.exchanges[idx + i] = ex;
            sd.netDistributes[idx + i] = _deductGasFee(amts, gas, tokenPriceGWei);
        }

        sd.gases[idx] = gas;
    }

    
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
            
            ctokenIn = args.tokenIn;
            tokenIn = ctokenFactory.getTokenAddress(ctokenIn);
            swapDistributes.amounts = Exchanges.convertCompoundTokenRedeemed(ctokenIn, swapDistributes.cAmounts, parts);
            
            
            
            
            
        } else {
            tokenIn = args.tokenIn;
            ctokenIn = ctokenFactory.getCTokenAddressPure(tokenIn);
            swapDistributes.amounts = Exchanges.linearInterpolation(args.amountIn, parts);
            swapDistributes.cAmounts = Exchanges.convertCompoundCtokenMinted(ctokenIn, swapDistributes.amounts, parts);
            
            
            
            
            
        }

        if (swapDistributes.ctokenOut) {
            tokenOut = ctokenFactory.getTokenAddress(args.tokenOut);
            ctokenOut = args.tokenOut;
        } else {
            tokenOut = args.tokenOut;
            ctokenOut = ctokenFactory.getCTokenAddressPure(tokenOut);
        }

        swapDistributes.gases          = new uint[]  (distributeCounts); 
        swapDistributes.pathIdx        = new uint[]  (distributeCounts); 
        swapDistributes.distributes    = new uint[][](distributeCounts); 
        swapDistributes.netDistributes = new int[][](distributeCounts);  
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

    
    function getExpectedReturnWithGas(
                DataTypes.QuoteParams calldata args
            )
            external
            view
            returns (DataTypes.SwapParams memory) {
        DataTypes.SwapFlagMap memory flag = args.flag;
        require(flag.tokenInIsCToken() == flag.tokenOutIsCToken(), "both token or ctoken"); 

        
        
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
                
            }
        }
        

        
        DataTypes.SwapParams memory params;
        params.flag = args.flag;
        _makeSwapSteps(args.amountIn, swapDistributes, params);
        return params;
    }


    
    function _makeSwapSteps(
                uint amountIn,
                DataTypes.SwapDistributes memory sd,
                DataTypes.SwapParams memory params
            )
            private
            view {
        (, uint[] memory dists) = PathFinder.findBestDistribution(sd.parts, sd.netDistributes);
        

        uint routes = 0;
        uint routeIdx = 0;
        for (uint i = 0; i < dists.length; i ++) {
            if (dists[i] > 0) {
                routes ++;
            }
        }

        bool allEbank = _allSwapByEBank(sd, dists);
        if (allEbank) {
            
            
            
            
            
            return _buildEBankSteps(routes, amountIn, dists, sd, params);
        }

        if (sd.ctokenIn) {
            
            routes += 2;
        }
        DataTypes.StepExecuteParams[] memory stepArgs = new DataTypes.StepExecuteParams[](routes);

        if (sd.ctokenIn) {
            
            _fillStepArgs(amountIn, routeIdx, dists, sd, stepArgs);
            
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
        
        (uint ebankParts, uint ebankAmt) = _calcEBankAmount(amountIn, sd, dists);
        uint remaining = amountIn.sub(ebankAmt);
        uint uniswapParts = sd.parts - ebankParts;
        if (remaining > 0) {
            
            stepArgs[0] = _makeCompoundRedeemStep(remaining, ctokenIn);
            routeIdx ++;
            
        }

        
        (int256 lastUniswapIdx, int256 lastEbankIdx) = _getLastSwapIndex(sd, dists);
        for (uint i = 0; i < dists.length; i ++) {
            if (dists[i] <= 0) {
                continue;
            }

            DataTypes.Exchange memory ex = sd.exchanges[i];
            if (Exchanges.isEBankExchange(ex.exFlag)) {
                
                uint amt = _partAmount(amountIn, dists[i], sd.parts);
                stepArgs[routeIdx] = _buildEBankSwapSteps(amt, i, true, sd);
            } else if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                
                uint amt = _partAmount(remaining, dists[i], uniswapParts);
                stepArgs[routeIdx] = _buildUniswapLikeSteps(amt, i, true, sd);
            } else {
                
            }
            routeIdx ++;
            
        }
    }

    
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
        

        if (isCToken) {
            return _makeEBankRouteStep(
                        DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
                        amt,
                        sd.exchanges[idx].contractAddr,
                        sd.cpaths[sd.pathIdx[idx]]
                    );
        } else {
            if (sd.tokenIn == address(0)) {
                
                return _makeEBankRouteStep(
                            DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
                            amt,
                            sd.exchanges[idx].contractAddr,
                            sd.paths[sd.pathIdx[idx]]
                        );
                
            } else if (sd.tokenOut == address(0)) {
                
                return _makeEBankRouteStep(
                            DataTypes.STEP_EBANK_ROUTER_TOKENS_ETH,
                            amt,
                            sd.exchanges[idx].contractAddr,
                            sd.paths[sd.pathIdx[idx]]
                        );
            } else {
                
                return _makeEBankRouteStep(
                            DataTypes.STEP_EBANK_ROUTER_TOKENS_TOKENS,
                            amt,
                            sd.exchanges[idx].contractAddr,
                            sd.paths[sd.pathIdx[idx]]
                        );
            }
        }
    }

    
    
    
    
    
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
        
        params.steps = new DataTypes.StepExecuteParams[](routes);


        
            for (uint i = 0; i < dists.length; i ++) {
                if (dists[i] > 0) {
                    
                    uint amt;
                    if (routeIdx == routes - 1) {
                        amt = remaining;
                    } else {
                        amt = _partAmount(amountIn, dists[i], parts);
                        remaining -= amt;
                    }
                    if (sd.ctokenIn) {
                        
                        params.steps[routeIdx] = _makeEBankRouteStep(
                                                    DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
                                                    amt,
                                                    sd.exchanges[i].contractAddr,
                                                    sd.cpaths[sd.pathIdx[i]]
                                                );
                        routeIdx ++;
                    } else {
                        
                        
                        if (sd.tokenIn == address(0)) {
                            
                            params.steps[routeIdx] = _makeEBankRouteStep(
                                                        DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS,
                                                        amt,
                                                        sd.exchanges[i].contractAddr,
                                                        sd.paths[sd.pathIdx[i]]
                                                    );
                            routeIdx ++;
                        } else if (sd.tokenOut == address(0)) {
                            
                            params.steps[routeIdx] = _makeEBankRouteStep(
                                                        DataTypes.STEP_EBANK_ROUTER_TOKENS_ETH,
                                                        amt,
                                                        sd.exchanges[i].contractAddr,
                                                        sd.paths[sd.pathIdx[i]]
                                                    );
                        } else {
                            
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
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
    }

    function _makeCompoundMintStep(
                uint amt,
                address ctoken
            )
            private 
            view
            returns (DataTypes.StepExecuteParams memory step) {
        address token = ctokenFactory.getTokenAddress(ctoken);

        
        if (token == address(0) || token == address(weth)) {
            step.flag = DataTypes.STEP_COMPOUND_MINT_CETH;
        } else {
            step.flag = DataTypes.STEP_COMPOUND_MINT_CTOKEN;
        }
        DataTypes.CompoundRedeemParam memory rp;
        rp.amount = amt;
        rp.ctoken = ctoken;
        
        
        
            
        
        step.data = abi.encode(rp);
    }

    
    
    function _makeCompoundRedeemStep(
                uint amt,
                address ctoken
            )
            private 
            pure
            returns (DataTypes.StepExecuteParams memory step) {
        
        
        
        
        
        
        
        
        step.flag = DataTypes.STEP_COMPOUND_REDEEM_TOKEN;
        DataTypes.CompoundRedeemParam memory rp;
        rp.amount = amt;
        rp.ctoken = ctoken;
        
        
        
            
        
        step.data = abi.encode(rp);
    }

    
    
    
    
    function _makeUniswapLikeRouteStep(
                uint amt,
                uint idx,
                DataTypes.SwapDistributes memory sd
                
            )
            private 
            pure
            returns (DataTypes.StepExecuteParams memory step) {
        
        step.flag = sd.exchanges[idx].exFlag;

        DataTypes.UniswapRouterParam memory rp;
        rp.contractAddr = sd.exchanges[idx].contractAddr;
        rp.amount = amt;
        
        
        
            
        
        rp.path = sd.paths[sd.pathIdx[idx]];
        step.data = abi.encode(rp);
    }

    function _makeUniswapLikePairStep(
                uint amt,
                uint idx,
                DataTypes.SwapDistributes memory sd
                
            )
            private 
            view
            returns (DataTypes.StepExecuteParams memory step) {

        IFactory factory = IFactory(IRouter(sd.exchanges[idx].contractAddr).factory());
        DataTypes.UniswapPairParam memory rp;

        rp.amount = amt;
        
        
        
            
        
        
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
                
            )
            private 
            pure
            returns (DataTypes.StepExecuteParams memory step) {
        step.flag = flag;
        DataTypes.UniswapRouterParam memory rp;
        rp.amount = amt;
        rp.contractAddr = ebank;
        
        
        
            
        
        rp.path = path;
        step.data = abi.encode(rp);
    }

    
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
                
                if (Exchanges.isEBankExchange(flag)) {
                    ebankIdx = int256(i);
                } else if (Exchanges.isUniswapLikeExchange(flag)) {
                    uniswapIdx = int256(i);
                }
            }
        }
    }

    
    function _allSwapByEBank(
                    DataTypes.SwapDistributes memory sd,
                    uint[] memory distributes
                )
                private
                pure
                returns (bool) {
        for (uint i = 0; i < distributes.length; i ++) {
            if (distributes[i] > 0) {
                
                if (Exchanges.isEBankExchange(sd.exchanges[i].exFlag) == false) {
                    return false;
                }
            }
        }

        return true;
    }

    
    function _calcEBankAmount(
                    uint amountIn,
                    DataTypes.SwapDistributes memory sd,
                    uint[] memory distributes
                )
                private
                pure
                returns (uint part, uint amt) {
        
        
        for (uint i = 0; i < distributes.length; i ++) {
            if (distributes[i] > 0) {
                
                if (Exchanges.isEBankExchange(sd.exchanges[i].exFlag)) {
                    part += distributes[i];
                }
            }
        }

        amt = _partAmount(amountIn, part, sd.parts);
    }

    
    function unoswap(DataTypes.SwapParams calldata args) public payable returns (DataTypes.StepExecuteParams[] memory) {
        args;
    }

    
    
    

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