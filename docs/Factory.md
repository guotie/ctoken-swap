interface IDeBankFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    // 手续费分成的地址
    // 非手续费挖矿模式下，手续费一部分分给流动性提供者, 一部分分给 feeTo 地址；如果 feeTo 为 0, 全部分给流动性提供者
    // 手续费挖矿模式下, 手续费全部兑换为 anchorToken, 然后转给 feeTo
    function feeTo() external view returns (address);

    // 设置 router 合约地址
    function router() external view returns (address);

    // 
    function lpFeeRate() external view returns (uint256);

    // ctoken factory 地址
    function lErc20DelegatorFactory() external view returns (LErc20DelegatorInterface);

    // 稳定币 token 地址
    function anchorToken() external view returns (address);

    // 获取交易对地址
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    // 交易对地址
    function allPairs(uint) external view returns (address pair);

    // 交易对总数
    function allPairsLength() external view returns (uint);

    // 交易对不存在时, 创建交易对。提供流动性时会自动创建，不需要调用
    function createPair(address tokenA, address tokenB) external returns (address pair);

    // 设置手续费分成地址
    function setFeeTo(address) external;

    // 非手续费挖矿模式下, 设置手续费分成比例
    function setFeeToRate(uint256) external;

    // 设置手续费费率, 万分之n
    function setPairFeeRate(address pair, uint feeRate) external;

    // 设置手续费兑换的稳定币地址
    function setAnchorToken(address _token) external;

    // token 排序
    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    // 两个 token 的交易对地址
    function pairFor(address tokenA, address tokenB) external view returns (address pair);

    // LP池的token数量
    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);

    // 添加流动性时，计算另一个token所需要的数量
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    // function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountOut);

    // function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountIn);

    // 计算输入n个token时，能够兑换多少token
    function getAmountsOut(uint256 amountIn, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    // 计算当输出n个token时, 需要输入多少个token
    function getAmountsIn(uint256 amountOut, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    // function amountToCTokenAmt(address ctoken, uint amountIn) external view returns (uint cAmountIn);
    // function ctokenAmtToAmount(address ctoken, uint cAmountOut) external view returns (uint amountOut);


    // 添加流动性时，计算另一个token所需要的数量
    function getReservesFeeRate(address tokenA, address tokenB, address to) external view returns (uint reserveA, uint reserveB, uint feeRate, bool outAnchorToken);

    // 兑换时，给定输入时，计算输出的token数量
    function getAmountOutFeeRate(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountOut);

    // 兑换时，给定输出时，计算需要的输入token数量
    function getAmountInFeeRate(uint amountOut, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountIn);

    // 类似于 getAmountOutFeeRate
    function getAmountOutFeeRateAnchorToken(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountOut);

}
