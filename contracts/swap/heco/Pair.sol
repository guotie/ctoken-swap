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

import "../library/SafeMath.sol";

import "../interface/IERC20.sol";
import "../interface/IDeBankFactory.sol";
import "../interface/IDeBankPair.sol";
import "../interface/IDeBankRouter.sol";

import "./PairStorage.sol";

import "hardhat/console.sol";

interface IHswapV2Callee {
    function hswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

library UQ112x112 {
    uint224 constant private _Q112 = 2 ** 112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * _Q112;
        // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}

// stable & uniwap pair
contract DeBankPair is IDeBankPair, PairStorage {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    constructor() public {
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
    
    function _updateRewardShare() internal {
        _updateBlockFee(0);

        if (totalSupply > 0) {
          accPerShare = rewards / totalSupply;
        }
    }

    function _mint(address to, uint value) internal {
        _updateRewardShare();

        LPReward storage lpReward = ownerOf[to];
        if (lpReward.amount == 0) {
            lpReward.amount = value;
            lpReward.rewardDebt = value.mul(accPerShare);
        } else {
            lpReward.pendingReward += lpReward.amount * accPerShare;
            lpReward.amount += value;
            lpReward.rewardDebt = lpReward.amount.mul(accPerShare);
        }

        // 记录 owner 只有 owner 可以提取流动性
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        _updateRewardShare();

        // 记录 owner 只有 owner 可以提取流动性
        LPReward storage lpReward = ownerOf[from];
        // require(lpReward.amount >= value, "Not enough");
        uint reward = accPerShare * lpReward.amount + lpReward.pendingReward - lpReward.rewardDebt;
        if (reward > 0) {
          // todo transfer
            address rewardToken = IDeBankRouter(IDeBankFactory(factory).router()).rewardToken();
            if (rewardToken != address(0)) {
                _safeTransfer(rewardToken, from, reward);
            }
        }
        lpReward.amount = lpReward.amount - value;
        lpReward.pendingReward = 0;
        lpReward.rewardDebt = lpReward.amount * accPerShare;

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

    function ownerAmountOf(address owner) external view returns (uint) {
        LPReward memory reward = ownerOf[owner];
        return reward.amount;
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != uint(- 1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function permit(address owner, address spender, uint value, uint deadline,
                    uint8 v, bytes32 r, bytes32 s) external {
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

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(_SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Swap: TRANSFER_FAILED');
    }

    ////////////////////////////
    
    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1, address _ctoken0, address _ctoken1) external {
        require(msg.sender == factory, 'DeBankSwap: FORBIDDEN');
        // sufficient check
        token0 = _token0;
        token1 = _token1;
        cToken0 = _ctoken0;
        cToken1 = _ctoken1;

        lpFeeRate = IDeBankFactory(factory).lpFeeRate();
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
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

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    // 设置了 feeTo 时, 才收取手续费
    // mdex 这里的 lpFeeRate 设置的是 0, 因此, 所有的手续费都被mdex平台收走
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IDeBankFactory(factory).feeTo();
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

    // 更新上一块的手续费分成
    // 更新本块的手续费总和
    function _updateBlockFee(uint fee) private {
        if (currentBlock == block.number) {
            blockFee += fee;
            return;
        }

        // 计算之前块的手续费分成
        if (blockFee > 0) {
            if (currentBlock == block.number - 1) {
                // 计算上一个块的奖励
                IDeBankRouter router = IDeBankRouter(IDeBankFactory(factory).router());
                uint denominator = router.allPairFeeLastBlock();    // 上一个块所有交易对的手续费
                uint reward = router.reward(currentBlock);
                rewards += reward.mul(blockFee).div(denominator);
            } else {
                // 中间有若干个块没有交易的情况 将 本交易对之前的块手续费算在 上一个的所有交易对手续费之和 里
                // 距离上一次交易的块越远, 收益越低
                uint multor = 1 + (block.number - currentBlock) / 100;
                blockFee = fee + blockFee / multor;
                currentBlock = block.number;
                return;
            }
        }
        // 重新累计这个块的手续费
        currentBlock = block.number;
        blockFee = fee;
    }

    // function _updateLPReward(address to, uint amount) private lock {
    //     _updateBlockFee(0);

    //     LPReward storage user = ownerOf[to];

    //     if (user.amount > 0) {
    //         uint256 pendingAmount = user.amount.mul(totalSupply).sub(user.rewardDebt);
    //     } else {

    //     }

    //     user.amount += amount;
    //     user.rewardDebt = user.amount.mul(pool.accMdxPerShare);
    // }


    // pair 的两个 ctoken 得到的 ctoken 存币挖矿收益
    function _lhbBlance() internal view returns (uint) {
        address lhb;        // todo 从factory中获取
        address unitroller; // todo 从factory中获取

        // 有部分币存在compAccrued中，没有转出来
        return IERC20(lhb).balanceOf(address(this)) + unitroller.compAccrued(address(this));
    }

    // 更新 mintAccPerShare
    function _updateCtokenMintPerShare(uint curr) internal {
        // uint curr = _lhbBlance();
        if (curr > ctokenMintRewards) {
            uint per = curr.sub(ctokenMintRewards);
            mintAccPerShare = mintAccPerShare.add(per.div(totalSupply));
        }
        ctokenMintRewards = curr;
    }

    // ETH/HT/BNB 不能直接 mint
    // 2021/5/25: 存入的是 ctoken 而不是 token; 如果要存入 token, 在外围合约中实现(先转换为ctoken, 再调用此方法)
    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        uint balance0 = IERC20(cToken0).balanceOf(address(this));
        uint balance1 = IERC20(cToken1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        // console.log(cToken0, cToken1);
        // console.log(balance0, balance1, _reserve0, _reserve1);

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

        require(liquidity > 0, 'DeBankSwap: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);

        // ctoken 挖矿, 负债
        _updateCtokenMintPerShare(_lhbBlance());
        ctokenMintDebt[to] = liquidity.mul(mintAccPerShare).div(totalSupply);

        // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // 用户移除流动性时， 将 ctoken 存币挖矿收益转给用户
    function _transferCtokenMint(address to, uint liquidity, uint ts) internal {
        address lhb;        // todo 从factory中获取
        address unitroller; // todo 从factory中获取
        CToken[] memory cTokens = new CToken[](2); // memory cTokens

        cTokens[0] = cToken0;
        cTokens[1] = cToken1;
        unitroller.claimComp(address(this), cTokens);
        _updateCtokenMintPerShare(_lhbBlance());
        uint amt = liquidity.mul(mintAccPerShare).div(ts).sub(ctokenMintDebt[to]);
        lhb.transfer(to, amt);
        // update curr
        
        ctokenMintRewards = _lhbBlance();
    }

    // 操作的是 ctoken 2021/05/25
    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
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
        if (to != _token0 && to != _token1 && to != IDeBankFactory(factory).router()) {
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

        uint ts = totalSupply; // _burn 之前记录 totalSupply
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        // todo transfer之后， 挖矿的收益在 comptroller 中已经更新
        _transferCtokenMint(to, liquidity, ts);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // 只允许 router 调用, fee 已经在外部扣除
    function swapNoFee(uint amount0Out, uint amount1Out, address to, uint fee) external lock {
        require(msg.sender == IDeBankFactory(factory).router(), "DeBankSwap: router only");
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
        require(balance0.mul(balance1) >= uint(_reserve0).mul(_reserve1), 'DeBankSwap: K2');

        _update(balance0, balance1, _reserve0, _reserve1);

        // 更新挖矿收益
        _updateCtokenMintPerShare(_lhbBlance());

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
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
            if (data.length > 0) IHswapV2Callee(to).hswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'DeBankSwap: INSUFFICIENT_INPUT_AMOUNT');
        {// scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = balance0.mul(10000).sub(amount0In.mul(feeRate));
            uint balance1Adjusted = balance1.mul(10000).sub(amount1In.mul(feeRate));
            console.log("amount0In: %d amount1In: %d", amount0In, amount1In);
            console.log("balanceAdjusted: %d  %d", balance0Adjusted, balance1Adjusted);
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(10000 ** 2), 'DeBankSwap: K1');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        
        // 更新挖矿收益
        _updateCtokenMintPerShare(_lhbBlance());
        
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function getFee(uint256 amt) public view returns (uint256) {
        return amt.mul(feeRate).div(10000);
    }

    // x * y = x' * y'   令 x' = x + a; y' = y - b
    // x * y = (x+a) * y'
    // y' = (x*y) / (x+a)
    // b = y - y' = y - (x*y) / (x+a) = a*y/(x+a)
    // b = a*y/(x+a)
    // function _swapWithOutFee(uint256 a, uint256 r0, uint256 r1) private pure returns (uint256) {
    //     return (a * r1) / (a + r0);
    // }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = cToken0;
        // gas savings
        address _token1 = cToken1;
        // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    function price(address token, uint256 baseDecimal) public view returns (uint256) {
        if ((cToken0 != token && cToken1 != token) || 0 == reserve0 || 0 == reserve1) {
            return 0;
        }
        if (cToken0 == token) {
            return uint256(reserve1).mul(baseDecimal).div(uint256(reserve0));
        } else {
            return uint256(reserve0).mul(baseDecimal).div(uint256(reserve1));
        }
    }

    ////////////////////////////////////////////////////////// Admin //////////////////////////////////////////////////////////
    // 更新 lpFeeRate 只有 factory 可以更新 lpFeeRate
    function updateLPFeeRate(uint256 _feeRate) external {
        require(msg.sender == factory, 'DeBankSwap: FORBIDDEN');
        lpFeeRate = _feeRate;
    }

    // 手续费比例
    function updateFeeRate(uint256 _feeRate) external {
        require(msg.sender == factory, 'DeBankSwap: FORBIDDEN');
        require(_feeRate <= 200, "feeRate too high");  // 最高不超过 2%
        feeRate = _feeRate;
    }
}
