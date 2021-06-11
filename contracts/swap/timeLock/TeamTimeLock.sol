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

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';


contract TeamTimeLock {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint constant  public PERIOD = 30 days;
    uint constant  public CYCLE_TIMES = 24;
    uint public fixedQuantity;  // Monthly rewards are fixed
    uint public startTime;
    uint public delay;
    uint public cycle;      // cycle already received
    uint public hasReward;  // Rewards already withdrawn
    address public beneficiary;
    string public introduce;

    event WithDraw(address indexed operator, address indexed to, uint amount);

    constructor(
        address _beneficiary,
        address _token,
        uint _fixedQuantity,
        uint _startTime,
        uint _delay,
        string memory _introduce
    ) public {
        require(_beneficiary != address(0) && _token != address(0), "TimeLock: zero address");
        require(_fixedQuantity > 0, "TimeLock: fixedQuantity is zero");
        beneficiary = _beneficiary;
        token = IERC20(_token);
        fixedQuantity = _fixedQuantity;
        delay = _delay;
        startTime = _startTime.add(_delay);
        introduce = _introduce;
    }


    function getBalance() public view returns (uint) {
        return token.balanceOf(address(this));
    }

    function getReward() public view returns (uint) {
        // Has ended or not started
        if (cycle >= CYCLE_TIMES || block.timestamp <= startTime) {
            return 0;
        }
        uint pCycle = (block.timestamp.sub(startTime)).div(PERIOD);
        if (pCycle >= CYCLE_TIMES) {
            return token.balanceOf(address(this));
        }
        return pCycle.sub(cycle).mul(fixedQuantity);
    }

    function withDraw() external {
        uint reward = getReward();
        require(reward > 0, "TimeLock: no reward");
        uint pCycle = (block.timestamp.sub(startTime)).div(PERIOD);
        cycle = pCycle >= CYCLE_TIMES ? CYCLE_TIMES : pCycle;
        hasReward = hasReward.add(reward);
        token.safeTransfer(beneficiary, reward);
        emit WithDraw(msg.sender, beneficiary, reward);
    }

    // Update beneficiary address by the previous beneficiary.
    function setBeneficiary(address _newBeneficiary) public {
        require(msg.sender == beneficiary, "Not beneficiary");
        beneficiary = _newBeneficiary;
    }
}
