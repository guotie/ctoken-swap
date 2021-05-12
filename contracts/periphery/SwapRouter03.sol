// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "./UniswapV2Router02.sol";

contract SwapV2Router03 is UniswapV2Router02 {
  address public lerc20Factory;

  constructor(address _factory, address _WETH, address _lerc20Factory) UniswapV2Router02(_factory, _WETH) {
      // factory = _factory;
      // WETH = _WETH;
      lerc20Factory = _lerc20Factory;
  }
}