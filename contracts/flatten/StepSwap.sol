// SPDX-License-Identifier: GPL-3.0-or-later


















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

    
    uint256 public constant STEP_UNISWAP_ROUTER_TOKENS_TOKENS   = 0x000000011; 
    uint256 public constant STEP_UNISWAP_ROUTER_ETH_TOKENS      = 0x000000012; 
    uint256 public constant STEP_UNISWAP_ROUTER_TOKENS_ETH      = 0x000000013; 
    uint256 public constant STEP_EBANK_ROUTER_CTOKENS_CTOKENS   = 0x000000014;  
    uint256 public constant STEP_EBANK_ROUTER_TOKENS_TOKENS     = 0x000000015;  
    uint256 public constant STEP_EBANK_ROUTER_ETH_TOKENS        = 0x000000016;  
    uint256 public constant STEP_EBANK_ROUTER_TOKENS_ETH        = 0x000000017;  

    uint256 public constant REVERSE_SWAP_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 public constant ADDRESS_MASK      = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff; 

    
    struct SwapFlagMap {
        
        
        
        
        
        
        uint256 data;
    }

    
    struct RoutePathParams {
        address tokenIn;
        address tokenOut;
        address[] midTokens;      
        uint256 mainRoutes;           
        uint256 complex;
        uint256 parts;
        bool allowPartial;
        bool allowBurnchi;
    }

    
    struct QuoteParams {
        address to;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        address[] midTokens;      
        uint256 mainRoutes;           
        uint256 complex;
        uint256 parts;
        
        bool allowPartial;
        bool allowBurnchi;
        
        
        
        
        
        
        
        
    }

    
    struct SwapReserveRates {
        bool isEToken;
        bool allowBurnchi;
        bool allEbank;                  
        uint256 ebankAmt;
        uint256 amountIn;
        uint256 swapRoutes;             
        address tokenIn;
        address tokenOut;
        address etokenIn;
        address etokenOut;
        uint256 routes;                 
        uint256 rateIn;
        uint256 rateOut;
        uint256[]  fees;
        Exchange[]  exchanges;
        address[][] paths;        
        address[][] cpaths;       
        uint256[][][] reserves;     
        uint256[] distributes;    
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
        bytes   data;
    }

    
    struct SwapParams {
        
        
        
        
        
        
        
        
        
        
        
        bool isEToken;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmt;
        uint256 block;   
        StepExecuteParams[] steps;
    }

    
    struct Exchange {
        uint exFlag;
        address contractAddr;
    }


    
    struct SwapDistributes {
        bool        isCtoken;     
        
        address     to;           
        address     tokenIn;
        address     tokenOut;
        uint256     parts;        
        uint256     rateIn;       
        uint256     rateOut;      
        uint[]      amounts;      
        uint[]      cAmounts;     
        
        
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
    uint256 public constant FLAG_TOKEN_IN_ETH          = 0x000000000100; 
    uint256 public constant FLAG_TOKEN_TOKEN           = 0x000000000200; 
    uint256 public constant FLAG_TOKEN_CTOKEN          = 0x000000000400; 
    uint256 public constant FLAG_TOKEN_OUT_ETH         = 0x000000000800; 
    
    
    

    uint256 internal constant _MASK_PARTS           = 0x00000000000000000000ff; 
    uint256 internal constant _MASK_MAIN_ROUTES     = 0x00ff000000000000000000; 
    uint256 internal constant _MASK_COMPLEX_LEVEL   = 0x0300000000000000000000; 
    uint256 internal constant _MASK_PARTIAL_FILL    = 0x0400000000000000000000; 
    uint256 internal constant _MASK_BURN_CHI        = 0x0800000000000000000000; 

    
    uint256 internal constant _SHIFT_MAIN_ROUTES    = 72; 
    uint256 internal constant _SHIFT_COMPLEX_LEVEL  = 80; 

    
    function tokenIsToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_TOKEN) != 0;
    }

    function tokenIsToken(uint flag) public pure returns (bool) {
        return (flag & FLAG_TOKEN_TOKEN) != 0;
    }
    
    
    function tokenIsCToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_CTOKEN) != 0;
    }

    
    function tokenInIsETH(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_IN_ETH) != 0;
    }

    
    function tokenOutIsETH(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_OUT_ETH) != 0;
    }

    
    function getParts(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_PARTS);
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






