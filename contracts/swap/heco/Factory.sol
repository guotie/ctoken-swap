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
pragma solidity ^0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";

import "../library/SafeMath.sol";
import "../interface/IERC20.sol";
import "../interface/IDeBankFactory.sol";
import "../interface/IDeBankPair.sol";
import "../interface/IDeBankRouter.sol";

import "../interface/LErc20DelegatorInterface.sol";
import "../interface/ICToken.sol";

import "./Pair.sol";

// import "hardhat/console.sol";

contract DeBankFactory is IDeBankFactory, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint;
    address public feeTo;       
    // address public feeToSetter;
    uint256 public lpFeeRate = 0;    // 分配给LP的比例: 0: 0; n: (n/(n+1))
    // address public anchorUnderlying;
    address public anchorToken;           // 手续费锚定币种
    address public router;                // 在 pair 中使用
    bytes32 public initCodeHash;
    address public compAddr;        // compound unitroller

    // lend controller address. should be unitroller address, which is proxy of comptroller
    // LErc20DelegatorInterface public lErc20DelegatorFactory;
    // address public owner;

    // 由于0值与不存在无法区分，因此，设置的时候都在原值的基础上+1
    mapping(address => uint) public feeRateOf; // 用于设定特定用户的费率
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    // event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    // 创建时需要设置 LERC20 factory 地址 --- 改在router中设置, factory 创建 pair 时需要提供 两个token地址 两个ctoken地址
    // constructor(address _ctokenFacotry, address _anchorToken) public {
    constructor(address _anchorToken) public {
        // owner = msg.sender;
        // feeToSetter = _feeToSetter;
        // lErc20DelegatorFactory = LErc20DelegatorInterface(_ctokenFacotry);
        initCodeHash = keccak256(abi.encodePacked(type(DeBankPair).creationCode));

        // anchorUnderlying = _anchorToken;
        anchorToken = _anchorToken; // lErc20DelegatorFactory.getCTokenAddressPure(_anchorToken);
        require(anchorToken != address(0), "eToken of anchorToken is 0");
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    // function setAnchorToken(address _anchorToken) external {
    //     require(msg.sender == owner, "No auth");
    //     anchorUnderlying = _anchorToken;
    //     anchorToken = _anchorToken; // lErc20DelegatorFactory.getCTokenAddressPure(_anchorToken);
    //     require(anchorToken != address(0), "cToken of anchorToken is 0");
    // }

    // 创建交易对
    // tokenA tokenB 都不能是 cToken
    function createPair(address tokenA, address tokenB, address ctoken0, address ctoken1) external returns (address pair) {
        require(tokenA != tokenB, 'SwapFactory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'SwapFactory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'SwapFactory: PAIR_EXISTS');
        
        // guotie
        // token0 token1 不能是 cToken
        // (address ctoken0, address ctoken1) = _checkOrCreateCToken(token0, token1);

        // single check is sufficient
        bytes memory bytecode = type(DeBankPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IDeBankPair(pair).initialize(token0, token1, ctoken0, ctoken1);

        // guotie
        // set compound ctoken address
        // IDeBankPair(pair).initializeCTokenAddress(ctoken0, ctoken1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        getPair[ctoken0][ctoken1] = pair;
        getPair[ctoken1][ctoken0] = pair;
        // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        // require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        feeTo = _feeTo;
    }

    // function setFeeToSetter(address _feeToSetter) external onlyOwner {
    //     // require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
    //     require(_feeToSetter != address(0), "DeBankSwapFactory: FeeToSetter is zero address");
    //     feeToSetter = _feeToSetter;
    // }

    // 设置用户费率 所有交易对生效
    // 获取时，真实的费率-1
    function setUserFeeRate(address user, uint feeRate) external onlyOwner {
        // require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        feeRateOf[user] = feeRate + 1;
    }

    function setFeeToRate(uint256 _rate) external onlyOwner {
        // require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        require(_rate > 0, "DeBankSwapFactory: FEE_TO_RATE_OVERFLOW");
        lpFeeRate = _rate.sub(1);
    }
    
    function setPairFeeRate(address pair, uint feeRate) external onlyOwner {
        // require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        // 最高手续费不得高于2%
        require(feeRate <= 200, "DeBankSwapFactory: feeRate too high");
        IDeBankPair(pair).updateFeeRate(feeRate);
    }

    function setRouter(address _router) external onlyOwner {
        // require(msg.sender == owner, "SwapFactory: FORBIDDEN");
        router = _router;
    }
    
    function setAnchorToken(address _token) external onlyOwner {
        anchorToken = _token;
    }

    // // 原来的owner设置新的owner
    // function changeOwner(address _owner) external {
    //     // require(msg.sender == owner, "SwapFactory: FORBIDDEN");
    //     owner = _owner;
    // }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'SwapFactory: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'SwapFactory: ZERO_ADDRESS');
    }

    // guotie
    // 检查 token 不是 cToken
    // function _checkTokenIsNotCToken(address token0, address token1) private view returns (uint) {
    //     address ctoken0 = lErc20DelegatorFactory.getCTokenAddressPure(token0);
    //     if (ctoken0 == address(0)) {
    //         return 1;
    //     }

    //     address ctoken1 = lErc20DelegatorFactory.getCTokenAddressPure(token1);
    //     if (ctoken1 == address(0)) {
    //         return 2;
    //     }

    //     if(ctoken0 == ctoken1) {
    //         return 3;
    //     }
    //     return 0;
    // }

    // function _checkOrCreateCToken(address token0, address token1) private returns (address ctoken0, address ctoken1) {
    //     ctoken0 = lErc20DelegatorFactory.getCTokenAddress(token0);
    //     require(ctoken0 != address(0), 'SwapFactory: cToken is 0');
    //     ctoken1 = lErc20DelegatorFactory.getCTokenAddress(token1);
    //     require(ctoken1 != address(0), 'SwapFactory: cToken is 0');

    //     require(ctoken0 != ctoken1, 'SwapFactory: Dup cToken');
    // }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) public view returns (address pair) {
        pair = getPair[tokenA][tokenB];
        // // guotie 这里不关心顺序
        // uint err = _checkTokenIsNotCToken(tokenA, tokenB);
        // require(err == 0, "check token failed");

        // (address token0, address token1) = sortTokens(tokenA, tokenB);
        // pair = address(uint(keccak256(abi.encodePacked(
        //         hex'ff',
        //         address(this),
        //         keccak256(abi.encodePacked(token0, token1)),
        //         initCodeHash
        //     ))));
    }

    // token 都是 token 而非 ctoken !!!
    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB) public view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IDeBankPair(pairFor(tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // fetches and sorts the reserves for a pair

    // token 都是 token 而非 ctoken !!!
    function getReservesFeeRate(address tokenA, address tokenB, address to) public view 
            returns (uint reserveA, uint reserveB, uint feeRate, bool outAnchorToken) {
        (address token0,) = sortTokens(tokenA, tokenB);
        address pair = pairFor(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IDeBankPair(pair).getReserves();
        feeRate = feeRateOf[to];
        if (feeRate == 0) {
            feeRate = IDeBankPair(pair).feeRate();
        } else {
            feeRate = feeRate - 1;
        }

        // 输出货币是否是 锚定货币

        outAnchorToken = tokenA == token0 ? tokenB == anchorToken : tokenA == anchorToken;
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        // console.log("tokenA: %s tokenB: %s anchorToken: %s", tokenA, tokenB, anchorToken);
        // console.log("reserveA: %d reserveB: %d feeRate: %d", reserveA, reserveB, feeRate);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) public pure returns (uint amountB) {
        require(amountA > 0, 'SwapFactory: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public view returns (uint amountOut) {
    //     require(amountIn > 0, 'SwapFactory: INSUFFICIENT_INPUT_AMOUNT');
    //     require(reserveIn > 0 && reserveOut > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
    //     uint amountInWithFee = amountIn.mul(997);
    //     uint numerator = amountInWithFee.mul(reserveOut);
    //     uint denominator = reserveIn.mul(1000).add(amountInWithFee);
    //     amountOut = numerator / denominator;
    // }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOutFeeRate(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) public pure returns (uint amountOut) {
        require(amountIn > 0, 'SwapFactory: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(10000-feeRate);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(10000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // amountOut 是锚定货币的情况, 需要将 amountIn 的手续费部分转换为锚定货币
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // x*y = x'*y'
    // a = x' - x  输入
    // b = y - y'
    // xfee = a*0.003
    // 将 xfee 兑换为 yfee: yfee = (xfee*y)/(x+xfee)
    // 兑换后: 
    // a' = a - xfee
    // x = x+xfee   y = y-yfee
    // b = a' * y/(x+a') = a'*(y-yfee)/(x+xfee+a')=(a-xfee)*(y-yfee)/(x+xfee+a-xfee)=(a-xfee)*(y-yfee)/(x+a)
    // 最终: b = (a-xfee)*(y-yfee)/(x+a)
    // 对比: b = (a-xfee)*y/(x+a-xfee)
    function getAmountOutFeeRateAnchorToken(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) public pure returns (uint amountOut) {
        require(amountIn > 0, 'SwapFactory: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(10000-feeRate);
        uint amountInFee = amountIn.mul(10000) - amountInWithFee;
        // 这部分转换不收手续费
        uint amountOutFee = amountInFee.mul(reserveOut) / reserveIn.mul(10000).add(amountInFee);

        // amountOutFee 被截断, 可能造成 reserveOut + 1, 因此这里 -1
        reserveOut = reserveOut - amountOutFee - 1;
        reserveIn = reserveIn - amountInFee.div(10000);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.add(amountIn).mul(10000);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, address to) public view returns (uint amountIn) {
    //     require(amountOut > 0, 'SwapFactory: INSUFFICIENT_OUTPUT_AMOUNT');
    //     require(reserveIn > 0 && reserveOut > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
    //     uint numerator = reserveIn.mul(amountOut).mul(1000);
    //     uint denominator = reserveOut.sub(amountOut).mul(997);
    //     amountIn = (numerator / denominator).add(1);
    // }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // 正常计算逻辑:
    // x*y = x'*y'
    // a = x' - x  输入
    // b = y - y'
    // b = 997*a*y/(997*a+1000*x)
    // a = 1000xb/997(y-b)
    function getAmountInFeeRate(uint amountOut, uint reserveIn, uint reserveOut, uint feeRate) public pure returns (uint amountIn) {
        require(amountOut > 0, 'SwapFactory: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(10000);
        uint denominator = reserveOut.sub(amountOut).mul(10000-feeRate);
        amountIn = (numerator / denominator).add(1);
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // xfee = 0.003a
    // (x+0.997a)(y-b) = (x+xfee)(y-(fy/(x+f))) = xy
    // function getAmountInFeeRateAnchorToken(uint amountOut, uint reserveIn, uint reserveOut, uint feeRate) public pure override
    //     returns (uint amountIn) {
    //     require(amountOut > 0, 'SwapFactory: INSUFFICIENT_OUTPUT_AMOUNT');
    //     require(reserveIn > 0 && reserveOut > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
    //     uint numerator = reserveIn.mul(amountOut).mul(10000);
    //     uint denominator = reserveOut.sub(amountOut).mul(10000-feeRate);
    //     amountIn = (numerator / denominator).add(1);
    // }

    // 调用前确保已经是最新的 exchangeRate
    // ctokenAmt = amt / exchangeRate
    // function amountToCTokenAmt(address ctoken, uint amountIn) external view returns (uint cAmountIn) {
    //     uint exchangeRate = ICToken(ctoken).exchangeRateStored();
    //     return amountIn.mul(1e18).div(exchangeRate);
    // }

    // 调用前确保已经是最新的 exchangeRate
    // ctoken amount 转换为 token amt
    // tokenAmt = ctokenAmt * exchangeRate
    // function ctokenAmtToAmount(address ctoken, uint cAmountOut) external view returns (uint amountOut) {
    //     uint exchangeRate = ICToken(ctoken).exchangeRateStored();
    //     return cAmountOut.mul(exchangeRate).div(1e18);
    // }

    // path 中的 address 应该都是 token, 因为 sortToken 用的是 token
    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, address[] memory path, address to) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwapFactory: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut, uint feeRate, bool outAnchorToken) = getReservesFeeRate(path[i], path[i + 1], to);
            if (outAnchorToken) {
                amounts[i + 1] = getAmountOutFeeRateAnchorToken(amounts[i], reserveIn, reserveOut, feeRate);
            } else {
                amounts[i + 1] = getAmountOutFeeRate(amounts[i], reserveIn, reserveOut, feeRate);
            }
        }
    }

    // path 中的 address 应该都是 token, 因为 sortToken 用的是 token
    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint amountOut, address[] memory path, address to) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwapFactory: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut, uint feeRate, ) = getReservesFeeRate(path[i - 1], path[i], to);
            amounts[i - 1] = getAmountInFeeRate(amounts[i], reserveIn, reserveOut, feeRate);
        }
    }

}

