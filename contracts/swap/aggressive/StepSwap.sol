// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

// 分步骤 swap, 可能的步骤
// 0. despot ht
// 1. withdraw wht
// 2. mint token
// 3. mint ht
// 4. redeem token
// 5. redeem ht
// 6. uniswap v1
// 7. uniswap v2
// 8. curve stable
// 9. 
// 
//
// tokenIn的情况:
// 1. ht
// 2. token
// 3. ctoken
//
// tokenOut的情况:
// 1. ht
// 2. token
// 3. ctoken
// 4. cht
//
//
// uniswap 只需要提供 router 地址，router 合约有 factory 地址
// 
// exchange 的类型
// 1. uniswap v1
// 2. uniswap v2, direct by pair 直接使用pair交易
// 3. uniswap v2, 使用router交易, 因为mdex可以交易挖矿
// 4. 
//
import "./IStepSwap.sol";

contract StepSwap is BaseStepSwap {
    using SafeMath for uint;
    using SafeMath for uint256;

}
