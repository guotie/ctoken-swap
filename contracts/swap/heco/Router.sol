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

import "@openzeppelin/contracts/access/Ownable.sol";
import "../library/SafeMath.sol";
import "../interface/IERC20.sol";
import "../../common/IMdexFactory.sol";
import "../../common/IMdexPair.sol";
import "../../common/IMdexRouter.sol";
import "../../common/IWHT.sol";
import "../../common/LErc20DelegatorInterface.sol";

import "hardhat/console.sol";

interface ISwapMining {
    function swap(address account, address input, address output, uint256 amount) external returns (bool);
}


contract MdexRouter is IMdexRouter, Ownable {
    using SafeMath for uint256;

    address public immutable override factory;
    address public immutable override WHT;
    address public override swapMining;
    address[] public quoteTokens;
    address public immutable cWHT;

    // 所有交易对产生的手续费收入, 各个交易对根据占比分配收益
    uint public override allPairFee;
    // 上一个块的总手续费
    uint public override allPairFeeLastBlock;
    // 开始分配收益的块
    uint public override startBlock;
    // 记录当前手续费的块数
    uint public currentBlock;
    // tokens created per block to all pair LP
    uint256 public lpPerBlock;      // LP 每块收益
    uint256 public traderPerBlock;  // 交易者每块收益
    // How many blocks are halved  182天
    uint256 public halvingPeriod = 5256000;
    address public rewardToken; // 收益 token 

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'MdexRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WHT, address _cWHT, uint _startBlock) {
        factory = _factory;
        WHT = _WHT;
        cWHT = _cWHT;
        startBlock = _startBlock;
        // heco 链上的 usdt
        quoteTokens.push(IMdexFactory(_factory).anchorToken()); // usdt
        quoteTokens.push(_WHT); // wht
        // quoteTokens.push();  // husd
    }

    receive() external payable {
        assert(msg.sender == WHT);
        // only accept HT via fallback from the WHT contract
    }

    function pairFor(address tokenA, address tokenB) public view returns (address pair){
        pair = IMdexFactory(factory).pairFor(tokenA, tokenB);
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

    function phase(uint256 blockNumber) public view returns (uint256) {
        if (halvingPeriod == 0) {
            return 0;
        }
        if (blockNumber > startBlock) {
            return (blockNumber.sub(startBlock).sub(1)).div(halvingPeriod);
        }
        return 0;
    }

    // 计算块奖励
    function reward(uint256 blockNumber) public override view returns (uint256) {
        // todo totalSupply !!!
        // if (IERC20(rewardToken).totalSupply() > 1e28) {
        //     return 0;
        // }
        uint256 _phase = phase(blockNumber);
        return lpPerBlock.div(2 ** _phase);
    }

    function getBlockRewards(uint256 _lastRewardBlock) public override view returns (uint256) {
        uint256 blockReward = 0;
        uint256 n = phase(_lastRewardBlock);
        uint256 m = phase(block.number);
        while (n < m) {
            n++;
            uint256 r = n.mul(halvingPeriod).add(startBlock);
            blockReward = blockReward.add((r.sub(_lastRewardBlock)).mul(reward(r)));
            _lastRewardBlock = r;
        }
        blockReward = blockReward.add((block.number.sub(_lastRewardBlock)).mul(reward(block.number)));
        return blockReward;
    }

    function _getCtoken(address token) private view returns (address ctoken) {
        ctoken = LErc20DelegatorInterface(IMdexFactory(factory).lErc20DelegatorFactory()).getCTokenAddressPure(token);
    }

    function _safeTransferCtoken(address token, address from, address to, uint amt) private {
        TransferHelper.safeTransferFrom(_getCtoken(token), from, to, amt);
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IMdexFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IMdexFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = IMdexFactory(factory).getReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = IMdexFactory(factory).quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'MdexRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = IMdexFactory(factory).quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'MdexRouter: INSUFFICIENT_A_AMOUNT');
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
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = pairFor(tokenA, tokenB);
        // TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        // TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        _safeTransferCtoken(tokenA, msg.sender, pair, amountA);
        _safeTransferCtoken(tokenB, msg.sender, pair, amountB);
        liquidity = IMdexPair(pair).mint(to);
    }

    // 这个函数应该不能直接被调用了, 如果是 ctoken, 直接调用上面的函数；如果是 token, 需要调用 todo
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WHT,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = pairFor(token, WHT);
        // TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        _safeTransferCtoken(token, msg.sender, pair, amountToken);
        IWHT(WHT).deposit{value : amountETH}();
        assert(IWHT(WHT).transfer(pair, amountETH));
        liquidity = IMdexPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = pairFor(tokenA, tokenB);
        IMdexPair(pair).transferFrom(msg.sender, pair, liquidity);
        // send liquidity to pair
        (uint amount0, uint amount1) = IMdexPair(pair).burn(to);
        (address token0,) = IMdexFactory(factory).sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'MdexRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'MdexRouter: INSUFFICIENT_B_AMOUNT');
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WHT,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWHT(WHT).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
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
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = pairFor(tokenA, tokenB);
        uint value = approveMax ? uint(- 1) : liquidity;
        IMdexPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = pairFor(token, WHT);
        uint value = approveMax ? uint(- 1) : liquidity;
        IMdexPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WHT,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWHT(WHT).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = pairFor(token, WHT);
        uint value = approveMax ? uint(- 1) : liquidity;
        IMdexPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // 兑换手续费, 不收手续费
    function _swapFee(address pair, uint feeIn, address feeTo) internal returns (uint feeOut) {
        (uint reserve0, uint reserve1, ) = IMdexPair(pair).getReserves();
        feeOut = feeIn.mul(reserve1).div(reserve0.add(feeIn));
        IMdexPair(pair).swapNoFee(0, feeOut, feeTo, feeOut);
    }

    // 将收到的手续费 token 转换为 anchorToken
    function _swapToAnchorToken(address input, address pair, address anchorToken) internal returns (uint fee) {
        address feeTo = IMdexFactory(factory).feeTo();
        uint amountIn = IERC20(_getCtoken(input)).balanceOf(pair);    // 输入转入
        uint feeIn = IMdexPair(pair).getFee(amountIn);
        console.log("amountIn: %d  feeIn: %d", amountIn, feeIn);

        if (input == anchorToken) {
            // 直接收
            fee = feeIn;
            // feeTotal = feeTotal.add(feeIn);
        } else {
            // 兑换成 anchorToken
            // uint fee = _swapToAnchorToken(input, amountIn);
            for (uint i; i < quoteTokens.length; i ++) {
                address token = quoteTokens[i];
                address tPair = IMdexFactory(factory).getPair(input, token);

                console.log("_swapToAnchorToken: input=%s token=%s pair=%s", input, token, tPair);
                if (tPair != address(0)) {
                    if (token == anchorToken) {
                        // 兑换成功
                        IERC20(tPair).transfer(tPair, feeIn);
                        fee = _swapFee(tPair, feeIn, feeTo);
                    } else {
                        // 需要两步兑换
                        // 第一步, 兑换为中间币种 例如ht husd btc
                        address pair2 = IMdexFactory(factory).getPair(token, anchorToken);
                        require(pair2 != address(0), "quote coin has no pair to anchorToken");
                        IERC20(tPair).transfer(tPair, feeIn);
                        uint fee1 = _swapFee(tPair, feeIn, pair2);
                        // 第二步
                        fee = _swapFee(pair2, fee1, feeTo);
                    }
                    break;
                }
            }
        }

        console.log("_swapToAnchorToken: input: %s  fee: %d  ", input, fee);
        // IERC20(anchorToken).transfer(feeTo, fee);
        return fee;
    }

    function _updatePairFee(uint fee) private {
        // 更新所有交易对的手续费
        if (currentBlock == block.number) {
            allPairFee += fee;
        } else {
            //
            allPairFeeLastBlock = allPairFee;
            allPairFee = fee;
            currentBlock = block.number;
        }
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        uint feeTotal;  // by anchorToken
        address anchorToken = IMdexFactory(factory).anchorToken();

        console.log("_swap ....");
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = IMdexFactory(factory).sortTokens(input, output);
            address pair = IMdexFactory(factory).getPair(path[i], path[i + 1]);
            // address feeTo = IMdexFactory(factory).feeTo();
            // uint feeRate = IMdexPair(pair).feeRate();
            uint amountOut = amounts[i + 1];
            // uint amountIn = IERC20(pair).balanceOf(pair);    // 输入转入
            // uint feeIn = IMdexPair(pair).getFee(amountIn);

            // 收手续费
            uint fee = _swapToAnchorToken(input, pair, anchorToken);
            if (fee > 0) {
                _updatePairFee(fee);
            }
            // feeTotal = feeTotal.add();
            // if (feeTotal > 0) {
            //     // 分配LP手续费奖励
            // }

            if (swapMining != address(0)) {
                // 交易挖矿
                ISwapMining(swapMining).swap(msg.sender, input, output, amountOut);
            }
            
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? pairFor(output, path[i + 2]) : _to;
            IMdexPair(pairFor(input, output)).swapNoFee(
                amount0Out, amount1Out, to, fee
            );
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        console.log('swapExactTokensForTokens ....');
        amounts = IMdexFactory(factory).getAmountsOut(amountIn, path);
        console.log(amounts[0], amounts[1]);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MdexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        _safeTransferCtoken(
            path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        console.log('swapTokensForExactTokens ....');
        amounts = IMdexFactory(factory).getAmountsIn(amountOut, path);
        require(amounts[0] <= amountInMax, 'MdexRouter: EXCESSIVE_INPUT_AMOUNT');
        _safeTransferCtoken(
            path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    // external
    // virtual
    // override
    // payable
    // ensure(deadline)
    // returns (uint[] memory amounts)
    // {
    //     console.log('swapExactETHForTokens ....');
    //     require(path[0] == WHT, 'MdexRouter: INVALID_PATH');
    //     amounts = IMdexFactory(factory).getAmountsOut(msg.value, path);
    //     require(amounts[amounts.length - 1] >= amountOutMin, 'MdexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
    //     IWHT(WHT).deposit{value : amounts[0]}();
    //     assert(IWHT(WHT).transfer(pairFor(path[0], path[1]), amounts[0]));
    //     _swap(amounts, path, to);
    // }

    // function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    // external
    // virtual
    // override
    // ensure(deadline)
    // returns (uint[] memory amounts)
    // {
    //     console.log('swapTokensForExactETH ....');
    //     require(path[path.length - 1] == WHT, 'MdexRouter: INVALID_PATH');
    //     amounts = IMdexFactory(factory).getAmountsIn(amountOut, path);
    //     require(amounts[0] <= amountInMax, 'MdexRouter: EXCESSIVE_INPUT_AMOUNT');
    //     _safeTransferCtoken(
    //         path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
    //     );
    //     _swap(amounts, path, address(this));
    //     IWHT(WHT).withdraw(amounts[amounts.length - 1]);
    //     TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    // }

    // function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    // external
    // virtual
    // override
    // ensure(deadline)
    // returns (uint[] memory amounts)
    // {
    //     console.log('swapExactTokensForETH ....');
    //     require(path[path.length - 1] == WHT, 'MdexRouter: INVALID_PATH');
    //     amounts = IMdexFactory(factory).getAmountsOut(amountIn, path);
    //     require(amounts[amounts.length - 1] >= amountOutMin, 'MdexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
    //     _safeTransferCtoken(
    //         path[0], msg.sender, pairFor(path[0], path[1]), amounts[0]
    //     );
    //     _swap(amounts, path, address(this));
    //     IWHT(WHT).withdraw(amounts[amounts.length - 1]);
    //     TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    // }

    // function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    // external
    // virtual
    // override
    // payable
    // ensure(deadline)
    // returns (uint[] memory amounts)
    // {
    //     console.log('swapETHForExactTokens ....');
    //     require(path[0] == WHT, 'MdexRouter: INVALID_PATH');
    //     amounts = IMdexFactory(factory).getAmountsIn(amountOut, path);
    //     require(amounts[0] <= msg.value, 'MdexRouter: EXCESSIVE_INPUT_AMOUNT');
    //     IWHT(WHT).deposit{value : amounts[0]}();
    //     assert(IWHT(WHT).transfer(pairFor(path[0], path[1]), amounts[0]));
    //     _swap(amounts, path, to);
    //     // refund dust eth, if any
    //     if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    // }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = IMdexFactory(factory).sortTokens(input, output);
            IMdexPair pair = IMdexPair(pairFor(input, output));
            uint amountInput;
            uint amountOutput;
            {// scope to avoid stack too deep errors
                (uint reserve0, uint reserve1,) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = IMdexFactory(factory).getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            if (swapMining != address(0)) {
                ISwapMining(swapMining).swap(msg.sender, input, output, amountOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? pairFor(output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'MdexRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
    external
    virtual
    override
    payable
    ensure(deadline)
    {
        require(path[0] == WHT, 'MdexRouter: INVALID_PATH');
        uint amountIn = msg.value;
        IWHT(WHT).deposit{value : amountIn}();
        assert(IWHT(WHT).transfer(pairFor(path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'MdexRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
    external
    virtual
    override
    ensure(deadline)
    {
        require(path[path.length - 1] == WHT, 'MdexRouter: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WHT).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'MdexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWHT(WHT).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public view override returns (uint256 amountB) {
        return IMdexFactory(factory).quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view override returns (uint256 amountOut){
        return IMdexFactory(factory).getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public view override returns (uint256 amountIn){
        return IMdexFactory(factory).getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path) public view override returns (uint256[] memory amounts){
        return IMdexFactory(factory).getAmountsOut(amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path) public view override returns (uint256[] memory amounts){
        return IMdexFactory(factory).getAmountsIn(amountOut, path);
    }

}


// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value : value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}
