// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import {IERC20 as SIERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IEbe is SIERC20 {
    function mint(address to, uint256 amount) external returns (bool);
}
