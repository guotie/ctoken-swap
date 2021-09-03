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
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";

interface IOrderBook {

}

// 挂单合约
contract MockMargin {
    IOrderBook public orderBook;

    constructor(address _addr) public {
        orderBook = IOrderBook(_addr);
    }

    function fulfilOrder(
                uint orderId,
                uint amtToTaken,
                address to,
                bool isToken,
                bool partialFill,
                bytes calldata data
            ) public {

    }

    function onFulfiled(address owner, address tokenOut, address tokenIn, uint fulfiled, uint amt) external {

    }

    function onCanceled(address owner, address token0, address token1, address tokenReturn, uint amt) external {

    }
}

