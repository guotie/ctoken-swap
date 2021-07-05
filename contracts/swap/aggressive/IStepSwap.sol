// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";

// BaseStepSwap 定义结构及存储
abstract contract BaseStepSwap is Ownable {
  address public wht;

  constructor(address _wht) public {
    wht = _wht;
  }
}