library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function _sendLogPayload(bytes memory payload) private view {
		uint256 payloadLength = payload.length;
		address consoleAddress = CONSOLE_ADDRESS;
		assembly {
			let payloadStart := add(payload, 32)
			let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int)", p0));
	}

	function logUint(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
	}

	function log(uint p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
	}

	function log(uint p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
	}

	function log(uint p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
	}

	function log(string memory p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
	}

	function log(uint p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
	}

	function log(uint p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
	}

	function log(uint p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
	}

	function log(uint p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
	}

	function log(uint p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
	}

	function log(uint p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
	}

	function log(uint p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
	}

	function log(uint p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
	}

	function log(uint p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
	}

	function log(uint p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
	}

	function log(uint p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
	}

	function log(bool p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
	}

	function log(bool p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
	}

	function log(bool p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
	}

	function log(address p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
	}

	function log(address p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
	}

	function log(address p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}








library PathFinder {
    function findBestDistribution(
        uint256 s,                
        int256[][] memory amounts 
    )
        public
        view
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
        console.log("amounts length 3:", n, s, amounts[0].length);

        distribution = new uint256[](n);

        uint256 partsLeft = s;
        for (uint curExchange = n - 1; partsLeft > 0; curExchange--) {
            distribution[curExchange] = partsLeft - parent[curExchange][partsLeft];
            partsLeft = parent[curExchange][partsLeft];
        }

        returnAmount = (answer[n - 1][s] <= 0) ? int256(0) : answer[n - 1][s];
        console.log("return amount:", uint(returnAmount));
        for (uint i = 0; i < n; i ++) {
            console.log("distribution[%d]: %d %d", i, distribution[i], uint(amounts[i][s]));
        }
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



















interface ILHT {

    function mint() external payable returns (uint, uint);
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







interface ICTokenFactory {
    
    function getCTokenAddressPure(address token) external view returns (address);

    
    function getTokenAddress(address cToken) external view returns (address);
}



















interface IFactory {

    function router() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);
    
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountOut);
    
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
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

    
    function swapExactTokensForETH(
            uint amountIn,
            uint amountOutMin,
            address[] calldata path,
            address to,
            uint deadline
        )
        external
        returns (uint[] memory amounts);

    function addLiquidityETH(
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

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
}



















interface IDeBankRouter {
    function factory() external view returns (address);
    
    
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

}






interface IDeBankFactory {
    function router() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    function pairFor(address tokenA, address tokenB) external view returns (address pair);

    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);

    function getAmountsOut(uint256 amountIn, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    
    

    function setPairFeeRate(address pair, uint feeRate) external;

    function getReservesFeeRate(address tokenA, address tokenB, address to) 
                external view returns (uint reserveA, uint reserveB, uint feeRate, bool outAnchorToken);

    function getAmountOutFeeRate(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountOut);

    function getAmountOutFeeRateAnchorToken(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountOut);
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

    
    function _itemInArray(address[] memory vec, address item) private pure returns (bool) {
        for (uint i = 0; i < vec.length; i ++) {
            if (item == vec[i]) {
                return true;
            }
        }
        return false;
    }

    
    function calcPathComplex(
                address[][] memory paths,
                uint idx,
                uint complex,
                address token1,
                address[] memory midTokens,
                address[] memory path
            )
            internal
            pure
            returns (uint) {
        if (complex == 0) {
            address[] memory npath = new address[](path.length+1);
            for (uint i = 0; i < path.length; i ++) {
                npath[i] = path[i];
            }
            npath[npath.length-1] = token1;
            paths[idx] = npath;
            return idx+1;
        }

        for (uint i = 0; i < midTokens.length; i ++) {
            address[] memory npath = new address[](path.length+1);
            for (uint ip = 0; ip < path.length; ip ++) {
                npath[ip] = path[ip];
            }
            address midToken = midTokens[i];
            npath[npath.length-1] = midToken;

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
        return idx;
    }

    
    function allPaths(
                address tokenIn,
                address tokenOut,
                address[] memory midTokens,
                uint complexLevel
            )
            public
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
                )
                internal
                pure
                returns(uint256[] memory rets) {
        rets = new uint256[](parts);
        for (uint i = 0; i < parts; i++) {
            rets[i] = value.mul(i + 1).div(parts);
        }
    }

    
    function calcDistributes(
                    DataTypes.Exchange memory ex,
                    address[] memory path,
                    uint[] memory amts,
                    address to
                )
                public
                view
                returns (uint256[] memory distributes) {
        uint flag = ex.exFlag;
        address addr = ex.contractAddr;

        if (flag == EXCHANGE_UNISWAP_V2 || flag == EXCHANGE_UNISWAP_V3) {
            distributes = uniswapLikeSwap(addr, path, amts);
            
            
            
        } else if (flag == EXCHANGE_EBANK_EX) {
            distributes = new uint256[](amts.length+1);
            for (uint i = 0; i < amts.length; i ++) {
                distributes[i+1] = ebankSwap(addr, path, amts[i], to);
            }
        } else {
            
        }
        
    }

    
    function isUniswapLikeExchange(uint flag) public pure returns (bool) {
        if (flag == EXCHANGE_UNISWAP_V2 ||
            flag == EXCHANGE_UNISWAP_V3 ||
            flag == EXCHANGE_EBANK_EX) {
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

    
    function calcCTokenExchangeRate(ICToken ctoken) public view returns (uint) {
        uint rate = ctoken.exchangeRateStored();
        uint supplyRate = ctoken.supplyRatePerBlock();
        uint lastBlock = ctoken.accrualBlockNumber();
        uint blocks = block.number.sub(lastBlock);
        uint inc = rate.mul(supplyRate).mul(blocks);
        return rate.add(inc);
    }

    
    function convertCompoundCtokenMinted(
                    address ctoken,
                    uint[] memory amounts,
                    uint parts
                )
                public
                view
                returns (uint256[] memory) {
        uint256 rate = calcCTokenExchangeRate(ICToken(ctoken));
        uint256[] memory cAmts = new uint256[](parts);

        for (uint i = 0; i < parts; i ++) {
            cAmts[i] = amounts[i].mul(1e18).div(rate);
        }
        return cAmts;
    }

    
    function convertCompoundTokenRedeemed(
                    address ctoken,
                    uint[] memory cAmounts,
                    uint parts
                )
                public
                view
                returns (uint256[] memory) {
        uint256 rate = calcCTokenExchangeRate(ICToken(ctoken));
        uint256[] memory amts = new uint256[](parts);

        for (uint i = 0; i < parts; i ++) {
            amts[i] = cAmounts[i].mul(rate).div(1e18);
        }
        return amts;
    }

    
    
    
    function compoundMintToken(
                    address ctoken,
                    uint256 amount
                )
                public
                returns (uint256) {
        uint256 balanceBefore = IERC20(ctoken).balanceOf(address(this));
        ICToken(ctoken).mint(amount);

        return IERC20(ctoken).balanceOf(address(this)).sub(balanceBefore);
    }

    
    function compoundMintETH(
                    address weth,
                    uint amount
                )
                public
                returns (uint256) {
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

    
    

    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    function calculateUniswapFormula(uint256 fromBalance, uint256 toBalance, uint256 amount) internal pure returns(uint256) {
        if (amount == 0) {
            return 0;
        }
        return amount.mul(toBalance).mul(997).div(
            fromBalance.mul(1000).add(amount.mul(997))
        );
    }

    function getReserves(
                    address router,
                    address[] memory path
                )
                public
                view
                returns (uint[][] memory reserves) {

        uint plen = path.length;
        reserves = new uint[][](plen);
        IFactory factory = IFactory(IRouter(router).factory());
        for (uint i = 0; i < plen - 1; i ++) {
            
            
            address pair = factory.getPair(path[i], path[i+1]);
            uint[] memory res = new uint[](2);
            if (pair == address(0)) {
                reserves[i] = res;
                
                continue;
            }
            
            
            
            
            
            
            
            
            
            res[0] = IERC20(path[i]).balanceOf(pair);
            res[1] = IERC20(path[i+1]).balanceOf(pair);
            reserves[i] = res;
            
            
            
        }
    }

    function uniswapLikeSwap(
                    address router,
                    address[] memory path,
                    uint256[] memory amountIns
                )
                public
                view
                returns (uint[] memory amountOuts) {
        uint plen = path.length;
        uint[] memory reserves = new uint[](plen);
        amountOuts = new uint[](amountIns.length+1);

        IFactory factory = IFactory(IRouter(router).factory());
        for (uint i = 0; i < plen - 1; i ++) {
            
            
            address pair = factory.getPair(path[i], path[i+1]);
            if (pair == address(0)) {
                return amountOuts;
            }
            reserves[i] = IERC20(path[i]).balanceOf(pair);
            reserves[i+1] = IERC20(path[i+1]).balanceOf(pair);
            if (reserves[i] == 0 || reserves[i+1] == 0) {
                return amountOuts;
            }
        }

        uint[] memory tmp = new uint[](plen);
        for (uint i = 0; i < amountIns.length; i ++) {
            tmp[0] = amountIns[i];
            for (uint j = 0; j < plen - 1; j ++) {
                tmp[j + 1] = calculateUniswapFormula(reserves[j], reserves[j+1], tmp[j]);
            }
            amountOuts[i+1] = tmp[plen-1];
        }

        
        
        
        
        
        
        
        
        
        
        
        
        
        
    }

    
    function ebankSwap(
                    address router,
                    address[] memory path,
                    uint256 amountIn,
                    address to
                )
                public
                view
                returns (uint) {
        IDeBankFactory factory = IDeBankFactory(IDeBankRouter(router).factory());
        uint[] memory amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i = 0; i < path.length - 1; i ++) {
            address pair = factory.getPair(path[i], path[i+1]);
            if (pair == address(0)) {
                return 0;
            }
            (uint ra, uint rb, uint feeRate, bool outAnchorToken) = factory.getReservesFeeRate(path[i], path[i + 1], to);
            if (ra == 0 || rb == 0) {
                return 0;
            }
            if (outAnchorToken) {
                amounts[i + 1] = factory.getAmountOutFeeRateAnchorToken(amounts[i], ra, rb, feeRate);
            } else {
                amounts[i + 1] = factory.getAmountOutFeeRate(amounts[i], ra, rb, feeRate);
            }
        }
        
        return amounts[amounts.length - 1];
        
        
    }

    
    function curveSwap(
                    address addr,
                    uint i,
                    uint j,
                    uint dx
                )
                public
                view
                returns (uint) {
        return ICurve(addr).get_dy(int128(i), int128(j), dx);
    }
}










































contract StepSwapStorage {
    mapping(uint => DataTypes.Exchange) public swaps;  
    uint public exchangeCount;  
    IWETH public weth;
    ILHT public ceth;  
    ICTokenFactory public ctokenFactory;

    uint internal constant _HALF_MAX_UINT = uint(-1) >> 1;                            
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

    receive() external payable {

    }

    function isTokenToken(address token) public view returns (bool) {
        address ctoken = ctokenFactory.getCTokenAddressPure(token);
        
        if (ctoken != address(0)) {
            return true;
        }
        
        if (ctokenFactory.getTokenAddress(token) != address(0)) {
            
            return false;
        }
        return true;
    }

    function _getCTokenAddressPure(address token) internal view returns (address ctoken) {
        if (token == address(0)) {
            return address(ceth);
        }
        return ctokenFactory.getCTokenAddressPure(token);
    }

    function _getTokenAddressPure(address ctoken) internal view returns (address token) {
        if (token == address(ceth)) {
            return address(0);
        }
        return ctokenFactory.getTokenAddress(ctoken);
    }

    
    
    function getRoutesPaths(
                    DataTypes.QuoteParams memory args
                )
                public
                view
                returns (
                    
                    uint routes,
                    address[][] memory paths,
                    address[][] memory cpaths,
                    DataTypes.Exchange[] memory exchanges
                    ) {
        (routes, exchanges) = calcExchangeRoutes(args.midTokens.length, args.complex);

        address ti = args.tokenIn;
        address to = args.tokenOut;
        address cti = args.tokenIn;
        address cto = args.tokenOut;
        if (args.tokenIn == address(0)) {
            
            cti = address(ceth);
        } else if (isTokenToken(args.tokenIn)) {
            
            cti = _getCTokenAddressPure(ti);
        } else {
            
            ti = ctokenFactory.getTokenAddress(cti);
        }

        if (args.tokenOut == address(0)) {
            
            cto = address(ceth);
        } else if (isTokenToken(args.tokenOut)) {
            
            require(isTokenToken(args.tokenIn) || args.tokenIn == address(0), "both token in/out should be token");
            cto = _getCTokenAddressPure(to);
        } else {
            
            require(isTokenToken(args.tokenIn) == false || args.tokenIn == address(0), "both token in/out should be etoken");
            to = ctokenFactory.getTokenAddress(cto);
        }

        
        
        
        
        
        
        
        
        

        if (ti == address(0)) {
            ti = address(weth);
        }
        if (to == address(0)) {
            to = address(weth);
        }
        
        address[] memory midCTokens = new address[](args.midTokens.length);
        for (uint i = 0; i < args.midTokens.length; i ++) {
            midCTokens[i] = _getCTokenAddressPure(args.midTokens[i]);
        }
        address[][] memory tmp = Exchanges.allPaths(ti, to, args.midTokens, args.complex);
        paths = allSwapPaths(tmp);
        tmp = Exchanges.allPaths(cti, cto, midCTokens, args.complex);
        cpaths = allSwapPaths(tmp);
    }

    function allSwapPaths(
                    address[][] memory ps
                )
                public
                view
                returns (address[][] memory paths) {
        uint total = 0;
        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange storage ex = swaps[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }
            
            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                total += ps.length;
            } else {
                
                total ++;
            }
        }
        paths = new address[][](total);
        uint pIdx = 0;
        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange storage ex = swaps[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }
            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                for (uint j = 0; j < ps.length; j ++) {
                    paths[pIdx] = ps[j];
                    pIdx ++;
                }
            } else {
                
                paths[pIdx] = new address[](1);
                pIdx ++;
            }
        }
    }

    
    function getSwapReserveRates(
                DataTypes.QuoteParams memory args
            )
            public
            view
            returns (DataTypes.SwapReserveRates memory params) {
        require(exchangeCount > 0, "no exchanges");
        
        (
            
            params.routes,
            params.paths,
            params.cpaths,
            params.exchanges
        ) = getRoutesPaths(args);

        console.log("routes: %d paths: %d exchanges: %d", params.routes, params.paths.length, params.exchanges.length);
        if (isTokenToken(args.tokenIn)) {
            require(isTokenToken(args.tokenOut), "tokenOut should be token too");
            address ctokenIn = _getCTokenAddressPure(args.tokenIn);
            address ctokenOut = _getCTokenAddressPure(args.tokenOut);
            params.isEToken  = false;
            params.tokenIn   = args.tokenIn;
            params.tokenOut  = args.tokenOut;
            params.etokenIn  = ctokenIn;
            params.etokenOut = ctokenOut;
            params.rateIn    = Exchanges.calcCTokenExchangeRate(ICToken(ctokenIn));
            params.rateOut   = Exchanges.calcCTokenExchangeRate(ICToken(ctokenOut));
        } else {
            require(isTokenToken(args.tokenOut) == false, "tokenOut should be etoken too");
            params.isEToken  = true;
            params.etokenIn  = args.tokenIn;
            params.etokenOut = args.tokenOut;
            params.tokenIn   = ctokenFactory.getTokenAddress(args.tokenIn);
            params.tokenOut  = ctokenFactory.getTokenAddress(args.tokenOut);
            params.rateIn    = Exchanges.calcCTokenExchangeRate(ICToken(args.tokenIn));
            params.rateOut   = Exchanges.calcCTokenExchangeRate(ICToken(args.tokenOut));
        }

        
        
        
        
        

        params.fees = new uint[](params.routes);
        params.reserves = new uint[][][](params.routes);
        for (uint i = 0; i < params.paths.length; i ++) {
            DataTypes.Exchange memory ex = params.exchanges[i];
            address[] memory path = params.paths[i];

            
            
            
            

            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                if (Exchanges.isEBankExchange(ex.exFlag)) { 
                    
                    params.fees[i] = 30;
                    params.reserves[i] = Exchanges.getReserves(ex.contractAddr, params.cpaths[i]);
                } else {
                    
                    params.fees[i] = 30;
                    params.reserves[i] = Exchanges.getReserves(ex.contractAddr, path);
                }
            } else {
                
                params.fees[i] = 4;
            }
        }
    }

    
    function buildSwapRouteSteps(
                    DataTypes.SwapReserveRates memory args
                )
                public
                view
                returns (DataTypes.SwapParams memory params) {
        uint steps = args.swapRoutes;

        params.amountIn = args.amountIn;
        if (args.isEToken) {
            params.tokenIn = args.etokenIn;
            params.tokenOut = args.etokenOut;
            
            if (args.allEbank == false) {
                steps += 1;
            }
        } else {
            params.tokenIn = args.tokenIn;
            params.tokenOut = args.tokenOut;
        }
        params.isEToken = args.isEToken;

        uint stepIdx = 0;
        params.steps = new DataTypes.StepExecuteParams[](steps);
        if (args.isEToken && args.allEbank == false) {
            
            params.steps[stepIdx] = _buildCompoundRedeemStep(args.amountIn.sub(args.ebankAmt), args.etokenIn);
            stepIdx ++;
        }

        if (args.ebankAmt > 0) {
            
            address ebankRouter = _getEBankContract();
            address[] memory path;
            address[] memory cpath;
            uint i = 0;
            for (; i < args.distributes.length; i ++) {
                if (args.distributes[i] == 0) {
                    continue;
                }

                DataTypes.Exchange memory ex = args.exchanges[i];
                if (Exchanges.isEBankExchange(ex.exFlag)) {
                    path = args.paths[i];
                    cpath = args.cpaths[i];
                    break;
                }
            }
            console.log("build ebank step: amt=%d", args.ebankAmt);
            require(i != args.distributes.length, "no ebank");
            params.steps[stepIdx] = buildEbankSwapStep(
                                                ebankRouter,
                                                path,
                                                cpath,
                                                args.ebankAmt,
                                                args.isEToken
                                            );
            stepIdx ++;
        }

        for (uint i = 0; i < args.distributes.length; i ++) {
            if (args.distributes[i] == 0) {
                continue;
            }

            DataTypes.Exchange memory ex = args.exchanges[i];
            if (Exchanges.isEBankExchange(ex.exFlag)) {
                continue;
            }

            if (Exchanges.isUniswapLikeExchange(ex.exFlag)) {
                params.steps[stepIdx] = buildUniSwapStep(
                                            ex.contractAddr,
                                            args.paths[i],
                                            args.distributes[i],
                                            true
                                        );
            } else {
                
                DataTypes.StepExecuteParams memory step;
                step.flag = 0;
                params.steps[stepIdx] = step;
            }

            stepIdx ++;
        }

        
        
        
        
        params.block = block.number;
    }

    function _isETH(address token) private view returns (bool) {
        if (token == address(weth) || token == address(0)) {
            return true;
        }
        return false;
    }

    function _isCETH(address token) private view returns (bool) {
        if (token == address(ceth) || token == address(0)) {
            return true;
        }
        return false;
    }

    
    function buildEbankSwapStep(
                    address router,
                    address[] memory path,
                    address[] memory cpath,
                    uint256 amtIn,
                    bool isEToken                
                )
                public
                view
                returns (DataTypes.StepExecuteParams memory step) {
        DataTypes.UniswapRouterParam memory rp;
        if (!isEToken) {
            
            address tokenIn = cpath[0];
            address tokenOut = cpath[cpath.length-1];

            if (_isCETH(tokenIn)) {
                step.flag = DataTypes.STEP_EBANK_ROUTER_ETH_TOKENS;
            } else if (_isCETH(tokenOut)) {
                step.flag = DataTypes.STEP_EBANK_ROUTER_TOKENS_ETH;
            } else {
                step.flag = DataTypes.STEP_EBANK_ROUTER_TOKENS_TOKENS;
            }
            
            rp.path = path;
        } else {
            step.flag = DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS;
            rp.path = cpath;
        }

        rp.contractAddr = router;
        rp.amount = amtIn;

        step.data = abi.encode(rp);
    }

    
    function buildUniSwapStep(
                    address router,
                    address[] memory path,
                    uint256 amtIn,
                    bool useRouter
                )
                public
                view
                returns (DataTypes.StepExecuteParams memory step) {
            require(useRouter, "must be router");
        
            address tokenIn = path[0];
            address tokenOut = path[path.length-1];

            if (_isETH(tokenIn)) {
                step.flag = DataTypes.STEP_UNISWAP_ROUTER_ETH_TOKENS;
            } else if (_isETH(tokenOut)) {
                step.flag = DataTypes.STEP_UNISWAP_ROUTER_TOKENS_ETH;
            } else {
                step.flag = DataTypes.STEP_UNISWAP_ROUTER_TOKENS_TOKENS;
            }
            DataTypes.UniswapRouterParam memory rp;
            rp.contractAddr = router;
            rp.amount = amtIn;
            rp.path = path;

            step.data = abi.encode(rp);
        
            
            
            
            
            
            
            
            

            
            
        
    }

    
    function _approve(IERC20 tokenIn, address spender) private {
        if (tokenIn.allowance(address(this), spender) < _HALF_MAX_UINT) {
            tokenIn.approve(spender, uint(-1));
        }
    }

    

    function _doRouterSetp(uint flag, address tokenIn, address router, uint amt, address[] memory path, uint deadline) private {
        
            
            
        console.log("_doRouterSetp flag:", flag);
        if (flag == DataTypes.STEP_UNISWAP_ROUTER_ETH_TOKENS || flag == DataTypes.STEP_EBANK_ROUTER_ETH_TOKENS) {
            
            if (amt == 0) {
                amt = address(this).balance;
            }
            if (flag == DataTypes.STEP_UNISWAP_ROUTER_ETH_TOKENS) {
                IRouter(router).swapExactETHForTokens{value: amt}(0, path, address(this), deadline);
            } else {
                IDeBankRouter(router).swapExactETHForTokensUnderlying{value: amt}(0, path, address(this), deadline);
            }
        } else {
            if (amt == 0) {
                amt = IERC20(tokenIn).balanceOf(address(this));
            }
            
            _approve(IERC20(tokenIn), router);
            if (flag == DataTypes.STEP_UNISWAP_ROUTER_TOKENS_TOKENS) {
                console.log("uniswap token->token:", path.length, amt, IERC20(tokenIn).balanceOf(address(this)));
                IRouter(router).swapExactTokensForTokens(amt, 0, path, address(this), deadline);
            } else if (flag == DataTypes.STEP_UNISWAP_ROUTER_TOKENS_ETH) {
                IRouter(router).swapExactTokensForETH(amt, 0, path, address(this), deadline);
            } else if (flag == DataTypes.STEP_EBANK_ROUTER_CTOKENS_CTOKENS) {
                console.log("ebank ctoken->ctoken:", path.length, amt, IERC20(tokenIn).balanceOf(address(this)));
                IDeBankRouter(router).swapExactTokensForTokens(amt, 0, path, address(this), deadline);
            } else if (flag == DataTypes.STEP_EBANK_ROUTER_TOKENS_TOKENS) {
                console.log("ebank token->token:", path.length, amt, IERC20(tokenIn).balanceOf(address(this)));
                IDeBankRouter(router).swapExactTokensForTokensUnderlying(amt, 0, path, address(this), deadline);
            } else {
                
                require(flag == DataTypes.STEP_EBANK_ROUTER_TOKENS_ETH, "invalid flag");
                IDeBankRouter(router).swapExactTokensForETHUnderlying(amt, 0, path, address(this), deadline);
            }
        }

    }

    
    
    function unoswap(DataTypes.SwapParams memory args) public payable {
        address tokenIn = args.tokenIn;

        if (tokenIn == address(0)) {
            require(msg.value >= args.amountIn, "not enough value");
        } else {
            
            TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), args.amountIn);
        }

        console.log("transfer to stepswap success, steps: %d amountIn: %d", args.steps.length, args.amountIn);

        address tokenOut = args.tokenOut;
        
        uint deadline = block.timestamp + 600;
        if (args.isEToken) {
            
            uint stepIdx = 0;
            uint endIdx = args.steps.length;
            bool redeemMint = false;
            uint total = 0;   
            uint originAmt = 0;
            if (args.steps[0].flag == DataTypes.STEP_COMPOUND_REDEEM_TOKEN) {
                redeemMint = true;
                stepIdx ++;
                endIdx -= 1;
                DataTypes.CompoundRedeemParam memory rp = abi.decode(args.steps[0].data, (DataTypes.CompoundRedeemParam));
                
                ICToken(rp.ctoken).redeem(rp.amount);
                originAmt = rp.amount;
                if (rp.ctoken == address(ceth)) {
                    total = address(this).balance;
                } else {
                    address token = ctokenFactory.getTokenAddress(rp.ctoken);
                    total = IERC20(token).balanceOf(address(this));
                }
            }

            
            if (args.amountIn > originAmt) {
                _approve(IERC20(tokenIn), address(this));
                DataTypes.UniswapRouterParam memory param = abi.decode(args.steps[stepIdx].data, (DataTypes.UniswapRouterParam));
                IDeBankRouter(param.contractAddr).swapExactTokensForTokens(param.amount, 0, param.path, address(this), deadline);
                stepIdx ++;
            }

            address ctokenIn = _getTokenAddressPure(tokenIn);
            for (; stepIdx < endIdx; stepIdx ++) {
                
                uint amount = 0;
                DataTypes.StepExecuteParams memory step = args.steps[stepIdx];
                
                
                
                
                
                
                
                    DataTypes.UniswapRouterParam memory param = abi.decode(step.data, (DataTypes.UniswapRouterParam));
                    if (stepIdx != endIdx - 1) {
                        amount = param.amount.mul(total).div(originAmt);
                    }
                    _doRouterSetp(step.flag, ctokenIn, param.contractAddr, amount, param.path, deadline);
                
            }

            if (redeemMint) {
                
                if (tokenOut == address(ceth)) {
                    uint amt = address(this).balance;
                    ceth.mint{value: amt}();
                } else {
                    address token = ctokenFactory.getTokenAddress(tokenOut);
                    _approve(IERC20(token), tokenOut);
                    ICToken(tokenOut).mint(IERC20(token).balanceOf(address(this)));
                }
            }
        } else {
            
            console.log("steps:", args.steps.length);
            for (uint i = 0; i < args.steps.length; i ++) {
                uint flag = args.steps[i].flag;
                console.log("swap %d %d", i, flag);
                DataTypes.StepExecuteParams memory step = args.steps[i];
                
                
                
                
                    DataTypes.UniswapRouterParam memory param = abi.decode(step.data, (DataTypes.UniswapRouterParam));
                    _doRouterSetp(flag, tokenIn, param.contractAddr, param.amount, param.path, deadline);
                
            }
        }

        
        
        if (args.tokenOut == address(0)) {
            uint balance = address(this).balance;
            require(balance >= args.minAmt, "less than minAmt");
            console.log("eth balance:", balance);
            TransferHelper.safeTransferETH(msg.sender, balance);
        } else {
            uint balance = IERC20(tokenOut).balanceOf(address(this));
            require(balance >= args.minAmt, "less than minAmt");
            console.log("token balance:", balance);
            TransferHelper.safeTransfer(tokenOut, msg.sender, balance);
        }
    }

    
    function calcExchangeRoutes(
                    uint midTokens,
                    uint complexLevel
                )
                public
                view
                returns (uint total, DataTypes.Exchange[] memory exchanges) {
        uint i;

        
        for (i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange storage ex = swaps[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }

            total += Exchanges.getExchangeRoutes(ex.exFlag, midTokens, complexLevel);
        }
        exchanges = new DataTypes.Exchange[](total);
        uint exIdx = 0;
        for (i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange storage ex = swaps[i];

            if (ex.contractAddr == address(0)) {
                continue;
            }

            uint count = Exchanges.getExchangeRoutes(ex.exFlag, midTokens, complexLevel);
            for (uint j = 0; j < count; j ++) {
                exchanges[exIdx].exFlag = ex.exFlag;
                exchanges[exIdx].contractAddr = ex.contractAddr;
                exIdx ++;
            }
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

        for (uint i = 1; i < amounts.length; i ++) {
            uint amt = amounts[i];
            
                deducted[i] = int256(amt) - int256(val);
            
                
                
            
        }

        return deducted;
    }

    
    function _partAmount(uint amt, uint part, uint totalParts) private pure returns (uint) {
        return amt.mul(part).div(totalParts);
    }

    function _getEBankContract() private view returns (address ebank) {
        for (uint i = 0; i < exchangeCount; i ++) {
            DataTypes.Exchange memory ex = swaps[i];
            if (ex.exFlag == Exchanges.EXCHANGE_EBANK_EX && ex.contractAddr != address(0)) {
                ebank = ex.contractAddr;
                break;
            }
        }
        require(ebank != address(0), "not found ebank");
        return ebank;
    }

    function _buildCompoundMintStep(
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

    
    
    function _buildCompoundRedeemStep(
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


    function _buildEBankRouteStep(
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

    
    
    

    function addSwap(uint flag, address addr) external onlyOwner {
        DataTypes.Exchange storage ex = swaps[exchangeCount];
        ex.exFlag = flag;
        ex.contractAddr = addr;

        exchangeCount ++;
    }

    function removeSwap(uint i) external onlyOwner {
        DataTypes.Exchange storage ex = swaps[i];

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