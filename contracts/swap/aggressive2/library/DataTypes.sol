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

    /// @dev 询价 计算最佳兑换路径的入参
    struct QuoteParams {
        address to;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 tokenPriceGWei;
        address fromAddress;
        address dstReceiver;
        address[] midTokens;  // should always be token
        SwapFlagMap flag;
    }

    struct UniswapRouterParam {
        uint256 amount;
        address contract;
        address to;
        address[] path;
    }

    struct UniswapPairParam {
        uint256 amount;
        address to;
        address[] pairs;
    }

    // struct 
    struct StepExecuteParams {
        uint256 flag;           // step execute flag 指示用哪种步骤去执行
        // bytes[] data;           /// decode by executor
        bytes data;
    }

    /// @dev 兑换 入参
    struct SwapParams {
        // address to;
        // address tokenIn;
        // address tokenOut;
        // uint256 amountIn;
        // uint256 amountOut;
        // uint256 tokenPriceGWei;
        // address fromAddress;
        // address dstReceiver;
        // address[] midTokens;  // should always be token
        // SwapFlagMap flag;
        SwapFlagMap flag;
        uint256 minAmt;
        StepExecuteParams[] steps;
    }

    /// @dev Exchange 交易所合约地址及交易所类型
    struct Exchange {
        uint exFlag;
        address contractAddr;
    }


    /// @dev 计算各个交易所的每个parts的return
    struct SwapDistributes {
        bool        ctokenIn;     // 卖出的币是否是 ctoken
        bool        ctokenOut;    // 买到的币是否是 ctoken
        address     to;           // 交易者地址
        uint256     parts;        // 交易量拆分为多少份
        uint256     rateIn;       // token in exchange rate
        uint256     rateOut;      // token out exchange rate
        uint[]      amounts;      // split into parts
        uint[]      cAmounts;     // mint to ctoken amounts
        address[]   midTokens;    // middle token list
        address[]   midCTokens;   // middle ctoken list
        address[][] paths;        // 由 midTokens 和 复杂度计算得到的所有 path 列表
        address[][] cpaths;       // 由 midCTokens 和 复杂度计算得到的所有 cpath 列表
        
        uint[]      gases;          // gas 费用估算
        uint[]      pathIdx;        // 使用的 path 序号
        uint[][]    distributes;    // 一级为交易路径, 二级为该交易路径的所有parts对应的return
        int256[][]  netDistributes; // distributes - gases
        Exchange[]  exchanges;
    }
}
