
pragma solidity ^0.6.12;

interface IDeBankFactory {
    function router() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    function pairFor(address tokenA, address tokenB) external view returns (address pair);

    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);

    function getAmountsOut(uint256 amountIn, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path, address to) external view returns (uint256[] memory amounts);

    // function amountToCTokenAmt(address ctoken, uint amountIn) external view returns (uint cAmountIn);
    // function ctokenAmtToAmount(address ctoken, uint cAmountOut) external view returns (uint amountOut);

    function setPairFeeRate(address pair, uint feeRate) external;

    function getReservesFeeRate(address tokenA, address tokenB, address to) 
                external view returns (uint reserveA, uint reserveB, uint feeRate, bool outAnchorToken);

    function getAmountOutFeeRate(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountOut);

    function getAmountOutFeeRateAnchorToken(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) external pure returns (uint amountOut);
}
