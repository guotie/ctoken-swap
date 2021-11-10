
interface IDeBankRouter {
    // 获取 factory 地址
    function factory() external view returns (address);

    // 获取 wht 地址
    function WHT() external view returns (address);

    // 所有交易对的累计手续费，以兑换为 anchorToken
    function allPairFee() external view returns (uint);

    // 所有交易对上一个块的手续费
    function allPairFeeLastBlock() external view returns (uint);

    function reward(uint256 blockNumber) external view returns (uint256);

    // 平台币合约地址
    function rewardToken() external view returns (address);

    // 废弃
    function lpDepositAddr() external view returns (address);
    
    // compound 合约地址 unitroller
    function compAddr() external view returns (address);

    // 开始挖矿的 block
    function startBlock() external view returns (uint);

    // 交易及挖矿合约地址
    function swapMining() external view returns (address);

    // 即将废弃
    function getBlockRewards(uint256 _lastRewardBlock) external view returns (uint256);

    // 添加/创建 ctoken/ctoken 的流动性，调用之前需要 approve
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    // 添加/创建 token/token 的流动性，调用之前需要 approve
    function addLiquidityUnderlying(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    // 添加/创建 eth/token 的流动性，调用之前需要 approve
    function addLiquidityETHUnderlying(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    // 移除交易对的流动性，得到  ctoken ctoken
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    // 移除交易对的流动性，得到  token token
    function removeLiquidityUnderlying(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    // 移除交易对的流动性，得到  eth token
    function removeLiquidityETHUnderlying(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHUnderlyingWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    // 兑换 ctoken/ctoken。输入确定，输出不低于 amountOutMin
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    // 兑换 ctoken/ctoken。输出确定，输入不高于 amountInMax
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    // 兑换 token/token。输入确定，输出不低于 amountOutMin
    function swapExactTokensForTokensUnderlying(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path, // ['0x....', '0x....', '0x...']
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    // 兑换 token/token。输出确定，输入不大于 amountInMax
    function swapTokensForExactTokensUnderlying(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    // 兑换 eth/token。输入eth确定，输出不低于 amountOutMin
    function swapExactETHForTokensUnderlying(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    // 兑换 token/eth。输出eth确定，输入不高于 amountInMax
    function swapTokensForExactETHUnderlying(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    // 兑换 token/eth。输入token确定，输出不低于 amountOutMin
    function swapExactTokensForETHUnderlying(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    // 兑换 eth/token。输出token确定，输入 eth 不高于 amountOut
    function swapETHForExactTokensUnderlying(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    // external
    // payable
    // returns (uint[] memory amounts);

    // function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    // external
    // returns (uint[] memory amounts);

    // function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    // external
    // returns (uint[] memory amounts);

    // function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    // external
    // payable
    // returns (uint[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external view returns (uint256 amountB);

    // function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountOut);

    // function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountIn);

    // 输入确定时，计算按照 path 的兑换顺序，能够兑换多少输出
    function getAmountsOut(uint256 amountIn, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    // 输出确定时，计算按照 path 的兑换顺序，需要多少输入
    function getAmountsIn(uint256 amountOut, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    // function removeLiquidityETHSupportingFeeOnTransferTokens(
    //     address token,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline
    // ) external returns (uint amountETH);

    // function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    //     address token,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline,
    //     bool approveMax, uint8 v, bytes32 r, bytes32 s
    // ) external returns (uint amountETH);

    // function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external;

    // function swapExactETHForTokensSupportingFeeOnTransferTokens(
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external payable;

    // function swapExactTokensForETHSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external;
}
