// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./UniERC20.sol";
import "./IWETH.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./Address.sol";
import "./RevertReasonParser.sol";
import "./IUniswapV2Factory.sol";

import "hardhat/console.sol";

interface IERC20Permit {
    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}


contract Permitable {
    event Error(
        string reason
    );

    function _permit(IERC20 token, uint256 amount, bytes calldata permit) internal {
        if (permit.length == 32 * 7) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory result) = address(token).call(abi.encodePacked(IERC20Permit.permit.selector, permit));
            if (!success) {
                string memory reason = RevertReasonParser.parse(result, "Permit call failed: ");
                if (token.allowance(msg.sender, address(this)) < amount) {
                    revert(reason);
                } else {
                    emit Error(reason);
                }
            }
        }
    }
}

contract UnoswapRouter is Permitable {
    using SafeMath for uint;

    uint256 private constant _TRANSFER_FROM_CALL_SELECTOR_32 = 0x23b872dd00000000000000000000000000000000000000000000000000000000;
    uint256 private constant _WETH_DEPOSIT_CALL_SELECTOR_32 = 0xd0e30db000000000000000000000000000000000000000000000000000000000;
    uint256 private constant _WETH_WITHDRAW_CALL_SELECTOR_32 = 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000;
    uint256 private constant _ERC20_TRANSFER_CALL_SELECTOR_32 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000;
    uint256 private constant _ADDRESS_MASK =   0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant _REVERSE_MASK =   0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant _WETH_MASK =      0x4000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant _NUMERATOR_MASK = 0x0000000000000000ffffffff0000000000000000000000000000000000000000;
    uint256 private _WETH =           0x000000000000000000000000C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 private constant _UNISWAP_PAIR_RESERVES_CALL_SELECTOR_32 = 0x0902f1ac00000000000000000000000000000000000000000000000000000000;
    uint256 private constant _UNISWAP_PAIR_SWAP_CALL_SELECTOR_32 = 0x022c0d9f00000000000000000000000000000000000000000000000000000000;
    uint256 private constant _DENOMINATOR = 1000000;
    uint256 private constant _NUMERATOR_OFFSET = 160;

    receive() external payable {
        // solhint-disable-next-line avoid-tx-origin
        require(msg.sender != tx.origin, "ETH deposit rejected");
    }

    constructor(address _weth) public {
        _WETH = uint(_weth);
    }

    function unoswapWithPermit(
        IERC20 srcToken,
        uint256 amount,
        uint256 minReturn,
        bytes32[] calldata pools,
        bytes calldata permit
    ) external payable returns(uint256 returnAmount) {
        _permit(srcToken, amount, permit);
        return _doSwap(address(srcToken), amount, minReturn, pools);
    }

    struct SwapParm {
        address srcToken;
        uint routers;
        uint returnAmt;
        uint[] amts;
        uint[] outAmts;
        uint[] minOutAmts;
        uint[] flags;
        bytes32[][] pools;
    }

    // 同时调用多个交易所兑换
    function unoswapAll(bytes calldata data) public payable returns(uint256 returnAmount) {
        SwapParm memory param = abi.decode(data, (SwapParm));
            console.log("srcToken: ", param.srcToken);
            console.log("routers: ", param.routers);
            console.log("returnAmt: ", param.returnAmt);
            for (uint i = 0; i < param.routers; i ++) {
                console.log("amts[%d]: ", i, param.amts[i]);
                console.log("outAmts[%d]: ", i, param.outAmts[i]);
                console.log("minOutAmts[%d]: ", i, param.minOutAmts[i]);
                console.log("flags[%d]: ", i, param.flags[i]);
                bytes32[] memory pool = param.pools[i];
                for (uint j = 0; j < pool.length; j ++) {
                    console.log( j, uint(pool[j]));
                }
            }
        // uint[] memory amtOut;
        for (uint i = 0; i < param.routers; i ++) {
            uint flag = param.flags[i];

            // todo 
            // bytes32[] calldata pools = new bytes32[](param.pools.length);

            uint amtOut = _doSwap((param.srcToken), param.amts[i], param.minOutAmts[i], param.pools[i]);
            returnAmount += amtOut;
        }
        console.log("param.ret: real ret: ", param.returnAmt, returnAmount);
        // return;
    }

    function _swap(address pair, address dst, uint amt, uint feeRate, bool reversed) private returns (uint ret) {
        (uint r0, uint r1) = IUniswapV2Pair(pair).getReserves();
        if (reversed) {
            uint tmp = r0;
            r0 = r1;
            r1 = tmp;
        }
        uint amtIn = amt.mul(feeRate);
        ret = amtIn.mul(r1).div(amtIn + r0 * _DENOMINATOR);

        console.log("amtIn: %d feeRate: %d amtOut: %d", amt, feeRate, ret);
        if (reversed) {
            IUniswapV2Pair(pair).swap(ret, 0, dst, new bytes(0));
        } else {
            IUniswapV2Pair(pair).swap(0, ret, dst, new bytes(0));
        }
    }

    function _doSwap(address srcToken, uint amt, uint minOutAmt, bytes32[] memory datas) private returns (uint ret) {
        address pair = address(uint256(datas[0]) & _ADDRESS_MASK);
        uint data;
        uint feeRate;
        bool reversed;

        // address srcReal;
        if (srcToken == address(0)) {
            IWETH(_WETH).deposit{value: amt}();
            IERC20(_WETH).transfer(pair, amt);
            // srcReal = _WETH;
        } else {
            TransferHelper.safeTransferFrom(srcToken, msg.sender, pair, amt);
            // srcReal = srcToken;
        }

        ret = amt;
        for (uint i = 0; i < datas.length - 1; i ++) {
            data = uint((datas[i]));
            reversed = (data & _REVERSE_MASK) != 0;
            feeRate = (data & _NUMERATOR_MASK) >> 160;
            address nextPair = address(uint(datas[i+1]) & _ADDRESS_MASK);

            ret = _swap(pair, nextPair, ret, feeRate, reversed);
            pair = nextPair;
        }

        data = uint(datas[datas.length - 1]);
        reversed = (data & _REVERSE_MASK) != 0;
        feeRate = (data & _NUMERATOR_MASK) >> 160;
        pair = address(data & _ADDRESS_MASK);
        bool wethOut = (data & _WETH_MASK) != 0;
        // last
        if (wethOut) {
            ret = _swap(pair, address(this), ret, feeRate, reversed);
            require(ret >= minOutAmt, "not enough weth out");
            IWETH(_WETH).withdraw(ret);
            TransferHelper.safeTransferETH(msg.sender, ret);
        } else {
            console.log("amtIn:", ret);
            ret = _swap(pair, msg.sender, ret, feeRate, reversed);
            console.log(pair, ret, minOutAmt);
            require(ret >= minOutAmt, "not enough out");
        }
    }
    /*
    function unoswap(
        IERC20 srcToken,
        uint256 amount,     // 输入
        uint256 minReturn,
        bytes32[] calldata // pools
    ) public payable returns(uint256 returnAmount) {
        assembly {  // solhint-disable-line no-inline-assembly
            function reRevert() {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            function revertWithReason(m, len) {
                mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x20, 0x0000002000000000000000000000000000000000000000000000000000000000)
                mstore(0x40, m)
                revert(0, len)
            }

            function swap(emptyPtr, swapAmount, pair, reversed, numerator, dst) -> ret {
                mstore(emptyPtr, _UNISWAP_PAIR_RESERVES_CALL_SELECTOR_32)
                if iszero(staticcall(gas(), pair, emptyPtr, 0x4, emptyPtr, 0x40)) {
                    reRevert()
                }

                let reserve0 := mload(emptyPtr)
                let reserve1 := mload(add(emptyPtr, 0x20))
                if reversed {
                    let tmp := reserve0
                    reserve0 := reserve1
                    reserve1 := tmp
                }
                ret := mul(swapAmount, numerator)
                ret := div(mul(ret, reserve1), add(ret, mul(reserve0, _DENOMINATOR)))

                mstore(emptyPtr, _UNISWAP_PAIR_SWAP_CALL_SELECTOR_32)
                switch reversed
                case 0 {
                    mstore(add(emptyPtr, 0x04), 0)
                    mstore(add(emptyPtr, 0x24), ret)
                }
                default {
                    mstore(add(emptyPtr, 0x04), ret)
                    mstore(add(emptyPtr, 0x24), 0)
                }
                mstore(add(emptyPtr, 0x44), dst)
                mstore(add(emptyPtr, 0x64), 0x80)
                mstore(add(emptyPtr, 0x84), 0)
                if iszero(call(gas(), pair, 0, emptyPtr, 0xa4, 0, 0)) {
                    reRevert()
                }
            }

            let emptyPtr := mload(0x40)
            mstore(0x40, add(emptyPtr, 0xc0))

            let poolsOffset := add(calldataload(0x64), 0x4)   // 0x64 地址保存的是 pool end offset 的偏移，例如 0x80
            let poolsEndOffset := calldataload(poolsOffset)   // 多少个 pool
            poolsOffset := add(poolsOffset, 0x20)             // pair 地址
            poolsEndOffset := add(poolsOffset, mul(0x20, poolsEndOffset))
            let rawPair := calldataload(poolsOffset)
            switch srcToken
            case 0 {
                if iszero(eq(amount, callvalue())) {
                    revertWithReason(0x00000011696e76616c6964206d73672e76616c75650000000000000000000000, 0x55)  // "invalid msg.value"
                }

                mstore(emptyPtr, _WETH_DEPOSIT_CALL_SELECTOR_32)
                if iszero(call(gas(), _WETH, amount, emptyPtr, 0x4, 0, 0)) {
                    reRevert()
                }

                mstore(emptyPtr, _ERC20_TRANSFER_CALL_SELECTOR_32)
                mstore(add(emptyPtr, 0x4), and(rawPair, _ADDRESS_MASK))
                mstore(add(emptyPtr, 0x24), amount)
                if iszero(call(gas(), _WETH, 0, emptyPtr, 0x44, 0, 0)) {
                    reRevert()
                }
            }
            default {
                if callvalue() {
                    revertWithReason(0x00000011696e76616c6964206d73672e76616c75650000000000000000000000, 0x55)  // "invalid msg.value"
                }

                mstore(emptyPtr, _TRANSFER_FROM_CALL_SELECTOR_32)
                mstore(add(emptyPtr, 0x4), caller())
                mstore(add(emptyPtr, 0x24), and(rawPair, _ADDRESS_MASK))
                mstore(add(emptyPtr, 0x44), amount)
                if iszero(call(gas(), srcToken, 0, emptyPtr, 0x64, 0, 0)) {
                    reRevert()
                }
            }

            returnAmount := amount

            for {let i := add(poolsOffset, 0x20)} lt(i, poolsEndOffset) {i := add(i, 0x20)} {
                let nextRawPair := calldataload(i)

                returnAmount := swap(
                    emptyPtr,
                    returnAmount,
                    and(rawPair, _ADDRESS_MASK),
                    and(rawPair, _REVERSE_MASK),
                    shr(_NUMERATOR_OFFSET, and(rawPair, _NUMERATOR_MASK)),
                    and(nextRawPair, _ADDRESS_MASK)
                )

                rawPair := nextRawPair
            }

            switch and(rawPair, _WETH_MASK)
            case 0 {
                returnAmount := swap(
                    emptyPtr,
                    returnAmount,
                    and(rawPair, _ADDRESS_MASK),
                    and(rawPair, _REVERSE_MASK),
                    shr(_NUMERATOR_OFFSET, and(rawPair, _NUMERATOR_MASK)),
                    caller()
                )
            }
            default {
                returnAmount := swap(
                    emptyPtr,
                    returnAmount,
                    and(rawPair, _ADDRESS_MASK),
                    and(rawPair, _REVERSE_MASK),
                    shr(_NUMERATOR_OFFSET, and(rawPair, _NUMERATOR_MASK)),
                    address()
                )

                mstore(emptyPtr, _WETH_WITHDRAW_CALL_SELECTOR_32)
                mstore(add(emptyPtr, 0x04), returnAmount)
                if iszero(call(gas(), _WETH, 0, emptyPtr, 0x24, 0, 0)) {
                    reRevert()
                }

                if iszero(call(gas(), caller(), returnAmount, 0, 0, 0, 0)) {
                    reRevert()
                }
            }

            if lt(returnAmount, minReturn) {
                revertWithReason(0x000000164d696e2072657475726e206e6f742072656163686564000000000000, 0x5a)  // "Min return not reached"
            }
        }
    }
    */
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
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}
