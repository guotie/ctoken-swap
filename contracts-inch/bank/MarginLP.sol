// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../common/libraries/SafeToken.sol";
import "../common/CTokenInterfaces.sol";
import "../common/LErc20DelegatorInterface.sol";
import "./Goblin.sol";

// 杠杆流动性挖矿

contract MarginLP is Ownable, ReentrancyGuard {
    using SafeToken for address;
    using SafeMath for uint256;

    event OpPosition(uint256 indexed id, uint256 debt, uint back);
    event Liquidate(uint256 indexed id, address indexed killer, uint256 prize, uint256 left);

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
      // address token0;
      // address token1;
      // address ctoken0;
      // address ctoken1;
      // address borrowToken;  // 借出的 token
      // address pair;         // 兼容 uniswap IPair 接口
      uint256 productionId;
      uint256 debtShare;
    }

    uint256 public liquidateBps; // 清算奖励
    address public comptroller;   // comptroller
    address public compFactory;   // LErc20DelegatorFactory
    address public lht; // lht address
    
    mapping(uint256 => Production) public productions;
    uint256 public currentPid = 1;

    mapping(uint256 => Position) public positions;
    uint256 public currentPos = 1;

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "not eoa");
        _;
    }

    constructor(address _comptroller, address _compFactory, address _lht) {
        comptroller = _comptroller;
        compFactory = _compFactory;
        lht = _lht;
    }


    function debtShareToVal(address token, uint256 debtShare) public view returns (uint256) {
      return 0;
        // TokenBank storage bank = banks[token];
        // require(bank.isOpen, 'token not exists');

        // if (bank.totalDebtShare == 0) return debtShare;
        // return debtShare.mul(bank.totalDebt).div(bank.totalDebtShare);
    }

    function debtValToShare(address token, uint256 debtVal) public view returns (uint256) {
      return 0;
        // TokenBank storage bank = banks[token];
        // require(bank.isOpen, 'token not exists');

        // if (bank.totalDebt == 0) return debtVal;
        // return debtVal.mul(bank.totalDebtShare).div(bank.totalDebt);
    }

    // 开仓借款
    // 加仓借款
    // borrow: 借款
    // 质押: 转入的token0金额 + 借贷token1 => 得到的 LP
    function opPosition(uint256 posId, uint256 pid, uint256 borrow, bytes calldata data) external payable onlyEOA nonReentrant {
      if (posId == 0) {
          posId = currentPos;
          currentPos ++;
          positions[posId].owner = msg.sender;
          positions[posId].productionId = pid;
      } else {
          require(posId < currentPos, "bad position id");
          require(positions[posId].owner == msg.sender, "not position owner");

          pid = positions[posId].productionId;
      }

      // 1. 解除原来的 债务 (加仓的情况)
      // 2. 借出资金 cotken 需要开新的接口
      // uint ret = borrowToken.borrow(borrow);
      // require(ret == 0, "borrow failed");
      // 3. 提供流动性
      // 4. 计算债务
        require(pid < currentPid, "pid exceeds");
        Production memory production = productions[pid];
        require(production.isOpen, 'Production not open');

        require(borrow == 0 || production.canBorrow, "Production can not borrow");

        // 更新计算利息
        // calInterest(production.borrowToken);
        CTokenInterface(production.borrowToken).accrueInterest();
        if (borrow > 0) {
            // 从lend池中借出 token, 成功的话 将币转到 this
            CErc20Interface(production.borrowCtoken).borrowLPMargin(msg.sender, borrow);
        }
        // 上面已经更新过利率, 这里可以直接使用 borrowBalanceStored todo 改成margin
        uint debt = CTokenInterface(production.borrowCtoken).borrowBalanceStored(msg.sender);
        // uint256 debt = _removeDebt(positions[posId], production).add(borrow); // 更新 pos 债务 debt
        bool isBorrowHt = production.borrowToken == address(0);

        uint256 sendHT = msg.value;
        uint256 beforeToken = 0;
        if (isBorrowHt) {
            // 为什么要加 borrow ???
            // borrow 是这个用户要借的数量 以ht借ht的情况
            sendHT = sendHT.add(borrow);
            // require(sendHT <= address(this).balance && debt <= banks[production.borrowToken].totalVal, "insufficient HT in the bank");
            beforeToken = address(this).balance.sub(sendHT);
        } else {
            beforeToken = SafeToken.myBalance(production.borrowToken);
            // require(borrow <= beforeToken && debt <= banks[production.borrowToken].totalVal, "insufficient borrowToken in the bank");
            beforeToken = beforeToken.sub(borrow);
            // goblin 需要从这个地址转账过去, 因此需要approve。 HT直接发送过去的，因此不需要approve
            SafeToken.safeApprove(production.borrowCtoken, production.goblin, borrow);
        }

        Goblin(production.goblin).work(value, sendHT)(posId, msg.sender, production.borrowToken, borrow, debt, data);

        uint256 backToken = isBorrowHt? (address(this).balance.sub(beforeToken)) :
            SafeToken.myBalance(production.borrowToken).sub(beforeToken);

        if(backToken > debt) { //没有借款, 有剩余退款
            backToken = backToken.sub(debt);
            debt = 0;

            isBorrowHt? SafeToken.safeTransferETH(msg.sender, backToken):
                SafeToken.safeTransfer(production.borrowToken, msg.sender, backToken);

        } else if (debt > backToken) { //有借款
            debt = debt.sub(backToken);
            backToken = 0;

            require(debt >= production.minDebt, "too small debt size");
            uint256 health = Goblin(production.goblin).health(posId, production.borrowToken);
            require(health.mul(production.openFactor) >= debt.mul(10000), "bad work factor");

            // _addDebt(positions[posId], production, debt);
        }
        emit OpPosition(posId, debt, backToken);
    }

    // 减仓
    // 清仓 根据传入的 data 不同
    function closePosition(uint256 posId, uint lpAmount) external onlyEOA nonReentrant {
      require(positions[posId].owner == msg.sender, "not position owner");
    }

    // 清算
    function liquidate(uint256 posId) external payable onlyEOA nonReentrant {
        Position storage pos = positions[posId];
        // require(pos.debtShare > 0, "no debt");
        Production storage production = productions[pos.productionId];

        // 更新利率
        CTokenInterface(production.borrowToken).accrueInterest();
        // 借款数量
        uint256 debt = CTokenInterface(production.borrowCtoken).borrowBalanceStored(pos.owner); // _removeDebt(pos, production);

        uint256 health = Goblin(production.goblin).health(posId, production.borrowToken);
        require(health.mul(production.liquidateFactor) < debt.mul(10000), "can't liquidate");

        bool isHT = production.borrowToken == address(0);
        uint256 before = isHT? address(this).balance: SafeToken.myBalance(production.borrowToken);

        Goblin(production.goblin).liquidate(posId, pos.owner, production.borrowToken);

        uint256 back = isHT? address(this).balance: SafeToken.myBalance(production.borrowToken);
        back = back.sub(before);

        uint256 prize = back.mul(liquidateBps).div(10000);
        uint256 rest = back.sub(prize);
        uint256 left = 0;

        if (prize > 0) {
            isHT? SafeToken.safeTransferETH(msg.sender, prize): SafeToken.safeTransfer(production.borrowToken, msg.sender, prize);
        }
        if (rest > debt) {
            left = rest.sub(debt);
            isHT? SafeToken.safeTransferETH(pos.owner, left): SafeToken.safeTransfer(production.borrowToken, pos.owner, left);
        } else {
            // todo 国库亏损 计提
            // banks[production.borrowToken].totalVal = banks[production.borrowToken].totalVal.sub(debt).add(rest);
        }
        emit Liquidate(posId, msg.sender, prize, left);
    }


    // function _addDebt(Position storage pos, Production storage production, uint256 debtVal) internal {
    //     if (debtVal == 0) {
    //         return;
    //     }

    //     TokenBank storage bank = banks[production.borrowToken];

    //     uint256 debtShare = debtValToShare(production.borrowToken, debtVal);
    //     pos.debtShare = pos.debtShare.add(debtShare);

    //     bank.totalVal = bank.totalVal.sub(debtVal);
    //     bank.totalDebtShare = bank.totalDebtShare.add(debtShare);
    //     bank.totalDebt = bank.totalDebt.add(debtVal);
    // }

    // 根据 pos 账户的 debtShare 计算出 debt, 更新 bank 的 totalVal totalDebtShare totalDebt
    // function _removeDebt(Position storage pos, Production storage production) internal returns (uint256) {
    //     TokenBank storage bank = banks[production.borrowToken];

    //     uint256 debtShare = pos.debtShare;
    //     if (debtShare > 0) {
    //         uint256 debtVal = debtShareToVal(production.borrowToken, debtShare);
    //         pos.debtShare = 0;

    //         bank.totalVal = bank.totalVal.add(debtVal);
    //         bank.totalDebtShare = bank.totalDebtShare.sub(debtShare);
    //         bank.totalDebt = bank.totalDebt.sub(debtVal);
    //         return debtVal;
    //     } else {
    //         return 0;
    //     }
    // }

    function opProduction(uint256 pid, bool isOpen, bool canBorrow,
        address coinToken, address currencyToken, address borrowToken, address goblin,
        uint256 minDebt, uint256 openFactor, uint256 liquidateFactor) external onlyOwner {

        if(pid == 0){
            pid = currentPid;
            currentPid ++;
        } else {
            require(pid < currentPid, "bad production id");
        }

        Production storage production = productions[pid];
        production.isOpen = isOpen;
        production.canBorrow = canBorrow;
        // 地址一旦设置, 就不要再改, 可以添加新币对!
        production.coinToken = coinToken;
        production.currencyToken = currencyToken;
        production.borrowToken = borrowToken;
        if (borrowToken == address(0)) {
            production.borrowCtoken = lht; // address(LHT);
        } else {
            production.borrowCtoken = LErc20DelegatorInterface(compFactory).getCTokenAddressPure(borrowToken);
        }
        production.goblin = goblin;

        production.minDebt = minDebt;
        production.openFactor = openFactor;
        production.liquidateFactor = liquidateFactor;
    }
}
