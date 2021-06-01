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
import "../../common/IMdexRouter.sol";

import "../../common/LErc20DelegatorInterface.sol";
import "../../common/CTokenInterfaces.sol";

import "hardhat/console.sol";

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
        require(deadline >= block.timestamp, 'DeBankSwap: EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'DeBankSwap: INVALID_SIGNATURE');
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
    uint256 public override feeRate = 30;        // 手续费千三

    // 存到lend池中的 ctoken0 amount
    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    // 存到lend池中的 ctoken1 amount
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    address public cToken0;              // 对应 token0 在 lend 池中的 cToken
    address public cToken1;              // 对应 token1 在 lend 池中的 cToken
    uint112 public vReserve0;           // 虚拟的 token0 数量, 因为实际上 token0 已经存入 ctoken 合约中
    uint112 public vReserve1;           // 虚拟的 token1 数量, 因为实际上 token1 已经存入 ctoken 合约中
    uint256 public lpFeeRate;
    address public creator;             // 创建者, 第一个体提供流动性的

    uint public override price0CumulativeLast;
    uint public override price1CumulativeLast;
    uint public override kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    struct LPReward {
        uint amount; // LP amount
        uint rewardDebt;
    }
    uint public accPerShare;
    uint public rewards;
    uint public totalFee;
    uint public currentBlock;       // blockFee对应的块数
    uint public blockFee;           // 当前块的手续费, 下一个块的第一笔交易触发计算上个块的reward, 然后重新累计

    // 只有 owner 可以 burn, 其他不可以 burn
    mapping(address => LPReward) public ownerOf;

    uint private _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1, 'DeBankSwap: LOCKED');
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

    function _updateBlockFee(uint fee) private {
        if (currentBlock == block.number) {
            blockFee += fee;
            return;
        }

        if (blockFee > 0) {
            // 计算之前的奖励
            IMdexRouter router = IMdexRouter(IMdexFactory(factory).router());
            uint denominator = router.allPairFeeLastBlock();
            uint reward = router.reward(currentBlock);
            if (currentBlock != block.number - 1) {
                // 中间有若干个块没有交易的情况 将 本交易对之前的块手续费算在 上一个的所有交易对手续费之和 里
                denominator += blockFee;
            }
            rewards += reward.mul(blockFee).div(denominator);
        }
        // 重新累计这个块的手续费
        currentBlock = block.number;
        blockFee = fee;
    }

    // 更新本交易对的收益 每个块只更新一次 只更新上一个块的交易额
    function _updatePairFee() private {
        if (currentBlock == block.number) {
            return;
        }

        // uint allPairFee = IMdexRouter(IMdexFactory(factory).router()).allPairFees();
        // if (totalFee > totalFeeLast) {
        //     uint rewards = IMdexRouter(IMdexFactory(factory).router()).getBlockRewards(lastBlock);
        //     uint incFee = totalFee - totalFeeLast;
        //     uint allIncFee = allPairFee - allPairFeeLast;
        //     uint blocks = block.number - lastBlock;
        //     accPerShare += incFee.mul(rewards).div(allIncFee).div(blocks).div(totalSupply);
        // }

        // totalFeeLast = totalFee;
        // allPairFeeLast = allPairFee;
        // lastBlock = block.number;
    }

    function _mint(address to, uint value) internal {
        _updatePairFee();

        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        // 记录 owner 只有 owner 可以提取流动性
        LPReward storage lpReward = ownerOf[to];
        if (lpReward.amount == 0) {
            lpReward.amount = value;
            lpReward.rewardDebt = value.mul(accPerShare);
        } else {
            lpReward.amount += value;
            lpReward.rewardDebt = lpReward.amount.mul(accPerShare);
        }
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        // 记录 owner 只有 owner 可以提取流动性
        LPReward storage lpReward = ownerOf[from];
        require(lpReward.amount >= value, "No enough");
        lpReward.amount = lpReward.amount - value;

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
        require(msg.sender == factory, 'DeBankSwap: FORBIDDEN');
        // sufficient check
        token0 = _token0;
        token1 = _token1;
        lpFeeRate = IMdexFactory(factory).lpFeeRate();
    }

    // 更新 lpFeeRate 只有 factory 可以更新 lpFeeRate
    function updateLPFeeRate(uint256 _feeRate) external {
        require(msg.sender == factory, 'DeBankSwap: FORBIDDEN');
        lpFeeRate = _feeRate;
    }

    function updateFeeRate(uint256 _feeRate) override external {
        require(msg.sender == factory || msg.sender == creator, 'DeBankSwap: FORBIDDEN');
        feeRate = _feeRate;
    }

    // called once by the factory at time of deployment
    function initializeCTokenAddress(address _token0, address _token1) override external {
        require(msg.sender == factory, 'DeBankSwap: FORBIDDEN');
        // sufficient check
        cToken0 = _token0;
        cToken1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(- 1) && balance1 <= uint112(- 1), 'DeBankSwap: OVERFLOW');
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
        require(balance0 <= uint112(- 1) && balance1 <= uint112(- 1), 'DeBankSwap: OVERFLOW');
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
                    uint denominator = rootK.mul(lpFeeRate).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // ETH/HT/BNB 不能直接 mint
    // 2021/5/25: 存入的是 ctoken 而不是 token; 如果要存入 token, 在外围合约中实现(先转换为ctoken, 再调用此方法)
    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) override external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        uint balance0 = IERC20(cToken0).balanceOf(address(this));
        uint balance1 = IERC20(cToken1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        console.log(cToken0, cToken1);
        console.log(balance0, balance1, _reserve0, _reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;
        // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = SafeMath.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY);
            creator = to;
            // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = SafeMath.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }

        require(liquidity > 0, 'DeBankSwap: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // 操作的是 ctoken 2021/05/25
    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) override external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        address _token0 = cToken0;
        // gas savings
        address _token1 = cToken1;
        // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];
        // 只有 ctoken0 ctoken1 和 owner 可以 burn
        if (to != _token0 && to != _token1) {
            require(ownerOf[to].amount >= liquidity, "only owner can burn");
        }

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;
        // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply;
        // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply;
        // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'DeBankSwap: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // 只允许 router 调用, fee 已经在外部扣除
    function swapNoFee(uint amount0Out, uint amount1Out, address to, uint fee) override external lock {
        require(msg.sender == IMdexFactory(factory).router(), "DeBankSwap: router only");
        if (fee > 0) {
            _updateBlockFee(fee);
        }

        require(amount0Out > 0 || amount1Out > 0, 'DeBankSwap: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'DeBankSwap: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        {// scope for _token{0,1}, avoids stack too deep errors
        address _token0 = cToken0;
        address _token1 = cToken1;
            require(to != _token0 && to != _token1, 'DeBankSwap: INVALID_TO');
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            // optimistically transfer tokens
            // if (data.length > 0) IHswapV2Callee(to).hswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

        require(amount0In > 0 || amount1In > 0, 'DeBankSwap: INSUFFICIENT_INPUT_AMOUNT');
        // 因为手续费已经在外部收走, 这里只需要 x'*y'>=x*y
        require(balance0.mul(balance1) >= uint(_reserve0).mul(_reserve1), 'MdexSwap: K');

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) override external lock {
        require(amount0Out > 0 || amount1Out > 0, 'MdexSwap: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'MdexSwap: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        {// scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'MdexSwap: INVALID_TO');
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
        require(amount0In > 0 || amount1In > 0, 'MdexSwap: INSUFFICIENT_INPUT_AMOUNT');
        {// scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000 ** 2), 'MdexSwap: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function getFee(uint256 amt) public view override returns (uint256) {
        return amt.mul(feeRate).div(10000);
    }

    // x * y = x' * y'   令 x' = x + a; y' = y - b
    // x * y = (x+a) * y'
    // y' = (x*y) / (x+a)
    // b = y - y' = y - (x*y) / (x+a) = a*y/(x+a)
    // b = a*y/(x+a)
    function _swapWithOutFee(uint256 a, uint256 r0, uint256 r1) private pure returns (uint256) {
        return (a * r1) / (a + r0);
    }

    // 将手续费换算为usdt
    // path 手续费兑换路径
    // function _swapFee(uint256 amt0In, uint256 amt1In, address[] memory path) private {
    //     address _token0 = cToken0;
    //     address _token1 = cToken1;
    //     address feeTo = IMdexFactory(factory).feeTo();
    //     address anchorToken = IMdexFactory(factory).anchorToken();
    //     if (_token0 == anchorToken || _token1 == anchorToken) {
    //         // 如果pair本身就是 usdt 交易对, 手续费直接收或者直接换算即可
    //         if (amt0In > 0) {
    //             if (_token0 == anchorToken) {
    //                 IERC20(_token0).transfer(feeTo, getFee(amt0In));
    //             } else {
    //                 // 计算换算成多少 anchorToken
    //                 // uint256 fee = getFee(amt0In);
    //                 // x*y = x' * y'
    //                 uint256 fee = _swapWithOutFee(getFee(amt0In), reserve0, reserve1);
    //                 IERC20(_token1).transfer(feeTo, fee);
    //             }
    //         }
    //         if (amt1In > 0) {
    //             if (_token1 == anchorToken) {
    //                 IERC20(_token1).transfer(feeTo, getFee(amt1In));
    //             } else {
    //                 // 计算换算成多少 anchorToken
    //                 // uint256 fee = getFee(amt1In);
    //                 // x*y = x' * y'
    //                 uint256 fee = _swapWithOutFee(getFee(amt1In), reserve1, reserve0);
    //                 IERC20(_token0).transfer(feeTo, fee);
    //             }
    //         }
    //     } else {
    //         // 需要调用其他 pair 的不收手续费版本的 swap, 权限很难控制
    //     }
    // }

    // force balances to match reserves
    function skim(address to) override external lock {
        address _token0 = cToken0;
        // gas savings
        address _token1 = cToken1;
        // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() override external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    function price(address token, uint256 baseDecimal) override public view returns (uint256) {
        if ((cToken0 != token && cToken1 != token) || 0 == reserve0 || 0 == reserve1) {
            return 0;
        }
        if (cToken0 == token) {
            return uint256(reserve1).mul(baseDecimal).div(uint256(reserve0));
        } else {
            return uint256(reserve0).mul(baseDecimal).div(uint256(reserve1));
        }
    }
}

contract MdexFactory is IMdexFactory {
    using SafeMath for uint256;
    using SafeMath for uint;
    address public override feeTo;       
    address public override feeToSetter;
    uint256 public override lpFeeRate = 0;    // 分配给LP的比例: 0: 0; n: (n/(n+1))
    address public anchorUnderlying;
    address public override anchorToken;           // 手续费锚定币种
    address public override router;
    bytes32 public initCodeHash;

    // lend controller address. should be unitroller address, which is proxy of comptroller
    LErc20DelegatorInterface public override lErc20DelegatorFactory;
    address public owner;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    // event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    // 创建时需要设置 LERC20 factory 地址
    constructor(address _feeToSetter, address _ctokenFacotry, address _anchorToken) {
        owner = msg.sender;
        feeToSetter = _feeToSetter;
        lErc20DelegatorFactory = LErc20DelegatorInterface(_ctokenFacotry);
        initCodeHash = keccak256(abi.encodePacked(type(MdexPair).creationCode));

        anchorUnderlying = _anchorToken;
        anchorToken = _anchorToken; // lErc20DelegatorFactory.getCTokenAddressPure(_anchorToken);
        require(anchorToken != address(0), "cToken of anchorToken is 0");
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function setAnchorToken(address _anchorToken) external override {
        require(msg.sender == owner, "No auth");
        anchorUnderlying = _anchorToken;
        anchorToken = _anchorToken; // lErc20DelegatorFactory.getCTokenAddressPure(_anchorToken);
        require(anchorToken != address(0), "cToken of anchorToken is 0");
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
        require(_feeToSetter != address(0), "DeBankSwapFactory: FeeToSetter is zero address");
        feeToSetter = _feeToSetter;
    }

    function setFeeToRate(uint256 _rate) external override {
        require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        require(_rate > 0, "DeBankSwapFactory: FEE_TO_RATE_OVERFLOW");
        lpFeeRate = _rate.sub(1);
    }
    
    function setPairFeeRate(address pair, uint feeRate) external override {
        require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        // 最高手续费不得高于2%
        require(feeRate <= 200, "SwapFactory: feeRate too high");
        IMdexPair(pair).updateFeeRate(feeRate);
    }

    function setRouter(address _router) external {
        require(msg.sender == owner, "SwapFactory: FORBIDDEN");
        router = _router;
    }

    // 原来的owner设置新的owner
    function changeOwner(address _owner) external {
        require(msg.sender == owner, "SwapFactory: FORBIDDEN");
        owner = _owner;
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

    // fetches and sorts the reserves for a pair
    function getReservesFeeRate(address tokenA, address tokenB) public view override 
            returns (uint reserveA, uint reserveB, uint feeRate, bool outAnchorToken) {
        (address token0,) = sortTokens(tokenA, tokenB);
        address pair = pairFor(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IMdexPair(pair).getReserves();
        feeRate = IMdexPair(pair).feeRate();
        // 输出货币是否是 锚定货币
        outAnchorToken = tokenA == token0 ? tokenB == anchorToken : tokenA == anchorToken;
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        console.log("tokenA: %s tokenB: %s anchorToken: %s", tokenA, tokenB, anchorToken);
        console.log("reserveA: %d reserveB: %d feeRate: %d", reserveA, reserveB, feeRate);
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

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOutFeeRate(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) public pure override returns (uint amountOut) {
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
    function getAmountOutFeeRateAnchorToken(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) public pure override returns (uint amountOut) {
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
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure override returns (uint amountIn) {
        require(amountOut > 0, 'SwapFactory: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwapFactory: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // 正常计算逻辑:
    // x*y = x'*y'
    // a = x' - x  输入
    // b = y - y'
    // b = 997*a*y/(997*a+1000*x)
    // a = 1000xb/997(y-b)
    function getAmountInFeeRate(uint amountOut, uint reserveIn, uint reserveOut, uint feeRate) public pure override returns (uint amountIn) {
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
    function amountToCTokenAmt(address ctoken, uint amountIn) external view override returns (uint cAmountIn) {
        uint exchangeRate = CTokenInterface(ctoken).exchangeRateStored();
        return amountIn.mul(1e18).div(exchangeRate);
    }

    // 调用前确保已经是最新的 exchangeRate
    // ctoken amount 转换为 token amt
    // tokenAmt = ctokenAmt * exchangeRate
    function ctokenAmtToAmount(address ctoken, uint cAmountOut) external view override returns (uint amountOut) {
        uint exchangeRate = CTokenInterface(ctoken).exchangeRateStored();
        return cAmountOut.mul(exchangeRate).div(1e18);
    }

    // path 中的 address 应该都是 ctoken
    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, address[] memory path) public view override returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwapFactory: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut, uint feeRate, bool outAnchorToken) = getReservesFeeRate(path[i], path[i + 1]);
            if (outAnchorToken) {
                amounts[i + 1] = getAmountOutFeeRateAnchorToken(amounts[i], reserveIn, reserveOut, feeRate);
            } else {
                amounts[i + 1] = getAmountOutFeeRate(amounts[i], reserveIn, reserveOut, feeRate);
            }
        }
    }

    // path 中的 address 应该都是 ctoken
    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint amountOut, address[] memory path) public view override returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwapFactory: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut, uint feeRate, ) = getReservesFeeRate(path[i - 1], path[i]);
            amounts[i - 1] = getAmountInFeeRate(amounts[i], reserveIn, reserveOut, feeRate);
        }
    }

    // --------------------------------------------------------
    // 以上都是按照输入 ctoken 输出也是 ctoken 的情况
    // 按照 token 来计算的情况, 先将 token 转换为 ctoken 
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
