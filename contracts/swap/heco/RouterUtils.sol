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

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "../library/SafeMath.sol";
import "../interface/IERC20.sol";
import "../interface/IDeBankFactory.sol";
import "../interface/IDeBankPair.sol";
import "../interface/IDeBankRouter.sol";
import "../interface/IWHT.sol";
import "../interface/LErc20DelegatorInterface.sol";
import "../interface/ICToken.sol";


import "hardhat/console.sol";

// swap 工具集

contract DeBankRouterUtils {

    address public factory;
    address public ctokenFactory;
    address public cWHT;

    constructor(address _factory, address _ctokenFactory, address _cWHT) public {
        factory = _factory;
        ctokenFactory = _ctokenFactory;
        cWHT = _cWHT;
    }

    // ctoken 流动性计算
    // underlying 流动性计算

    // ctoken swap 计算: 已知 amountIn 的情况下, 求 amountOut
    // ctoken swap 计算: 已知 amountOut 的情况下, 求 amountIn
    // underlying swap 计算: 已知 amountIn 的情况下, 求 amountOut
    // underlying swap 计算: 已知 amountOut 的情况下, 求 amountIn

    // orderbook 计算
}
