// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./SafeERC20.sol";
import "./Address.sol";
import "./SafeERC20.sol";

import "./UnoswapRouter.sol";

interface IChi is IERC20 {
    function mint(uint256 value) external;
    function free(uint256 value) external returns (uint256 freed);
    function freeFromUpTo(address from, uint256 value) external returns (uint256 freed);
}


interface IGasDiscountExtension {
    function calculateGas(uint256 gasUsed, uint256 flags, uint256 calldataLength) external view returns (IChi, uint256);
}

interface IAggregationExecutor is IGasDiscountExtension {
    function callBytes(bytes calldata data) external payable;  // 0xd9c45357
}

contract AggregationRouterV3 is Ownable, UnoswapRouter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using UniERC20 for IERC20;

    uint256 private constant _PARTIAL_FILL = 0x01;
    uint256 private constant _REQUIRES_EXTRA_ETH = 0x02;
    uint256 private constant _SHOULD_CLAIM = 0x04;
    uint256 private constant _BURN_FROM_MSG_SENDER = 0x08;
    uint256 private constant _BURN_FROM_TX_ORIGIN = 0x10;

    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address srcReceiver;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    event Swapped(
        address sender,
        IERC20 srcToken,
        IERC20 dstToken,
        address dstReceiver,
        uint256 spentAmount,
        uint256 returnAmount
    );

    constructor(address _weth, address _ctokenFactory, address _ob) UnoswapRouter(_weth, _ctokenFactory, _ob) public {
        // _WETH = uint(_weth);
    }

    function discountedSwap(
        IAggregationExecutor caller,
        SwapDescription calldata desc,    // 必须 pragma experimental ABIEncoderV2
        bytes calldata data
    )
        external
        payable
        returns (uint256 returnAmount, uint256 gasLeft, uint256 chiSpent)
    {
        uint256 initialGas = gasleft();

        address chiSource = address(0);
        if (desc.flags & _BURN_FROM_MSG_SENDER != 0) {
            chiSource = msg.sender;
        } else if (desc.flags & _BURN_FROM_TX_ORIGIN != 0) {
            chiSource = tx.origin; // solhint-disable-line avoid-tx-origin
        } else {
            revert("Incorrect CHI burn flags");
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = address(this).delegatecall(abi.encodeWithSelector(this.swap.selector, caller, desc, data));
        if (success) {
            (returnAmount,) = abi.decode(returnData, (uint256, uint256));
        } else {
            if (msg.value > 0) {
                msg.sender.transfer(msg.value);
            }
            emit Error(RevertReasonParser.parse(returnData, "Swap failed: "));
        }

        (IChi chi, uint256 amount) = caller.calculateGas(initialGas.sub(gasleft()), desc.flags, msg.data.length);
        if (amount > 0) {
            chiSpent = chi.freeFromUpTo(chiSource, amount);
        }
        gasLeft = gasleft();
    }

    function swap(
        IAggregationExecutor caller,
        SwapDescription calldata desc,
        bytes calldata data
    )
        external
        payable
        returns (uint256 returnAmount, uint256 gasLeft)
    {
        require(desc.minReturnAmount > 0, "Min return should not be 0");
        require(data.length > 0, "data should be not zero");

        uint256 flags = desc.flags;
        IERC20 srcToken = desc.srcToken;
        IERC20 dstToken = desc.dstToken;

        if (flags & _REQUIRES_EXTRA_ETH != 0) {
            require(msg.value > (srcToken.isETH() ? desc.amount : 0), "Invalid msg.value");
        } else {
            require(msg.value == (srcToken.isETH() ? desc.amount : 0), "Invalid msg.value");
        }

        if (flags & _SHOULD_CLAIM != 0) {
            require(!srcToken.isETH(), "Claim token is ETH");
            _permit(srcToken, desc.amount, desc.permit);
            srcToken.safeTransferFrom(msg.sender, desc.srcReceiver, desc.amount);
        }

        address dstReceiver = (desc.dstReceiver == address(0)) ? msg.sender : desc.dstReceiver;
        uint256 initialSrcBalance = (flags & _PARTIAL_FILL != 0) ? srcToken.uniBalanceOf(msg.sender) : 0;
        uint256 initialDstBalance = dstToken.uniBalanceOf(dstReceiver);

        {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory result) = address(caller).call{value: msg.value}(abi.encodePacked(caller.callBytes.selector, data));
            if (!success) {
                revert(RevertReasonParser.parse(result, "callBytes failed: "));
            }
        }

        uint256 spentAmount = desc.amount;
        returnAmount = dstToken.uniBalanceOf(dstReceiver).sub(initialDstBalance);

        if (flags & _PARTIAL_FILL != 0) {
            spentAmount = initialSrcBalance.add(desc.amount).sub(srcToken.uniBalanceOf(msg.sender));
            require(returnAmount.mul(desc.amount) >= desc.minReturnAmount.mul(spentAmount), "Return amount is not enough");
        } else {
            require(returnAmount >= desc.minReturnAmount, "Return amount is not enough");
        }

        emit Swapped(
            msg.sender,
            srcToken,
            dstToken,
            dstReceiver,
            spentAmount,
            returnAmount
        );

        gasLeft = gasleft();
    }

    function rescueFunds(IERC20 token, uint256 amount) external onlyOwner {
        token.uniTransfer(msg.sender, amount);
    }

    function destroy() external onlyOwner {
        selfdestruct(msg.sender);
    }
}
