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
    uint256 public constant STEP_COMPOUND_MINT_CTOKEN  = 0x0000000003; // prettier-ignore
    uint256 public constant STEP_COMPOUND_MINT_CETH    = 0x0000000004; // prettier-ignore
    uint256 public constant STEP_COMPOUND_REDEEM_TOKEN = 0x0000000005; // prettier-ignore
    // uint256 public constant STEP_COMPOUND_REDEEM_ETH   = 0x0000000006; // prettier-ignore
    uint256 public constant STEP_AAVE_DEPOSIT_ATOKEN   = 0x0000000007; // prettier-ignore
    uint256 public constant STEP_AAVE_DEPOSIT_WETH     = 0x0000000008; // prettier-ignore
    uint256 public constant STEP_AAVE_WITHDRAW_TOKEN   = 0x0000000009; // prettier-ignore
    uint256 public constant STEP_AAVE_WITHDRAW_ETH     = 0x000000000a; // prettier-ignore

    // uint256 public constant STEP_UNISWAP_PAIR_SWAP              = 0x0000000100; // prettier-ignore
    uint256 public constant STEP_UNISWAP_ROUTER_TOKENS_TOKENS   = 0x000000011; // prettier-ignore
    uint256 public constant STEP_UNISWAP_ROUTER_ETH_TOKENS      = 0x000000012; // prettier-ignore
    uint256 public constant STEP_UNISWAP_ROUTER_TOKENS_ETH      = 0x000000013; // prettier-ignore
    uint256 public constant STEP_EBANK_ROUTER_CTOKENS_CTOKENS   = 0x000000014;  // prettier-ignore same to STEP_UNISWAP_ROUTER_TOKENS_TOKENS
    uint256 public constant STEP_EBANK_ROUTER_TOKENS_TOKENS     = 0x000000015;  // prettier-ignore underlying
    uint256 public constant STEP_EBANK_ROUTER_ETH_TOKENS        = 0x000000016;  // prettier-ignore underlying
    uint256 public constant STEP_EBANK_ROUTER_TOKENS_ETH        = 0x000000017;  // prettier-ignore underlying

    uint256 public constant REVERSE_SWAP_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 public constant ADDRESS_MASK      = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff; // prettier-ignore

    // todo slip, 16 bit, 分母: 10000
    struct SwapFlagMap {
        // bit 0-7 parts, 8 bit
        // bit 8-63: flag token in/out, 64 bit
        // bit 72-79 max main part, 8 bit
        // bit 80-81 complex level, 2 bit
        // bit 82    allow partial fill
        // bit 83    allow burnChi
        uint256 data;
    }

    /// @dev 询价 计算最佳兑换路径的入参
    // struct RoutePathParams {
    //     address tokenIn;
    //     address tokenOut;
    //     address[] midTokens;      // should always be token
    //     uint256 mainRoutes;           // distributeCounts
    //     uint256 complex;
    //     uint256 parts;
    //     bool allowPartial;
    //     bool allowBurnchi;
    // }

    /// @dev 询价 计算最佳兑换路径的入参
    struct QuoteParams {
        address to;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        address[] midTokens;      // should always be token
        uint256 mainRoutes;           // distributeCounts
        uint256 complex;
        uint256 parts;
        bool allowPartial;
        bool allowBurnchi;
        // uint256 routes;           // distributeCounts
        // uint256 tokenPriceGWei;
        // address fromAddress;
        // address dstReceiver;
        // address[] midTokens;      // should always be token
        // Exchange[]  exchanges;
        // address[][] paths;        // 由 midTokens 和 复杂度计算得到的所有 path 列表
        // address[][] cpaths;       // 由 midCTokens 和 复杂度计算得到的所有 cpath 列表
        // SwapFlagMap flag;
    }

    // swap reserves; exchange rates
    struct SwapReserveRates {
        bool isEToken;
        bool allowBurnchi;
        bool allEbank;                  // 是否全部都由 ebank 兑换
        uint256 ebankAmt;
        uint256 amountIn;
        uint256 swapRoutes;             // 最终经过多少个 route 来兑换
        address tokenIn;
        address tokenOut;
        address etokenIn;
        address etokenOut;
        uint256 routes;                 // distributeCounts 交易所数量 * 路径数量
        uint256 rateIn;
        uint256 rateOut;
        uint256[]  fees;
        Exchange[]  exchanges;
        address[][] paths;        // 由 midTokens 和 复杂度计算得到的所有 path 列表
        address[][] cpaths;       // 由 midCTokens 和 复杂度计算得到的所有 cpath 列表
        uint256[][][] reserves;     // [routes][path]
        uint256[] distributes;    // 各个 swap 路径分配的兑换数量, 对于 ebank 是 etoken 的数量， 其他 swap 是 token 数量
    }

    struct UniswapRouterParam {
        uint256 amount;
        address contractAddr;
        // address to;
        address[] path;
    }

    struct CompoundRedeemParam {
        uint256 amount;
        // address to;
        address ctoken;
    }

    struct UniswapPairParam {
        uint256 amount;
        address[] pairs;
    }

    // struct 
    struct StepExecuteParams {
        uint256 flag;           // step execute flag 指示用哪种步骤去执行
        bytes   data;           // abi.encode 后的参数
    }

    /// @dev 兑换 入参
    struct SwapParams {
        bool isEToken;      // 是否是etoken
        address tokenIn;    // 输入token/etoken地址
        address tokenOut;   // 输出token/etoken地址
        uint256 amountIn;   // 输入数量
        uint256 minAmt;     // 最小数量
        uint256 block;      // 计算结果的 block
        StepExecuteParams[] steps;  // 聚合交易的步骤参数
    }

    /// @dev Exchange 交易所合约地址及交易所类型
    struct Exchange {
        uint exFlag;              // 交易所类型
        address contractAddr;     // 交易所合约地址
    }


    /// @dev 计算各个交易所的每个parts的return
    // struct SwapDistributes {
    //     bool        isCtoken;     // 买入、卖出的币是否是 ctoken
    //     // bool     ctokenOut;    // 买到的币是否是 ctoken
    //     address     to;           // 交易者地址
    //     address     tokenIn;
    //     address     tokenOut;
    //     uint256     parts;        // 交易量拆分为多少份
    //     uint256     rateIn;       // token in exchange rate
    //     uint256     rateOut;      // token out exchange rate
    //     uint[]      amounts;      // split into parts
    //     uint[]      cAmounts;     // mint to ctoken amounts
    //     // address[]   midTokens;    // middle token list
    //     // address[]   midCTokens;   // middle ctoken list
    //     address[][] paths;        // 由 midTokens 和 复杂度计算得到的所有 path 列表
    //     address[][] cpaths;       // 由 midCTokens 和 复杂度计算得到的所有 cpath 列表

    //     uint[]      gases;          // gas 费用估算
    //     uint[]      pathIdx;        // 使用的 path 序号
    //     uint[][]    distributes;    // 一级为交易路径, 二级为该交易路径的所有parts对应的return
    //     int256[][]  netDistributes; // distributes - gases
    //     Exchange[]  exchanges;
    // }
}
