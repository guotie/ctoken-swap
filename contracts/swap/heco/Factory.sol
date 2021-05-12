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
pragma solidity =0.7.6;

import "../library/SafeMath.sol";
import "../interface/IERC20.sol";
import "../../common/IMdexFactory.sol";
import "../../common/IMdexPair.sol";

import "../../common/LErc20DelegatorInterface.sol";
import "../../common/CTokenInterfaces.sol";

interface IHswapV2Callee {
    function hswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

interface IMdexERC20 {
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
}

contract MdexERC20 is IMdexERC20 {
    using SafeMath for uint;

    string public constant override name = 'HSwap LP Token';
    // function name() override external pure returns (string memory) {
    //     return "HSwap LP Token";
    // }
    string public constant override symbol = 'HMDX';
    uint8 public constant override decimals = 18;
    uint  public override totalSupply;
    mapping(address => uint) public override balanceOf;
    mapping(address => mapping(address => uint)) public override allowance;

    bytes32 public override DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant override PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public override nonces;

    // event Approval(address indexed owner, address indexed spender, uint value);
    // event Transfer(address indexed from, address indexed to, uint value);

    constructor() {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) override external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) override external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) override external returns (bool) {
        if (allowance[from][msg.sender] != uint(- 1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) override external {
        require(deadline >= block.timestamp, 'MdexSwap: EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'MdexSwap: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
}

contract MdexPair is IMdexERC20, IMdexPair {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant override MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant _SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public override factory;
    address public override token0;
    address public override token1;

    // 存到lend池中的 ctoken0 amount
    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    // 存到lend池中的 ctoken1 amount
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    address public cToken0;              // 对应 token0 在 lend 池中的 cToken
    address public cToken1;              // 对应 token1 在 lend 池中的 cToken
    uint112 public vReserve0;           // 虚拟的 token0 数量, 因为实际上 token0 已经存入 ctoken 合约中
    uint112 public vReserve1;           // 虚拟的 token1 数量, 因为实际上 token1 已经存入 ctoken 合约中

    uint public override price0CumulativeLast;
    uint public override price1CumulativeLast;
    uint public override kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint private _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1, 'MdexSwap: LOCKED');
        _unlocked = 0;
        _;
        _unlocked = 1;
    }
    // using SafeMath for uint;

    string public constant override(IMdexERC20, IMdexPair) name = 'LP Token';
    string public constant override(IMdexERC20, IMdexPair) symbol = 'HMDX';
    uint8 public constant override(IMdexERC20, IMdexPair) decimals = 18;
    uint  public override(IMdexERC20, IMdexPair) totalSupply;
    mapping(address => uint) public override(IMdexERC20, IMdexPair) balanceOf;
    mapping(address => mapping(address => uint)) public override(IMdexERC20, IMdexPair) allowance;

    bytes32 public override(IMdexERC20, IMdexPair) DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant override(IMdexERC20, IMdexPair) PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public override(IMdexERC20, IMdexPair) nonces;

    // event Approval(address indexed owner, address indexed spender, uint value);
    // event Transfer(address indexed from, address indexed to, uint value);

    constructor() {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
        factory = msg.sender;
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) override(IMdexERC20, IMdexPair) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) override(IMdexERC20, IMdexPair) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) override(IMdexERC20, IMdexPair) external returns (bool) {
        if (allowance[from][msg.sender] != uint(- 1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function permit(address owner, address spender, uint value, uint deadline,
                    uint8 v, bytes32 r, bytes32 s) override(IMdexERC20, IMdexPair) external {
        require(deadline >= block.timestamp, 'Swap: EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'Swap: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
    ///////////////////////////////////////////////////////////////

    function getReserves() override public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(_SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Swap: TRANSFER_FAILED');
    }

    // event Mint(address indexed sender, uint amount0, uint amount1);
    // event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    // event Swap(
    //     address indexed sender,
    //     uint amount0In,
    //     uint amount1In,
    //     uint amount0Out,
    //     uint amount1Out,
    //     address indexed to
    // );
    // event Sync(uint112 reserve0, uint112 reserve1);

    // constructor() public {
    //     factory = msg.sender;
    // }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) override external {
        require(msg.sender == factory, 'MdexSwap: FORBIDDEN');
        // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // called once by the factory at time of deployment
    function initializeCTokenAddress(address _token0, address _token1) override external {
        require(msg.sender == factory, 'MdexSwap: FORBIDDEN');
        // sufficient check
        cToken0 = _token0;
        cToken1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(- 1) && balance1 <= uint112(- 1), 'MdexSwap: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // update reserves and, on the first call per block, price accumulators
    function _addVreserve(uint balance0, uint balance1) private {
        require(balance0 <= uint112(- 1) && balance1 <= uint112(- 1), 'MdexSwap: OVERFLOW');
        // uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        // uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        // // overflow is desired
        // if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
        //     // * never overflows, and + overflow is desired
        //     price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
        //     price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        // }
        vReserve0 += uint112(balance0);
        vReserve1 += uint112(balance1);
        // blockTimestampLast = blockTimestamp;
        // emit Sync(reserve0, reserve1);
    }

    function _delVreserve(uint balance0, uint balance1) private {
        require(balance0 <= vReserve0, "Swap: NOT ENOUGHT");
        require(balance1 <= vReserve1, "Swap: NOT ENOUGHT");
        
        vReserve0 -= uint112(balance0);
        vReserve1 -= uint112(balance1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IMdexFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast;
        // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = SafeMath.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = SafeMath.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(IMdexFactory(factory).feeToRate()).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function mintCToken(address to) override external lock returns (uint liquidity) {

    }

    // ETH/HT/BNB 不能直接 mint
    // 存入的是 token 而不是 ctoken; 如果存入的是 ctoken 或不确定, 调用 mintCToken
    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) override external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        // uint amount0 = balance0.sub(_reserve0);
        // uint amount1 = balance1.sub(_reserve1);

        // guotie
        // 分别将 token0 token1 transer 到 lend 池, 获取 ctoken0 ctoken1 的 amount0 amount1
        //
        uint cBalanceBefore0 = IERC20(cToken0).balanceOf(address(this));
        uint cBalanceBefore1 = IERC20(cToken1).balanceOf(address(this));
        // approve, mint ctoken0
        IERC20(cToken0).approve(cToken0, balance0);
        CErc20Interface(cToken0).mint(balance0);
        IERC20(cToken0).approve(cToken0, 0);

        // approve, mint ctoken1
        IERC20(cToken1).approve(cToken1, balance1);
        CErc20Interface(cToken1).mint(balance1);
        IERC20(cToken1).approve(cToken1, 0);
        uint cBalanceAfter0 = IERC20(cToken0).balanceOf(address(this));
        uint cBalanceAfter1 = IERC20(cToken1).balanceOf(address(this));

        // amount0 amount1 均为存入 lend 池后得到的 ctoken 的数量
        uint amount0 = cBalanceBefore0.sub(cBalanceAfter0); // .sub(_reserve0);
        uint amount1 = cBalanceBefore1.sub(cBalanceAfter1); // .sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;
        // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = SafeMath.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY);
            // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = SafeMath.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'MdexSwap: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(cBalanceAfter0, cBalanceAfter1, _reserve0, _reserve1);
        // _addVreserve(balance0, balance1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) override external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        // address _token0 = token0;
        // gas savings
        // address _token1 = token1;
        // gas savings
        address _ctoken0 = cToken0;
        // gas savings
        address _ctoken1 = cToken1;
        // gas savings
        // uint balance0 = IERC20(_token0).balanceOf(address(this));  // 应该是0 因为token 都存在 lend 池中
        // uint balance1 = IERC20(_token1).balanceOf(address(this));  // 应该是0 因为token 都存在 lend 池中
        uint cbalance0 = IERC20(_ctoken0).balanceOf(address(this));  // ctoken0 数量
        uint cbalance1 = IERC20(_ctoken1).balanceOf(address(this));  // ctoken1 数量
        uint liquidity = balanceOf[address(this)];  // 用户操作 burn 之前转入的 LP 代币数量

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;
        // gas savings, must be defined here since totalSupply can update in _mintFee
        uint camount0 = liquidity.mul(cbalance0) / _totalSupply;
        // using balances ensures pro-rata distribution
        uint camount1 = liquidity.mul(cbalance1) / _totalSupply;
        // using balances ensures pro-rata distribution
        require(camount0 > 0 && camount1 > 0, 'MdexSwap: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);

        // 先把 ctoken 转给 pair
        _redeemOrTransfer(to, _ctoken0, token0, camount0);
        _redeemOrTransfer(to, _ctoken1, token1, camount1);
        // _safeTransfer(_ctoken0, address(this), camount0);
        // _safeTransfer(_ctoken1, address(this), camount1);
        cbalance0 = IERC20(_ctoken0).balanceOf(address(this));
        cbalance1 = IERC20(_ctoken1).balanceOf(address(this));

        _update(cbalance0, cbalance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // 从 lend 池中把 token 赎回, camount 为 ctoken 数量
    // 赎回 token, 如果赎回成功, 将 token 转给 to; 否则, 将 ctoken 转给 to
    function _redeemOrTransfer(address to, address ctoken, address token, uint camount) private {
        uint ret;

        ret = CErc20Interface(ctoken).redeem(camount);
        if (ret == 0) {
            // success
            // 将赎回的 token 全部转给 to
            _safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        } else {
            // failed
            IERC20(ctoken).transfer(to, camount);
        }
    }

    // 从 lend 池中把 token 赎回, amount 为待赎回的 token 数量
    // 赎回 token, 如果赎回成功, 将 token 转给 to; 否则, 将 ctoken 转给 to
    function _redeemUnderlyingOrTransfer(address to, address ctoken, address token, uint amount) private {
        uint ret;

        ret = CErc20Interface(ctoken).redeemUnderlying(amount);
        if (ret == 0) {
            // success
            // 将赎回的 token 全部转给 to
            _safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        } else {
            // failed
            // 转多少呢? 这里需要获取 ctoken 和 token 的比例关系, 获取最新的 exchangeRate
            //
            uint camount = amount / CTokenInterface(ctoken).exchangeRateCurrent();
            IERC20(ctoken).transfer(to, camount);
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) override external lock {
        require(amount0Out > 0 || amount1Out > 0, 'Swap: INVALID_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'Swap: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        {// scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'Swap: INVALID_TO');
            require(to != cToken0 && to != cToken1, 'Swap: INVALID_TO');
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            // optimistically transfer tokens
            if (data.length > 0) IHswapV2Callee(to).hswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'Swap: INSUFFICIENT_INPUT_AMOUNT');
        {// scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000 ** 2), 'Swap: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    struct TokenLocalVars {
        uint balance;
        // uint balance0Adjusted;  // cToken: x1 - 0.003xin
        address token;
        address ctoken;
        uint amountIn;
        uint cAmountIn;
        uint cAmountOut;
    }
    // amount0Out: 预计得到的 token0 的数量, 在外围合约中计算好, 计算时需要考虑 exchangeRate 兑换比例
    // amount1Out: 预计得到的 token1 的数量, 在外围合约中计算好, 计算时需要考虑 exchangeRate 兑换比例
    // 转入的币应该是 token 而不是 ctoken
    function swap2x(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'Swap: INVALID_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        // 不能比较 因为 _reserve0 是 ctoken0 的数量
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'Swap: INSUFFICIENT_LIQUIDITY');
        TokenLocalVars memory vars0;
        TokenLocalVars memory vars1;

        // 这里记录转入的 token 数量
        vars0.token = token0;
        vars1.token = token1;
        vars0.ctoken = cToken0;
        vars1.ctoken = cToken1;

        // uint balance0;
        // uint balance1;
        // 这里记录转入的 token 数量
        // uint amount0In; // = IERC20(_token0).balanceOf(address(this));
        // uint amount1In; // = IERC20(_token1).balanceOf(address(this));

        // uint camount0In; // = IERC20(_token0).balanceOf(address(this));
        // uint camount1In; // = IERC20(_token1).balanceOf(address(this));
        {// scope for _token{0,1}, avoids stack too deep errors
            // address _ctoken0 = cToken0;
            // address _ctoken1 = cToken1;
            require(to != vars0.token && to != vars1.token, 'Swap: INVALID_TO');
            require(to != vars0.ctoken && to != vars1.ctoken, 'Swap: INVALID_TO');
            if (amount0Out > 0) {
                vars0.cAmountOut = amount0Out / CTokenInterface(vars0.ctoken).exchangeRateCurrent();
                _redeemUnderlyingOrTransfer(to, vars0.ctoken, vars0.token, amount0Out);
            } // _safeTransfer(_token0, to, amount0Out);
            // optimistically transfer tokens
            if (amount1Out > 0) {
                vars1.cAmountOut = amount1Out / CTokenInterface(vars1.ctoken).exchangeRateCurrent();
                _redeemUnderlyingOrTransfer(to, vars1.ctoken, vars1.token, amount1Out);
            } // _safeTransfer(_token1, to, amount1Out);
            // optimistically transfer tokens
            if (data.length > 0) IHswapV2Callee(to).hswapV2Call(msg.sender, amount0Out, amount1Out, data);

            // 这里 mint cToken
            // todo 收手续费
            vars0.amountIn = IERC20(vars0.token).balanceOf(address(this));
            vars1.amountIn = IERC20(vars1.token).balanceOf(address(this));
            require(vars0.amountIn > 0 || vars1.amountIn > 0, 'Swap: INSUFFICIENT_INPUT_AMOUNT');
            if (vars0.amountIn > 0) {
                // 将转入的 token0 存入借贷池
                CErc20Interface(vars0.ctoken).mint(vars0.amountIn);
            }
            if (vars1.amountIn > 0) {
                // 将转入的 token1 存入借贷池
                CErc20Interface(vars1.ctoken).mint(vars1.amountIn);
            }

            vars0.balance = IERC20(vars0.ctoken).balanceOf(address(this));
            vars1.balance = IERC20(vars1.ctoken).balanceOf(address(this));
        }
        // 注意: x * y = K 是两个 cToken 之间的关系
        vars0.cAmountIn = vars0.balance > _reserve0 - vars0.cAmountOut ? vars0.balance - (_reserve0 - vars0.cAmountOut) : 0;
        vars1.cAmountIn = vars1.balance > _reserve1 - vars1.cAmountOut ? vars1.balance - (_reserve1 - vars1.cAmountOut) : 0;
        // uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        {// scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = vars0.balance.mul(1000).sub(vars0.cAmountIn.mul(3));
            uint balance1Adjusted = vars1.balance.mul(1000).sub(vars1.cAmountIn.mul(3));
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000 ** 2), 'Swap: K');
        }

        _update(vars0.balance, vars1.balance, _reserve0, _reserve1);
        emit Swap(msg.sender, vars0.amountIn, vars1.amountIn, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) override external lock {
        address _token0 = token0;
        // gas savings
        address _token1 = token1;
        // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() override external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    function price(address token, uint256 baseDecimal) override public view returns (uint256) {
        if ((token0 != token && token1 != token) || 0 == reserve0 || 0 == reserve1) {
            return 0;
        }
        if (token0 == token) {
            return uint256(reserve1).mul(baseDecimal).div(uint256(reserve0));
        } else {
            return uint256(reserve0).mul(baseDecimal).div(uint256(reserve1));
        }
    }
}

contract MdexFactory is IMdexFactory {
    using SafeMath for uint256;
    address public override feeTo;
    address public override feeToSetter;
    uint256 public override feeToRate;
    bytes32 public initCodeHash;

    // lend controller address. should be unitroller address, which is proxy of comptroller
    LErc20DelegatorInterface public lErc20DelegatorFactory;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    // event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    // 创建时需要设置 LERC20 factory 地址
    constructor(address _feeToSetter, address _comptroller) {
        feeToSetter = _feeToSetter;
        lErc20DelegatorFactory = LErc20DelegatorInterface(_comptroller);
        initCodeHash = keccak256(abi.encodePacked(type(MdexPair).creationCode));
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    // 创建交易对
    // tokenA tokenB 都不能是 cToken
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'SwapFactory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'SwapFactory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'SwapFactory: PAIR_EXISTS');
        
        // guotie
        // token0 token1 不能是 cToken
        (address ctoken0, address ctoken1) = _checkOrCreateCToken(token0, token1);

        // single check is sufficient
        bytes memory bytecode = type(MdexPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IMdexPair(pair).initialize(token0, token1);

        // guotie
        // set compound ctoken address
        IMdexPair(pair).initializeCTokenAddress(ctoken0, ctoken1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        require(_feeToSetter != address(0), "MdexSwapFactory: FeeToSetter is zero address");
        feeToSetter = _feeToSetter;
    }

    function setFeeToRate(uint256 _rate) external override {
        require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        require(_rate > 0, "MdexSwapFactory: FEE_TO_RATE_OVERFLOW");
        feeToRate = _rate.sub(1);
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) public pure override returns (address token0, address token1) {
        require(tokenA != tokenB, 'SwapFactory: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'SwapFactory: ZERO_ADDRESS');
    }

    // guotie
    // 检查 token 不是 cToken
    function _checkTokenIsNotCToken(address token0, address token1) private view returns (uint) {
        address ctoken0 = lErc20DelegatorFactory.getCTokenAddressPure(token0);
        if (ctoken0 == address(0)) {
            return 1;
        }

        address ctoken1 = lErc20DelegatorFactory.getCTokenAddressPure(token1);
        if (ctoken1 == address(0)) {
            return 2;
        }

        if(ctoken0 == ctoken1) {
            return 3;
        }
        return 0;
    }

    function _checkOrCreateCToken(address token0, address token1) private returns (address ctoken0, address ctoken1) {
        ctoken0 = lErc20DelegatorFactory.getCTokenAddress(token0);
        require(ctoken0 != address(0), 'SwapFactory: cToken is 0');
        ctoken1 = lErc20DelegatorFactory.getCTokenAddress(token1);
        require(ctoken1 != address(0), 'SwapFactory: cToken is 0');

        require(ctoken0 != ctoken1, 'SwapFactory: Dup cToken');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) public view override returns (address pair) {
        // guotie 这里不关心顺序
        uint err = _checkTokenIsNotCToken(tokenA, tokenB);
        require(err == 0, "check token failed");

        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                address(this),
                keccak256(abi.encodePacked(token0, token1)),
                initCodeHash
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB) public view override returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IMdexPair(pairFor(tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) public pure override returns (uint amountB) {
        require(amountA > 0, 'SwapFactory: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure override returns (uint amountOut) {
        require(amountIn > 0, 'SwapFactory: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure override returns (uint amountIn) {
        require(amountOut > 0, 'SwapFactory: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, address[] memory path) public view override returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwapFactory: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint amountOut, address[] memory path) public view override returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwapFactory: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

library UQ112x112 {
    uint224 constant Q112 = 2 ** 112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112;
        // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
