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
import "../interface/IWHT.sol";
import "../interface/LErc20DelegatorInterface.sol";
import "../interface/ICToken.sol";

import "../../ebe/IEBEToken.sol";

// import "../../compound/LHT.sol";
import "hardhat/console.sol";

interface ILHT {
    function mint() external payable returns (uint, uint);
}

interface ISwapMining {
    function swap(address account, address input, address output, uint256 fee) external returns (bool);
}

// interface IRewardToken {
//     function reward(uint256 blockNumber) external view returns (uint256);
// }

contract DeBankRouter is IDeBankRouter, Ownable {
    using SafeMath for uint256;

    address public factory;
    address public WHT;
    address public swapMining;
    address public cWHT;
    address[] public quoteTokens;
    LErc20DelegatorInterface public ctokenFactory;

    // 所有交易对产生的手续费收入, 各个交易对根据占比分配收益
    // uint public allPairFee;
    // 上一个块的总手续费
    // uint public allPairFeeLastBlock;
    // 开始分配收益的块
    // uint public startBlock;
    // 记录当前手续费的块数
    // uint public currentBlock;

    address public rewardToken;     // 收益 token

    uint256 public swapFeeTotal;       // 累计交易手续费
    uint256 public swapFeeCurrent;     // 累计交易手续费 - 已经提取了 reward 的
    uint256 public swapFeeLastBlock;   // 最后一次 mint 的块
    uint256 public ebeRewards;         // 待分配的 ebe
    // tokens created per block to all pair LP
    // uint256 public lpPerBlock;      // LP 每块收益
    // uint256 public traderPerBlock;  // 交易者每块收益
    uint256 public ebePerBlock;        // lp 每块分配多少个 ebe
    // address public lpDepositAddr;   // compound 流动性抵押
    // address public compAddr;        // compound unitroller
    uint256 public feeAlloc;        // 手续费分配方案: 0: 分配给LP; 1: 不分配给LP, 平台收取后兑换为 anchorToken
    // todo How many blocks are halved  182天 应该在 rewardToken 中处理
    // uint256 public halvingPeriod = 5256000;

    modifier ensure(uint deadline) {
        // solhint-disable-next-line
        require(deadline >= block.timestamp, 'DeBankRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _wht, address _cwht, address _ctokenFactory) public {
        factory = _factory;
        WHT = _wht;
        cWHT = _cwht;
        ctokenFactory = LErc20DelegatorInterface(_ctokenFactory);
        // startBlock = _startBlock;
        // heco 链上的 usdt
        quoteTokens.push(IDeBankFactory(_factory).anchorToken()); // usdt
        // todo 应该是 wht
        quoteTokens.push(WHT); // _cwht); // wht
        // quoteTokens.push();  // husd
    }

    function() external payable {
        assert(msg.sender == WHT || msg.sender == cWHT);
        // only accept HT via fallback from the WHT contract
    }

    function pairFor(address tokenA, address tokenB) public view returns (address pair) {
        // pair = IDeBankFactory(factory).pairFor(tokenA, tokenB);
        pair = IDeBankFactory(factory).getPair(tokenA, tokenB);
    }

    function setFeeAlloc(uint _feeAlloc) public onlyOwner {
        require(_feeAlloc == 0 || _feeAlloc == 1, "invalid param feeAlloc");
        feeAlloc = _feeAlloc;
    }

    function setSwapMining(address _swapMininng) public onlyOwner {
        swapMining = _swapMininng;
    }

    function resetQuoteTokens(address[] memory tokens) public onlyOwner {
        for (uint i; i < quoteTokens.length; i ++) {
            quoteTokens.pop();
        }
        // quoteTokens.length = 0;
        for (uint i; i < tokens.length; i ++) {
            quoteTokens.push(tokens[i]);
        }
    }

    function addQuoteToken(address token) public onlyOwner {
        quoteTokens.push(token);
    }

    // set reward token address
    function setRewardToken(address _reword) external onlyOwner {
        rewardToken = _reword;
        // ebePerBlock = _ebePerBlock;
    }

    function setEbePerBlock(uint256 _ebePerBlock) external onlyOwner {
        ebePerBlock = _ebePerBlock;
    }

    // function phase(uint256 blockNumber) public view returns (uint256) {
    //     if (halvingPeriod == 0) {
    //         return 0;
    //     }
    //     if (blockNumber > startBlock) {
    //         return (blockNumber.sub(startBlock).sub(1)).div(halvingPeriod);
    //     }
    //     return 0;
    // }

    // 计算块奖励
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

    // 只能 pair 地址调用该方法
    function mintEBEToken(address token0, address token1, uint256 _amount) external returns (uint) {
        //
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

        // 将 pair 的收益转给 pair
        uint ebeBalance = IERC20(rewardToken).balanceOf(address(this));
        if (swapFeeCurrent >= _amount) {
            uint part = _amount.mul(ebeBalance).div(swapFeeCurrent);
            IEBEToken(rewardToken).transfer(pair, part);
            return part;
        }
        return 0;
    }

    function _getOrCreateCtoken(address token) private returns (address ctoken) {
        // ctoken = LErc20DelegatorInterface(IDeBankFactory(factory).lErc20DelegatorFactory()).getCTokenAddress(token);
        ctoken = ctokenFactory.getCTokenAddress(token);
        require(ctoken != address(0), "get or create etoken failed");
    }

    function _getCtoken(address token) private view returns (address ctoken) {
        // ctoken = LErc20DelegatorInterface(IDeBankFactory(factory).lErc20DelegatorFactory()).getCTokenAddressPure(token);
        ctoken = ctokenFactory.getCTokenAddressPure(token);
        require(ctoken != address(0), "get etoken failed");
    }

    function _getTokenByCtoken(address ctoken) private view returns (address token) {
        // token = LErc20DelegatorInterface(IDeBankFactory(factory).lErc20DelegatorFactory()).getTokenAddress(ctoken);
        token = ctokenFactory.getTokenAddress(ctoken);
        require(token != address(0), "get token failed");
    }

    // function _safeTransferCtoken(address token, address from, address to, uint amt) private {
    //     TransferHelper.safeTransferFrom(_getCtoken(token), from, to, amt);
    // }

    // **** ADD LIQUIDITY ****

    struct LiquidityLocalVars {
        // uint amountToken;
        // uint amountEth;
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

    // tokenA tokenB 都必须是 cToken
    function _addLiquidity(
        LiquidityLocalVars memory liquidity
    ) internal returns (uint amountA, uint amountB) {
        address ctokenA = liquidity.ctokenA;
        address ctokenB = liquidity.ctokenB;
        uint amountADesired  = liquidity.camountDesiredA;
        uint amountBDesired = liquidity.camountDesiredB;
        uint amountAMin = liquidity.camountMinA;
        uint amountBMin = liquidity.camountMinB;
        address tokenA =  liquidity.tokenA; // _getTokenByCtoken(ctokenA);
        address tokenB =  liquidity.tokenB; // _getTokenByCtoken(ctokenB);

        // create the pair if it doesn't exist yet
        if (IDeBankFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IDeBankFactory(factory).createPair(tokenA, tokenB, ctokenA, ctokenB);
        }
        (uint reserveA, uint reserveB) = IDeBankFactory(factory).getReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = IDeBankFactory(factory).quote(amountADesired, reserveA, reserveB);
            // console.log("_addLiquidity: reserveA=%d  reserveB=%d", reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                // console.log("_addLiquidity: amountBOptimal=%d  amountBDesired=%d  amountADesired=%d",
                //       amountBOptimal, amountBDesired, amountADesired);
                require(amountBOptimal >= amountBMin, 'AddLiquidity: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = IDeBankFactory(factory).quote(amountBDesired, reserveB, reserveA);
                // console.log("_addLiquidity: amountAOptimal=%d  amountADesired=%d  amountBDesired=%d",
                //       amountAOptimal, amountADesired, amountBDesired);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'AddLiquidity: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    // tokenA tokenB 都是 cToken, amount 均为 ctoken 的 amount
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
        // console.log(tokenA, tokenB);
        // console.log("amountDesired:", amountADesired, amountBDesired);
        // console.log("amountMin:", amountAMin, amountBMin);
        LiquidityLocalVars memory liquidity;
        liquidity.camountDesiredA = amountADesired;
        liquidity.camountDesiredB = amountBDesired;
        liquidity.camountMinA = amountAMin;
        liquidity.camountMinB = amountBMin;
        liquidity.ctokenA = tokenA;
        liquidity.ctokenB = tokenB;
        liquidity.tokenA = _getTokenByCtoken(tokenA);
        liquidity.tokenB = _getTokenByCtoken(tokenB);
        (amountA, amountB) = _addLiquidity(liquidity); // tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = pairFor(tokenA, tokenB);
        // console.log("pair: %s", pair);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        // _safeTransferCtoken(tokenA, msg.sender, pair, amountA);
        // _safeTransferCtoken(tokenB, msg.sender, pair, amountB);
        liquidityAmt = IDeBankPair(pair).mint(to);
    }

    function _cTokenExchangeRate(address ctoken) private view returns(uint) {
        uint rate = ICToken(ctoken).exchangeRateStored();
        uint256 supplyRate = ICToken(ctoken).supplyRatePerBlock();
        uint256 prevBlock = ICToken(ctoken).accrualBlockNumber();
        rate += rate.mul(supplyRate).mul(block.number - prevBlock);
        return rate;
    }

    // 0. 计算需要多少amount
    // 1. transfer token from msg.sender to router
    // 2. mint ctoken
    // 3. transfer ctoken to pair
    // amt 是 Ctoken 流动性需要的 amount
    function _mintTransferCToken(address token, address ctoken, address pair, uint amt) private {
        // uint er = _cTokenExchangeRate(ctoken);
        // uint amt = camt * er / 10**18;

        // console.log("before transfer");
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amt);
        console.log("transfer %s(%s) done: amt=%d", token, ctoken, amt);
        // uint b0 = ICToken(ctoken).balanceOf(address(this));
        // mint 之前需要 approve
        ICToken(token).approve(address(ctoken), amt);
        (uint ret, uint mintCAmt) = ICToken(ctoken).mint(amt);
        ICToken(ctoken).approve(address(ctoken), 0);
        // console.log("mint token to ctoken %s, amt: %d ret: %d", ctoken, amt, ret);
        require(ret == 0, "mint failed");
        // uint b1 = ICToken(ctoken).balanceOf(address(this));
        // uint mintCAmt = b1 - b0;
        // uint mintCAmt = ICToken(ctoken).balanceOf(address(this));

        // console.log("_mintTransferCToken:", amt, mintCAmt);

        if (address(this) != pair) {
            TransferHelper.safeTransferFrom(ctoken, address(this), pair, mintCAmt);
        }
    }

    function _mintTransferEth(address pair, uint amt) private {
        // uint b0 = ICToken(cWHT).balanceOf(address(this));
        (uint ret, uint mintCAmt) = ILHT(cWHT).mint.value(amt)();
        require(ret == 0, "mint failed");
        console.log("mint eth:", mintCAmt);
        // uint mintCAmt = ICToken(cWHT).balanceOf(address(this));
        // uint mintCAmt = b1 - b0;
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

    // tokenA tokenB 都是 token
    // 6/23 如果 ctoken 不存在, 需要创建 ctoken
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

        (vars.camountA, vars.camountB) = _addLiquidity(vars); //.ctokenA,
                // vars.ctokenB,
                // vars.camountDesiredA,
                // vars.camountDesiredB,
                // vars.camountMinA,
                // vars.camountMinB);
        address pair = pairFor(tokenA, tokenB);
        // mint token 得到 ctoken
        amountA = _camount2Amount(vars.camountA, vars.rateA);
        amountB = _camount2Amount(vars.camountB, vars.rateB);
        // console.log("amountA: %d amountB: %d", amountA, amountB);
        _mintTransferCToken(tokenA, vars.ctokenA, pair, amountA);
        _mintTransferCToken(tokenB, vars.ctokenB, pair, amountB);
        // TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        // TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        // _safeTransferCtoken(tokenA, msg.sender, pair, amountA);
        // _safeTransferCtoken(tokenB, msg.sender, pair, amountB);
        // console.log('addLiquidityUnderlying: pair=%s', pair);
        liquidity = IDeBankPair(pair).mint(to);
    }

    // token 是 token 而不是 ctoken
    // 这个函数应该不能直接被调用了, 如果是 ctoken, 直接调用上面的函数；如果是 token, 需要调用 todo
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
        //     ctoken,
        //     cWHT,
        //     vars.camountDesiredA,
        //     vars.camountDesiredB,
        //     vars.camountMinA,
        //     vars.camountMinB
        // );
        address pair = pairFor(token, WHT);

        amountToken = _camount2Amount(amountCToken, vars.rateA);
        amountETH = _camount2Amount(amountCETH, vars.rateB);
        // console.log("amountToken: %d amountETH: %d", amountToken, amountETH);
        _mintTransferCToken(token, ctoken, pair, amountToken);
        // TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        // _safeTransferCtoken(token, msg.sender, pair, amountToken);
        // IWHT(WHT).deposit.value(amountETH)();
        _mintTransferEth(pair, amountETH);
        // cWHT.value(amountETH).mint();
        // assert(IWHT(WHT).transfer(pair, amountETH));
        liquidity = IDeBankPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    // tokenA tokenB 都是 ctoken
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
        // console.log("transfer Liquidity success");
        // send liquidity to pair
        (uint amount0, uint amount1) = IDeBankPair(pair).burn(to);
        address tokenA = _getTokenByCtoken(ctokenA);
        address tokenB = _getTokenByCtoken(ctokenB);
        (address token0,) = IDeBankFactory(factory).sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'RemoveLiquidity: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'RemoveLiquidity: INSUFFICIENT_B_AMOUNT');
    }

    // 赎回 ctoken
    function _redeemCToken(address ctoken, uint camt) private returns (uint) {
        // uint b0 = IERC20(token).balanceOf(address(this));
        // console.log("ctoken balance:", ctoken, IERC20(ctoken).balanceOf(address(this)));
        (uint err, uint amt, ) = ICToken(ctoken).redeem(camt);
        require(err == 0, "redeem failed");
        return amt;
        // return IERC20(token).balanceOf(address(this));
        // uint b1 = IERC20(token).balanceOf(address(this));
        // console.log(b1, b0);
        // require(b1 >= b0, "redeem failed");
        // return b1.sub(b0);
    }

    // 赎回 ctoken
    function _redeemCEth(uint camt) private returns (uint) {
        // uint b0 = IERC20(WHT).balanceOf(address(this));
        (uint err, uint amt, ) = ICToken(cWHT).redeem(camt);
        require(err == 0, "redeem failed");
        return amt;
        // uint b1 = IERC20(WHT).balanceOf(address(this));
        // return b1.sub(b0);
    }

    function _redeemCTokenTransfer(address ctoken, address token, address to, uint camt) private returns (uint)  {
        // console.log("_redeemCTokenTransfer: redeem amt: %d", camt);
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

    // tokenA tokenB 都是 token amount都是 token 的 amount
    // 从 ctoken redeem token 可能会失败(额度不足), 因此, 
    // 在调用之前, 前端必须校验借贷池余额是否足够！！！
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
        // 确保只有owner可以移除流动性
        // require(IDeBankPair(pair).ownerAmountOf(to) >= liquidity, "not owner or not enough");

        IDeBankPair(pair).transferFrom(msg.sender, pair, liquidity);
        LiquidityLocalVars memory vars;
        {
            vars.tokenA = tokenA;
            vars.tokenB = tokenB;
            //  先把 ctoken 发送给 router
            (uint camount0, uint camount1) = IDeBankPair(pair).burn(address(this));
            (address token0,) = IDeBankFactory(factory).sortTokens(vars.tokenA, vars.tokenB);
            (vars.camountA, vars.camountB) = tokenA == token0 ? (camount0, camount1) : (camount1, camount0);
        }
        // console.log("camountA: %d camountB: %d", vars.camountA, vars.camountB);
        amountA = _redeemCTokenTransfer(_getCtoken(tokenA), tokenA, to, vars.camountA);
        amountB = _redeemCTokenTransfer(_getCtoken(tokenB), tokenB, to, vars.camountB);

        // console.log("amountA: %d amountB: %d", amountA, amountB);
        // TransferHelper.safeTransfer(tokenA, to, amountA);
        // TransferHelper.safeTransfer(tokenB, to, amountB);
        // address ctokenB = _getCtoken(tokenB);
        // ICToken(ctokenA).redeem(camountA);
        // ICToken(ctokenB).redeem(camountB);

        require(amountA >= amountAMin, 'RemoveLiquidityUnderlying: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'RemoveLiquidityUnderlying: INSUFFICIENT_B_AMOUNT');
    }

    // 在调用之前, 前端必须校验借贷池余额是否足够！！！
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
        // TransferHelper.safeTransfer(token, to, amountToken);
        // IWHT(WHT).withdraw(amountETH);
        amountETH = _redeemCETHTransfer(to, amountCETH);
        // to.transfer(amountETH);
        // TransferHelper.safeTransferETH(to, amountETH);
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

    // 兑换手续费, 不收手续费
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
        console.log("_swapFee: feeIn=%d feeOut=%d", feeIn, feeOut);
    }

    struct SwapAnchorParam {
        uint fr;            // fee rate
        address input;
        address cinput;
        address pair;
        address feeTo;
        address anchorToken;
    }

    // 将收到的手续费 token 转换为 anchorToken
    // input 为 token
    // swap后得到的是 canchorToken, cUSDT
    function _swapToCAnchorToken(
                    SwapAnchorParam memory param,
                    uint amountIn
                )
                internal
                returns (uint feeIn, uint fee) {
        // address feeTo = IDeBankFactory(factory).feeTo();
        // uint amountIn = IERC20(_getCtoken(input)).balanceOf(pair);    // 输入转入
        uint feeRate = param.fr;
        address pair = param.pair;
        address input = param.input;
        address anchorToken = param.anchorToken;
        address feeTo = param.feeTo;

        // uint feeIn;
        if (feeRate == 0) {
            feeIn = IDeBankPair(pair).getFee(amountIn);
        } else {
            feeIn = IDeBankPair(pair).getFee(amountIn, feeRate - 1);
        }
        console.log("amountIn: %d  feeIn: %d", amountIn, feeIn);

        if (input == anchorToken) {
            // 直接收
            fee = feeIn;
            IERC20(param.cinput).transfer(feeTo, fee);
            // feeTotal = feeTotal.add(feeIn);
        } else {
            // 兑换成 anchorToken
            address cinput = param.cinput; // _getCtoken(input);
            for (uint i; i < quoteTokens.length; i ++) {
                address token = quoteTokens[i];
                address tPair = IDeBankFactory(factory).getPair(input, token);

                // console.log("_swapToCAnchorToken: input=%s token=%s pair=%s", input, token, tPair);
                if (tPair != address(0)) {
                    if (token == anchorToken) {
                        // 兑换成功
                        IERC20(cinput).transfer(tPair, feeIn);
                        fee = _swapFee(input, tPair, feeIn, feeTo);
                    } else {
                        // 需要两步兑换
                        // 第一步, 兑换为中间币种 例如ht husd btc
                        address pair2 = IDeBankFactory(factory).getPair(token, anchorToken);
                        require(pair2 != address(0), "quote coin has no pair to anchorToken");
                        IERC20(cinput).transfer(tPair, feeIn);
                        uint fee1 = _swapFee(input, tPair, feeIn, pair2);
                        // 第二步
                        fee = _swapFee(token, pair2, fee1, feeTo);
                    }
                    break;
                }
            }
        }

        // return fee;
    }

    function _updatePairFee(uint fee) private {
        // 更新所有交易对的手续费
        // if (currentBlock == block.number) {
        //     allPairFee += fee;
        // } else {
        //     //
        //     allPairFeeLastBlock = allPairFee;
        //     allPairFee = fee;
        //     currentBlock = block.number;
        // }
        swapFeeTotal += fee;
        swapFeeCurrent += fee;
    }


    // 将手续费兑换为 anchor token
    // 先将手续费收完 !!!
    function _swap2(uint amtIn, address[] memory path, address _to) internal returns (uint256 amtOut, uint feeTotal) {
        SwapAnchorParam memory param;

        param.feeTo = IDeBankFactory(factory).feeTo();
        require(param.feeTo != address(0), "feeTo not set");
        param.anchorToken = IDeBankFactory(factory).anchorToken();
        param.fr = IDeBankFactory(factory).feeRateOf(_to);

        uint amountIn = amtIn;
        uint fee;
        // uint feeTotal;
        for (uint i; i < path.length - 1; i++) {
            param.input = path[i];
            param.cinput = _getCtoken(param.input);
            param.pair = IDeBankFactory(factory).getPair(path[i], path[i+1]);
            // address feeTo = IDeBankFactory(factory).feeTo();
            // uint amountOut = amounts[i + 1];
            
            // (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            // (uint feeIn, uint fee) = _swapToCAnchorToken(amountIn, input, pair, anchorToken, feeTo, fr);
            // console.log("fee:", fee);
            // // if (fee > 0) {
            //     feeTotal += fee;
            // // }

            // // transfer to pair

            // amountIn = amountIn.sub(feeIn);
            // // input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            // (uint amount0Out, uint amount1Out) = _calcAmountOut(input, pair, amountIn);
            // IERC20(input).transfer(pair, amountIn);
            address to = i < path.length - 2 ? address(this) : _to;
            // IDeBankPair(pair).swapNoFee(
            //     amount0Out, amount1Out, to, fee
            // );
            // amountIn = amount1Out;
            (amtOut, fee) = _doSwapAnchorToken(param, amountIn, to);
            feeTotal += fee;
            amountIn = amtOut;
        }

        if (swapMining != address(0)) {
            // 交易挖矿
            ISwapMining(swapMining).swap(msg.sender, path[0], path[1], feeTotal);
        }

        if (feeTotal > 0) {
            _updatePairFee(feeTotal);
        }
        // return amountIn;
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
        // address anchorToken = param.anchorToken;
        // uint fr = param.fr;

        console.log("before swapfee: balance: %d transfer: %d", IERC20(param.cinput).balanceOf(address(this)), amountIn);
        (uint feeIn, uint fee) = _swapToCAnchorToken(param, amountIn);
        // transfer to pair

        amountIn = amountIn.sub(feeIn);
        // input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
        (uint amount0Out, uint amount1Out, uint amountOut) = _calcAmountOut(input, pair, amountIn);
        console.log("amountIn: %d amount0Out: %d amount1Out: %d", amountIn, amount0Out, amount1Out);
        console.log("balance: %d transfer: %d", IERC20(param.cinput).balanceOf(address(this)), amountIn);
        IERC20(param.cinput).transfer(pair, amountIn);
        // console.log("before swap");
        // address to = i < path.length - 2 ? address(this) : _to;
        IDeBankPair(pair).swapNoFee(
            amount0Out, amount1Out, to, fee
        );
        // amountIn = amount1Out;
        // return ()
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
        address token0 = IDeBankPair(pair).token0(); // IDeBankFactory(factory).sortTokens(input, output);
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

    // **** SWAP ****
    // amounts 为 ctoken 的 amount
    // path 中的 token 均为 token, 调用前请转换！！！
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        // uint feeTotal;  // by anchorToken
        // address anchorToken = IDeBankFactory(factory).anchorToken();
        // address[] memory path = _cpath2path(cpath);

        // console.log("_swap ....");
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = IDeBankFactory(factory).sortTokens(input, output);
            // address pair = IDeBankFactory(factory).getPair(path[i], path[i + 1]);
            // address feeTo = IDeBankFactory(factory).feeTo();
            // uint feeRate = IDeBankPair(pair).feeRate();
            uint amountOut = amounts[i + 1];
            // uint amountIn = IERC20(pair).balanceOf(pair);    // 输入转入
            // uint feeIn = IDeBankPair(pair).getFee(amountIn);

            // feeTotal = feeTotal.add();
            // if (feeTotal > 0) {
            //     // 分配LP手续费奖励
            // }

            
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? pairFor(output, path[i + 2]) : _to;
            // if (feeAlloc == 1) {
            //     // 收手续费, 并将手续费兑换为 canchorToken(cUSDT)
            //     uint fee = _swapToCAnchorToken(amounts[i], input, pair, anchorToken);
            //     console.log("fee:", fee);
            //     if (fee > 0) {
            //         _updatePairFee(fee);
            //     }

            //     if (swapMining != address(0)) {
            //         // 交易挖矿
            //         ISwapMining(swapMining).swap(msg.sender, input, output, fee);
            //     }

            //     // transfer to pair
            //     IDeBankPair(pairFor(input, output)).swapNoFee(
            //         amount0Out, amount1Out, to, fee
            //     );
            // } else {
                IDeBankPair(pairFor(input, output)).swap(
                    amount0Out, amount1Out, to, new bytes(0)
                );
            // }
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

    // amount token 均为 ctoken
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata cpath,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts, uint fee) {
        // console.log('swapExactTokensForTokens ....');
        address[] memory path = _cpath2path(cpath);
        amounts = IDeBankFactory(factory).getAmountsOut(amountIn, path, to);
        // console.log(amounts[0], amounts[1]);
        require(amounts[amounts.length - 1] >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        if (feeAlloc == 0) {
            TransferHelper.safeTransferFrom(cpath[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
            _swap(amounts, path, to);
        } else {
            TransferHelper.safeTransferFrom(cpath[0], msg.sender, address(this), amounts[0]);
            (, fee) = _swap2(amountIn, path, to);
        }
    }

    // amount token 均为 ctoken
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata cpath,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts, uint fee) {
        // console.log('swapTokensForExactTokens ....');
        address[] memory path = _cpath2path(cpath);
        amounts = IDeBankFactory(factory).getAmountsIn(amountOut, path, to);
        require(amounts[0] <= amountInMax, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
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
        // console.log('_swapExactTokensForTokensUnderlying ....');
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
        console.log("mint transfer ok: %d", amountIn);

        SwapLocalVars memory vars;
        vars.amountIn = amountIn;
        vars.rate0 = _cTokenExchangeRate(cpath[0]);
        vars.rate1 = _cTokenExchangeRate(cpath[0]);
        uint camtIn = _amount2CAmount(amountIn, vars.rate0);
        uint camtOut;
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );

        // TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        // 先将 ctoken 转给 router
        if (feeAlloc == 0) {
            uint[] memory camounts = IDeBankFactory(factory).getAmountsOut(camtIn, path, to);
            console.log("_swapExactTokensForTokensUnderlying: in/out: %d %d", camounts[0], camounts[camounts.length-1]);

            console.log("camounts: ", camounts[0], camounts[1]);
            camtOut = camounts[camounts.length-1];
            vars.amountOut = _camount2Amount(camtOut, vars.rate1);
            require(vars.amountOut >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
            _swap(camounts, path, address(this));
        } else {
            (camtOut, ) = _swap2(camtIn, path, address(this));
            require(vars.amountOut >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        }

        // vars.amountOut = 
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

    // amount token 均为 token
    // 调用者需要验证借贷池中的 path[path.length-1] 的资金足够！！！
    function swapExactTokensForTokensUnderlying(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        // console.log('swapExactTokensForTokensUnderlying ....');
        amounts = _swapExactTokensForTokensUnderlying(amountIn, amountOutMin, path, to, deadline, false, false);
        // address[] memory cpath = _path2cpath(path);
        // uint rate0 = _cTokenExchangeRate(cpath[0]);
        // uint rate1 = _cTokenExchangeRate(cpath[0]);
        // uint camtIn = _amount2CAmount(amountIn, rate0);
        // uint[] memory camounts = IDeBankFactory(factory).getAmountsOut(camtIn, path);
        // console.log(camounts[0], camounts[1]);
        // uint amountOut = _camount2Amount(camounts[camounts.length - 1], rate1);
        // require(amountOut >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // // _safeTransferCtoken(
        // //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // // );
        // _mintTransferCToken(path[0], cpath[0], pairFor(path[0], path[1]), amountIn);
        // // TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        // _swap(camounts, path, to);
        // uint idx = path.length - 1;
        // _redeemCTokenTransfer(cpath[idx], path[idx], to, camounts[idx]);

        // amounts = new uint[](path.length);
        // amounts[0] = amountIn;
        // amounts[idx] = amountOut;
    }

    struct SwapLocalVars {
        uint rate0;
        uint rate1;
        uint amountIn;
        uint amountOut;
    }

    /*
    function _swapTokensForExactTokensUnderlying(
        uint amountOut,
        uint amountInMax,
        address[] memory path,
        address to,
        uint deadline,
        bool ethIn,
        bool ethOut
    ) private ensure(deadline) returns (uint[] memory amounts) {
        // console.log('_swapTokensForExactTokensUnderlying ....');
        address[] memory cpath = _path2cpath(path);
        SwapLocalVars memory vars;

        vars.rate0 = _cTokenExchangeRate(cpath[0]);
        vars.rate1 = _cTokenExchangeRate(cpath[path.length-1]);
        uint camtOut = _amount2CAmount(amountOut, vars.rate1);
        uint[] memory camounts = IDeBankFactory(factory).getAmountsIn(camtOut, path, to);
        console.log("camounts:", camounts[0], camounts[1], camtOut);
        
        vars.amountIn = _camount2Amount(camounts[0], vars.rate0);
        // 上一步中舍去的 1
        vars.amountIn = vars.amountIn.add(1);
        // console.log("amountIn:", vars.amountIn);
        require(vars.amountIn <= amountInMax, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        if (ethIn) {
            _mintTransferEth(pairFor(path[0], path[1]), vars.amountIn);
        } else {
            _mintTransferCToken(path[0], cpath[0], pairFor(path[0], path[1]), vars.amountIn);
        }
        console.log("mint transfer ok: %d", vars.amountIn);
        // TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        // 先转给 router, 再由 router redeem 后, 转给 to
        _swap(camounts, path, address(this));
        uint idx = path.length - 1;
        if (ethOut) {
            _redeemCETHTransfer(to, camounts[idx]);
        } else {
            _redeemCTokenTransfer(cpath[idx], path[idx], to, camounts[idx]);
        }
        console.log("redeem transfer ok: %d", camounts[idx]);

        amounts = new uint[](path.length);
        amounts[0] = vars.amountIn;
        amounts[idx] = amountOut;
    }

    // amount token 均为 ctoken
    function swapTokensForExactTokensUnderlying(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        // console.log('swapTokensForExactTokensUnderlying ....');
        amounts = _swapTokensForExactTokensUnderlying(amountOut, amountInMax, path, to, deadline, false, false);
        // address[] memory cpath = _path2cpath(path);
        // uint rate0 = _cTokenExchangeRate(cpath[0]);
        // uint rate1 = _cTokenExchangeRate(cpath[0]);
        // uint camtOut = _amount2CAmount(amountOut, rate1);
        // uint[] memory camounts = IDeBankFactory(factory).getAmountsIn(camtOut, path);
        
        // uint amountIn = _camount2Amount(camounts[0], rate0);
        // require(amountIn <= amountInMax, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // // _safeTransferCtoken(
        // //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // // );
        // _mintTransferCToken(path[0], cpath[0], pairFor(path[0], path[1]), amountIn);
        // // TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]);
        // _swap(camounts, path, to);
        // uint idx = path.length - 1;
        // _redeemCTokenTransfer(cpath[idx], path[idx], to, camounts[idx]);

        // amounts = new uint[](path.length);
        // amounts[0] = amountIn;
        // amounts[idx] = amountOut;
    }
    */

    function swapExactETHForTokensUnderlying(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        console.log('swapExactETHForTokensUnderlying: %d ....', msg.value);
        require(path[0] == WHT, 'Router: INVALID_PATH');
        amounts = _swapExactTokensForTokensUnderlying(msg.value, amountOutMin, path, to, deadline, true, false);
        // amounts = IDeBankFactory(factory).getAmountsOut(msg.value, path);
        // require(amounts[amounts.length - 1] >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // IWHT(WHT).deposit.value(amounts[0])();
        // assert(IWHT(WHT).transfer(pairFor(path[0], path[1]), amounts[0]));
        // _swap(amounts, path, to);
    }

    /*
    function swapTokensForExactETHUnderlying(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // console.log('swapTokensForExactETH ....');
        require(path[path.length - 1] == WHT, 'Router: INVALID_PATH');
        amounts = _swapTokensForExactTokensUnderlying(amountOut, amountInMax, path, to, deadline, false, true);
        // amounts = IDeBankFactory(factory).getAmountsIn(amountOut, path);
        // require(amounts[0] <= amountInMax, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        // _swap(amounts, path, address(this));
        // IWHT(WHT).withdraw(amounts[amounts.length - 1]);
        // TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    */

    function swapExactTokensForETHUnderlying(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // console.log('swapExactTokensForETHUnderlying ....');
        require(path[path.length - 1] == WHT, 'Router: INVALID_PATH');
        amounts = _swapExactTokensForTokensUnderlying(amountIn, amountOutMin, path, to, deadline, false, true);
        // amounts = IDeBankFactory(factory).getAmountsOut(amountIn, path);
        // require(amounts[amounts.length - 1] >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // _safeTransferCtoken(
        //     path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        // );
        // _swap(amounts, path, address(this));
        // IWHT(WHT).withdraw(amounts[amounts.length - 1]);
        // TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /*
    function swapETHForExactTokensUnderlying(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // console.log('swapETHForExactTokensUnderlying ....');
        require(path[0] == WHT, 'Router: INVALID_PATH');
        amounts = _swapTokensForExactTokensUnderlying(amountOut, msg.value, path, to, deadline, true, false);
        // amounts = IDeBankFactory(factory).getAmountsIn(amountOut, path);
        // require(amounts[0] <= msg.value, 'Router: EXCESSIVE_INPUT_AMOUNT');
        // IWHT(WHT).deposit{value : amounts[0]}();
        // assert(IWHT(WHT).transfer(pairFor(path[0], path[1]), amounts[0]));
        // _swap(amounts, path, to);
        // // refund dust eth, if any
        // if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }
    */

    function adminTransfer(address token, address to, uint amt) external onlyOwner {
        if (token == address(0)) {
          TransferHelper.safeTransferETH(to, amt);
        } else {
          TransferHelper.safeTransferFrom(token, address(this), to, amt);
        }
    }
    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    // function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal {
    //     for (uint i; i < path.length - 1; i++) {
    //         (address input, address output) = (path[i], path[i + 1]);
    //         (address token0,) = IDeBankFactory(factory).sortTokens(input, output);
    //         IDeBankPair pair = IDeBankPair(pairFor(input, output));
    //         uint amountInput;
    //         uint amountOutput;
    //         {// scope to avoid stack too deep errors
    //             (uint reserve0, uint reserve1,) = pair.getReserves();
    //             (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    //             amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
    //             amountOutput = IDeBankFactory(factory).getAmountOut(amountInput, reserveInput, reserveOutput);
    //         }
    //         if (swapMining != address(0)) {
    //             ISwapMining(swapMining).swap(msg.sender, input, output, amountOutput);
    //         }
    //         (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
    //         address to = i < path.length - 2 ? pairFor(output, path[i + 2]) : _to;
    //         pair.swap(amount0Out, amount1Out, to, new bytes(0));
    //     }
    // }

    // function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external ensure(deadline) {
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, pairFor(path[0], path[1]), amountIn
    //     );
    //     uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
    //     _swapSupportingFeeOnTransferTokens(path, to);
    //     require(
    //         IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
    //         'Router: INSUFFICIENT_OUTPUT_AMOUNT'
    //     );
    // }

    // function swapExactETHForTokensSupportingFeeOnTransferTokens(
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // )
    // external
    // payable
    // ensure(deadline)
    // {
    //     require(path[0] == WHT, 'Router: INVALID_PATH');
    //     uint amountIn = msg.value;
    //     IWHT(WHT).deposit.value(amountIn)();
    //     assert(IWHT(WHT).transfer(pairFor(path[0], path[1]), amountIn));
    //     uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
    //     _swapSupportingFeeOnTransferTokens(path, to);
    //     require(
    //         IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
    //         'Router: INSUFFICIENT_OUTPUT_AMOUNT'
    //     );
    // }

    // function swapExactTokensForETHSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // )
    // external
    // ensure(deadline)
    // {
    //     require(path[path.length - 1] == WHT, 'Router: INVALID_PATH');
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, pairFor(path[0], path[1]), amountIn
    //     );
    //     _swapSupportingFeeOnTransferTokens(path, address(this));
    //     uint amountOut = IERC20(WHT).balanceOf(address(this));
    //     require(amountOut >= amountOutMin, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
    //     IWHT(WHT).withdraw(amountOut);
    //     TransferHelper.safeTransferETH(to, amountOut);
    // }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public view returns (uint256 amountB) {
        return IDeBankFactory(factory).quote(amountA, reserveA, reserveB);
    }

    // function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view returns (uint256 amountOut){
    //     return IDeBankFactory(factory).getAmountOut(amountIn, reserveIn, reserveOut);
    // }

    // function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public view returns (uint256 amountIn){
    //     return IDeBankFactory(factory).getAmountIn(amountOut, reserveIn, reserveOut);
    // }

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

    // function getCtoken(address ctokenFactory, address token) public view returns (address ctoken) {
    //     // ctoken = LErc20DelegatorInterface(IDeBankFactory(factory).lErc20DelegatorFactory()).getCTokenAddressPure(token);
    //     ctoken = LErc20DelegatorInterface(ctokenFactory).getCTokenAddressPure(token);
    // }

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


    // 获取添加流动性的数量
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
            // avoid stack too deep
            address ctokenA = LErc20DelegatorInterface(ctokenFactory).getCTokenAddressPure(tokenA);
            address ctokenB = LErc20DelegatorInterface(ctokenFactory).getCTokenAddressPure(tokenB);
            rateA = getCurrentExchangeRate(ctokenA);
            rateB = getCurrentExchangeRate(ctokenB);
        }
        // uint cAmtA = amountA.mul(e18).div(rateA);
        // uint cAmtB = cAmtA.mul(rb).div(ra);
        // uint amtB = cAmtB.mul(rateB).div(e18);
        // return amtB;

        return amountA.mul(rb).mul(rateB).div(rateA).div(ra);
    }

    /// @dev 给定 amountIn, 计算能够兑换得到的amountOut
    /// @param path token 数组, 注意: 必须是token的地址!!!
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
        //
        address[] memory cpath = path2cpath(ctokenFactory, path);
        uint256 rateIn = getCurrentExchangeRate(cpath[0]);
        uint256 cAmtIn = amountIn.mul(1e18).div(rateIn);
        amounts = IDeBankFactory(factory).getAmountsOut(cAmtIn, path, to);
        // console.log("cAmtIn: %d amountOut: %d", cAmtIn, amounts[1]);
        uint256 rateOut = getCurrentExchangeRate(cpath[cpath.length-1]);
        amountOut = amounts[amounts.length-1].mul(rateOut).div(1e18);
    }

    /// @dev 给定 amountOut, 计算输入的amountIn
    /// @param path token 数组, 注意: 必须是token的地址!!!
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
        //
        address[] memory cpath = path2cpath(ctokenFactory, path);
        uint256 rateOut = getCurrentExchangeRate(cpath[cpath.length-1]);
        uint256 cAmtOut = amountOut.mul(1e18).div(rateOut);
        amounts = IDeBankFactory(factory).getAmountsIn(cAmtOut, path, to);
        uint256 rateIn = getCurrentExchangeRate(cpath[0]);
        amountIn = amounts[0].mul(rateIn).div(1e18);
    }
}


// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = to.call.value(value)(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}
