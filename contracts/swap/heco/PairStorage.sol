// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity ^0.5.16;

import "../interface/IDeBankPair.sol";

contract PairStorage is IDeBankPair {
    // uint public MIN_RAMP_TIME = 86400;
    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;

    address public factory;
    address public token0;
    address public token1;
    address public cToken0;              // 对应 token0 在 lend 池中的 cToken
    address public cToken1;              // 对应 token1 在 lend 池中的 cToken

    uint112 public reserve0;
    uint112 public reserve1;

    // uint256 public fee;
    // bool public isStable;                      // 是否是稳定币
    uint256 public feeRate = 30;        // 手续费千三, 万分之三十
    // mapping(address => uint) feeRateOf; // 设置特定账户的手续费

    uint32 internal blockTimestampLast; // uses single storage slot, accessible via getReserves

    // uint112 public vReserve0;           // 虚拟的 token0 数量, 因为实际上 token0 已经存入 ctoken 合约中
    // uint112 public vReserve1;           // 虚拟的 token1 数量, 因为实际上 token1 已经存入 ctoken 合约中
    uint256 public lpFeeRate;           // 每个交易对分给LP的手续费比例 0不分

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    string public constant name = 'LP Token';
    string public constant symbol = 'Dex';
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    bytes4 internal constant _SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    mapping(address => uint) public nonces;
    mapping(address => uint) public balanceOf;
    // mapping(address => uint) public mintOf;
    mapping(address => mapping(address => uint)) public allowance;

    // 挖矿权
    // 挖矿权与所有权(balanceOf) 分离. 当用户把LP转给compound抵押时, 挖矿权依然归用户
    struct LPReward {
        uint amount;            // LP amount
        uint pendingReward;     // 未付 reward
        uint rewardDebt;        // LP 挖矿 + ctoken 挖矿
        // uint pendingReward;     // 未付 reward
        // uint ctokenRewordDebt;  // 
    }
    // 只有 owner 可以 burn, 其他不可以 burn
    mapping(address => LPReward) public mintRewardOf;
    uint public accPerShare;
    // uint public rewards;
    uint public totalFee;
    uint public currentBlock;       // blockFee对应的块数
    uint public blockFee;           // 当前块的手续费, 下一个块的第一笔交易触发计算上个块的reward, 然后重新累计

    // ctoken 挖矿收益
    // mapping(address => uint) public ctokenMintDebt;
    uint public mintAccPerShare;
    uint public ctokenMintRewards;
    uint public ctokenRewordBlock; // 上一次更新的块数
    uint public mintRewardDebt;    // 给用户转挖矿收益不足的情况

    // struct OrderItem {
    //     address owner;
    //     uint price;
    //     uint amount;
    //     uint posId;    // 代持合约中杠杆用户的posId
    //   // 通过
    //   // uint next;
    //   // uint prev;
    //   // uint itemId;
    // }

    // 计算价格的乘数 price = token0 * priceRatio / token1, such as 1e30
    // uint public priceRatio = 1e30; 

    // uint public itemId;
    // mapping(uint => OrderItem) public buyOrders;
    // mapping(uint => OrderItem) public sellOrders;

    uint private _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1, 'DeBankSwap: LOCKED');
        _unlocked = 0;
        _;
        _unlocked = 1;
    }

    
}
