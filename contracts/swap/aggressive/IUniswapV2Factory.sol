// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./IUniswapV2Exchange.sol";


interface IUniswapV2Factory {
    function getPair(IERC20 tokenA, IERC20 tokenB) external view returns (IUniswapV2Exchange pair);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function getReserves() external view returns (uint reserveA, uint reserveB);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}