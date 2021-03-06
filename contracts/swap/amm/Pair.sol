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
import "../interface/ICToken.sol";

import "./PairStorage.sol";

// import "hardhat/console.sol";

// interface ICToken {

// }

interface IUnitroller {
    function compAccrued(address addr) external view returns (uint);
    function claimComp(address holder, ICToken[] calldata cTokens) external returns(uint);
}

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
    
    // ?????????????????????????????????
    // ??????????????????????????????
    function _updateBlockFee(uint fee) private {
        totalFee += fee;
        currentFee += fee;
        // console.log("_updateBlockFee: fee=%d totalFee=%d currentFee=%d", fee, totalFee, currentFee);
    }

    // ??? router ?????? mint ?????????ebe: router ?????? mint ???????????? ebe ?????????????????? pair ?????????????????? pair
    function _mintPairEBE() private returns (uint amt) {
        if (currentFee == 0) {
            return 0;
        }
        IDeBankRouter router = IDeBankRouter(IDeBankFactory(factory).router());
        amt = router.mintEBEToken(token0, token1, currentFee);

        // console.log("_mintPairEBE: fee=%d reward=%d", currentFee, amt);
        currentFee = 0;
    }

    // ????????????????????? ctoken ?????????????????????
    function _claimPairComp() private returns (uint) {
        address lhbToken = IDeBankRouter(IDeBankFactory(factory).router()).rewardToken();
        if (lhbToken == address(0)) {
            return 0;
        }
        uint bal0 = IERC20(lhbToken).balanceOf(address(this));

        address unitroller = IDeBankFactory(factory).compAddr();    // ??? factory/router ?????????
        ICToken[] memory cTokens = new ICToken[](2); // memory cTokens
        cTokens[0] = ICToken(cToken0);
        cTokens[1] = ICToken(cToken1);

        return 0;
        /*
        // todo ???????????????
        console.log("_claimPairComp: %d", bal0);
        IUnitroller(unitroller).claimComp(address(this), cTokens);
        console.log("_claimPairComp ok", bal0);
        uint bal1 = IERC20(lhbToken).balanceOf(address(this));
        return bal1.sub(bal0);
        */
    }

    // ????????????
    function _updateEBEPerShare() private {
        if (lastBlock == block.number) {
            return;
        }
        // console.log("start update pair share: %d", currentFee);
        lastBlock = block.number;
        // ??????????????? ebe ??????
        uint feeAmt = _mintPairEBE();
        uint compAmt = _claimPairComp();
        uint total = feeAmt + compAmt;
        // console.log("_updateEBEPerShare: feeAmt=%d compAmt=%d", feeAmt, compAmt);
        if (total > 0 && totalSupply > 0) {
            // ?????? per share
            mintAccPerShare += total.mul(1e18).div(totalSupply);
        }
    }

    // ???????????????????????????. true: ???????????????; false: ????????????
    // HecoPool ????????????????????????
    // LP ?????????????????????
    function _isMintDisable(address addr) internal view returns (bool) {
        // ?????? factory ?????????
        return IDeBankFactory(factory).mintFreeAddress(addr);
    }

    // ?????? ?????? ??? ebe ??????, ??????????????????, ??? ebe ????????????
    function withdrawEBEReward(address to) public returns (uint) {
        if (_isMintDisable(to)) {
            return 0;
        }

        // ?????? pair ???????????????
        _updateEBEPerShare();
        // ???????????????
        return _updateUserEBEReward(to, 0, true, true);
    }

    function _updateUserEBEReward(address to, uint value, bool incVal, bool transfer) internal returns (uint transfered) {
        LPReward storage lpReward = mintRewardOf[to];
        uint amt = lpReward.amount;
        uint _perShare = mintAccPerShare;
        
        // if (incVal) {
        //     console.log("inc user %s ebe mint: %d", to, value);
        // } else {
        //     console.log("sub user %s ebe mint:", to, value);
        // }
        // console.log("user now mint reward: amount=%d pendingReward=%d debt=%d", lpReward.amount, lpReward.pendingReward, lpReward.rewardDebt);

        if (amt == 0) {
            // ?????????????????? 0
            require(incVal == true, "no amt to dec");
            lpReward.amount = value;
            lpReward.rewardDebt = value.mul(_perShare);
            return 0;
        }

        if (value > 0) {
            // ?????? pending ?????? ??? ????????????
            lpReward.pendingReward += amt.mul(_perShare).sub(lpReward.rewardDebt);
            if (incVal) {
                amt = amt.add(value);
            } else {
                amt = amt.sub(value);
            }
            lpReward.amount = amt;
            lpReward.rewardDebt = amt.mul(_perShare); // amt.mul(perShare);
        }

        if (transfer) {
            address rewardToken = IDeBankRouter(IDeBankFactory(factory).router()).rewardToken();
            require(rewardToken != address(0), "rewardToken not set");

            transfered = lpReward.pendingReward.add(amt.mul(_perShare).sub(lpReward.rewardDebt)).div(1e18);
            lpReward.rewardDebt = amt.mul(_perShare);
            // ?????? to
            IERC20(rewardToken).transfer(to, transfered);
            lpReward.pendingReward = 0;
        }
    }

    function _mint(address to, uint value) internal {
        if (to != address(0)) {
            _updateEBEPerShare();

            // ??????????????? ebe reward
            _updateUserEBEReward(to, value, true, false);

            // LPReward storage lpReward = mintRewardOf[to];
            // uint amt = lpReward.amount;
            // uint _perShare = mintAccPerShare;
            // if (amt == 0) {
            //     lpReward.amount = value;
            //     lpReward.rewardDebt = value.mul(_perShare);
            // } else {
            //     lpReward.pendingReward += amt.mul(_perShare);
            //     amt += value;
            //     lpReward.amount += amt;
            //     lpReward.rewardDebt = amt.mul(_perShare); // amt.mul(perShare);
            // }
        }
        // console.log("_mint %s LPReward.amount:", to, lpReward.amount);

        // ?????? owner ?????? owner ?????????????????????
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        // mintOf[to] = mintOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        // console.log("balanceOf[from]=%d value=%d totalSupply=%d", balanceOf[from], value, totalSupply);
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
        // ???????????????
        // address addr = _getLPDepositAddr();
        if (_isMintDisable(from) == false && _isMintDisable(to) == false) {
            _updateEBEPerShare();
            // console.log("_updateCtokenMintPerShare done");
            _updateUserEBEReward(from, value, false, true);
            // console.log("_updateUserMintReward from done");
            _updateUserEBEReward(to, value, true, false);
            // console.log("_updateUserMintReward to done");
            // LPReward memory fromReward = mintRewardOf[from];
            // LPReward memory toReward = mintRewardOf[to];
            // console.log("after _transfer, LPReward:");
            // console.log("  from: amount=%d pending=%d debt=%d", fromReward.amount, fromReward.pendingReward, fromReward.rewardDebt);
            // console.log("  to:   amount=%d pending=%d debt=%d", toReward.amount, toReward.pendingReward, toReward.rewardDebt);
        }
        // ??????????????????????????? ???????????? reward debt
        emit Transfer(from, to, value);
    }

    // function ownerAmountOf(address owner) external view returns (uint) {
    //     LPReward memory reward = ownerOf[owner];
    //     return reward.amount;
    // }

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
      // solhint-disable-next-line
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
        // solhint-disable-next-line avoid-low-level-calls
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
        // solhint-disable-next-line
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
    // ????????? feeTo ???, ??????????????????
    // mdex ????????? lpFeeRate ???????????? 0, ??????, ????????????????????????mdex????????????
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IDeBankFactory(factory).feeTo();
        // console.log("feeTo:", feeTo);
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


    function _lhbBalance() internal view returns (uint) {
        address lhb = IDeBankRouter(IDeBankFactory(factory).router()).rewardToken();        // ??? factory/router ?????????

        return IERC20(lhb).balanceOf(address(this));
    }

    // pair ????????? ctoken ????????? ctoken ??????????????????
    function _lhbTotalBlance() internal view returns (uint) {
        address lhb = IDeBankRouter(IDeBankFactory(factory).router()).rewardToken();        // ??? factory/router ?????????
        if (lhb == address(0)) {
            return 0;
        }
        // console.log("lhb:", lhb);
        address unitroller = IDeBankFactory(factory).compAddr();    // ??? factory/router ?????????
        if (unitroller == address(0)) {
            return IERC20(lhb).balanceOf(address(this));
        }

        // ?????????????????? compAccrued ?????????????????????
        return IERC20(lhb).balanceOf(address(this)) + IUnitroller(unitroller).compAccrued(address(this));
    }


    // ETH/HT/BNB ???????????? mint
    // 2021/5/25: ???????????? ctoken ????????? token; ??????????????? token, ????????????????????????(????????????ctoken, ??????????????????)
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
        // console.log("mint: liquidity: %d", liquidity);
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);

        // ctokenMintDebt[to] = liquidity.mul(mintAccPerShare); // .div(totalSupply);

        // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // ??????????????????????????? ??? ctoken ??????????????????????????????
    // function _transferCtokenMint(address from, address to, uint liquidity) internal {
    //     address lhb = IDeBankRouter(IDeBankFactory(factory).router()).rewardToken();        // ??? factory/router ?????????

    //     // unitroller.claimComp(address(this), cTokens);
    //     uint amt = liquidity.mul(mintAccPerShare).sub(ctokenMintDebt[to]);
    //     if (amt > _lhbBalance()) {
    //         // ??????????????????, ????????????????????????????????????
    //         _claimPairComp();
    //     }

    //     IERC20(lhb).transfer(to, amt);
    //     // update curr
        
    //     // ?????? pair ???????????????
    //     ctokenMintRewards = ctokenMintRewards.sub(amt); // _lhbTotalBlance();

    //     // ????????????????????????????????????LP, ????????????????????????????????????
    //     if (from == _getLPDepositAddr()) {
    //         mintOf[to] = mintOf[to].sub(liquidity);
    //     } else {
    //         mintOf[from] = 
    //     }
    // }

    // function lpDepositBurn(address owner) external lock returns (uint amount0, uint amount1) {
    //     // LP ?????????????????????????????????
    //     address lpDepositAddr;
    //     require(msg.sender == lpDepositAddr, "LP burn");
    // }

    // function _mintUserEBE(address to, uint liquidity) internal {
    //     IDeBankRouter router = IDeBankRouter(IDeBankFactory(factory).router());
    //     address ebe = router.rewardToken();
        
    //     if (ebe != address(0)) {
    //         if (currentFee > 0) {
    //             router.mintEBEToken(token0, token1, currentFee);
    //             currentFee = 0;
    //         }

    //         uint ebeAmt = IERC20(ebe).balanceOf(address(this));
    //         // 
    //         if (ebeAmt > 0) {
    //             // todo ?????? rewardDebt ???????????????
    //             uint userAmt = liquidity.mul(ebeAmt).div(totalSupply);
    //             IERC20(ebe).transfer(to, userAmt);
    //         }
    //     }
    // }

    // ???????????? ctoken 2021/05/25
    // burn ??????????????????????????????, ?????????????????????????????? mint ??? transfer ???
    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        // LP ?????????????????????????????????
        // address lpDepositAddr;
        // require(msg.sender != lpDepositAddr, "burn");
        // console.log("burn start");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // gas savings
        address _token0 = cToken0;
        // gas savings
        address _token1 = cToken1;
        // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];
        // ?????? ctoken0 ctoken1 ??? owner ?????? burn
        // if (to != _token0 && to != _token1 && to != IDeBankFactory(factory).router()) {
        //     require(ownerOf[to].amount >= liquidity, "only owner can burn");
        // }

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;
        // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply;
        // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply;
        // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'DeBankSwap: INSUFFICIENT_LIQUIDITY_BURNED');

        // console.log("after _mintFee:", amount0, amount1);

        // ??????????????????
        _updateEBEPerShare();
        // (to, liquidity);
        // ctoken ??????, ??????, ??? totalSupply ??????????????????
        // console.log("burn: before _updateUserEBEReward");
        // _updateUserEBEReward(to, liquidity, false, true);
        // console.log("burn: after _updateUserEBEReward");

        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        // ctoken transfer ????????? ?????????????????? comptroller ???????????????
        // ????????? LP ???????????????????????????????????????
        // 2021-07-14 burn ?????????????????????????????? pair, transfer ?????????????????????????????????, _burn ???????????? pair ??????????????????
        // _updateUserMintReward(to, liquidity, false);
        // _transferCtokenMint(msg.sender, to, liquidity);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // ????????? router ??????, fee ?????????????????????
    function swapNoFee(uint amount0Out, uint amount1Out, address to, uint fee) external lock {
        require(msg.sender == IDeBankFactory(factory).router(), "DeBankSwap: router only");
        // console.log("swapNoFee: amount0Out=%d amount1Out=%d fee=%d", amount0Out, amount1Out, fee);
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
        // ????????????????????????????????????, ??????????????? x'*y'>=x*y
        require(balance0.mul(balance1) >= uint(_reserve0).mul(_reserve1), 'DeBankSwap: K2');

        _update(balance0, balance1, _reserve0, _reserve1);

        // ??????????????????
        // _updateCtokenMintPerShare();

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
            // console.log("amount0In: %d amount1In: %d", amount0In, amount1In);
            // console.log("balanceAdjusted: %d  %d", balance0Adjusted, balance1Adjusted);
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(10000 ** 2), 'DeBankSwap: K1');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        
        // ??????????????????
        // _updateCtokenMintPerShare(_lhbTotalBlance());

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function getFee(uint256 amt) public view returns (uint256) {
        return amt.mul(feeRate).div(10000);
    }

    function getFee(uint256 amt, uint fr) public view returns (uint256) {
        require(fr < 1000, "invalid feeRate");
        return amt.mul(fr).div(10000);
    }

    // x * y = x' * y'   ??? x' = x + a; y' = y - b
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
    // ?????? lpFeeRate ?????? factory ???????????? lpFeeRate
    function updateLPFeeRate(uint256 _feeRate) external {
        require(msg.sender == factory, 'DeBankSwap: FORBIDDEN');
        lpFeeRate = _feeRate;
    }

    // ???????????????
    function updateFeeRate(uint256 _feeRate) external {
        require(msg.sender == factory, 'DeBankSwap: FORBIDDEN');
        require(_feeRate <= 200, "feeRate too high");  // ??????????????? 2%
        feeRate = _feeRate;
    }
}
