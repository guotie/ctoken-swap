// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

/**
 * @title DataTypes library
 * @author ebankex
 * @notice Provides data types and functions to perform step swap calculations
 * @dev DataTypes are used for aggressive swap within multi swap exchanges.
 **/

library DataTypes {
    // 步骤执行的动作类型
    uint256 public constant STEP_DEPOSIT_ETH           = 0x0000000001; // prettier-ignore
    uint256 public constant STEP_WITHDRAW_WETH         = 0x0000000002; // prettier-ignore
    uint256 public constant STEP_COMPOUND_MINT_CTOKEN  = 0x0000000004; // prettier-ignore
    uint256 public constant STEP_COMPOUND_MINT_CETH    = 0x0000000008; // prettier-ignore
    uint256 public constant STEP_COMPOUND_REDEEM_TOKEN = 0x0000000010; // prettier-ignore
    uint256 public constant STEP_COMPOUND_REDEEM_ETH   = 0x0000000020; // prettier-ignore
    uint256 public constant STEP_AAVE_DEPOSIT_ATOKEN   = 0x0000000040; // prettier-ignore
    uint256 public constant STEP_AAVE_DEPOSIT_WETH     = 0x0000000080; // prettier-ignore
    uint256 public constant STEP_AAVE_WITHDRAW_TOKEN   = 0x0000000100; // prettier-ignore
    uint256 public constant STEP_AAVE_WITHDRAW_ETH     = 0x0000000200; // prettier-ignore
    uint256 public constant STEP_UNISWAP_PAIR_SWAP     = 0x0000000400; // prettier-ignore
    uint256 public constant STEP_UNISWAP_ROUTER_SWAP   = 0x0000000800; // prettier-ignore

    struct SwapFlagMap {
        // bit 0-63: flag token in/out, 64 bit
        // bit 64-71 parts, 8 bit
        // bit 72-79 max main part, 8 bit
        // bit 80-81 complex level, 2 bit
        // bit 82    allow partial fill
        // bit 83    allow burnChi
        uint256 data;
    }

    /// @dev 计算最佳兑换路径的入参
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 gasLimit;
        uint256 gasPrice;
        address fromAddress;
        address dstReceiver;
        address[] midTokens;  // should always be token
        SwapFlagMap flag;
    }

    // struct 
    struct StepExecuteParams {
        uint256 flag;
        address contractAddr;   // 合约地址
        bytes[] data;           /// decode by executor
    }
}
