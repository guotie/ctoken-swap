// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;

// 杠杆交易
// 
// 1. 兑换时，给用户兑换 token 还是 ctoken ？
// 2. 用户收益: 贷款产生的挖矿收益，交易产生的挖矿收益
// 3. 贷款利率:
// 4. 兑换产生的收益或损失
//
contract MarginSwap {
  // 用户贷款额度保存在 ctoken 中
  
    struct Production {
      address coinToken;
      address currencyToken;
      address borrowToken;        // token
      address borrowCtoken;       // borrow token 对应的 ctoken
      bool isOpen;
      bool canBorrow;
      address goblin;
      uint256 minDebt;
      uint256 openFactor;
      uint256 liquidateFactor;
    }

    struct Position {
      address owner;
      uint256 productionId;
      uint256 debtShare;
    }


    // 假如 eth 价值 1000 美金, 用户用 1eth 为抵押, 3倍杠杆, 借出 300 usdt
    //    时刻             资产                                             负债
    // 0    Block      1eth + 3000usdt                               3000usdt(尚未产生利息)
    // 100  Block      1eth + 3000usdt + reward(贷款)                3000usdt + 利息
    // 
    struct PositionAsset {
      uint256 token0Amt;  // token0 amount
      uint256 token1Amt;  // token1 amount
      uint256 ctoken0Amt;
      uint256 ctoken1Amt;
      uint256 rewards;     // 平台币奖励: 交易产生 + 借贷产生
    }

    uint256 public liquidateBps; // 清算奖励
    address public comptroller;   // comptroller
    address public compFactory;   // LErc20DelegatorFactory
    address public lht; // lht address
    
    mapping(uint256 => Production) public productions;
    uint256 public currentPid = 1;

    // 每个地址 + 交易对一个仓位 逐仓模式
    mapping(uint256 => Position) public positions;

    // 用户资产
    mapping(uint => PositionAsset) public positionAssets;

  constructor() {

  }

  // 兑换
  function swap(uint posId, uint amount) public {
    posId;
    amount;
  }
}
