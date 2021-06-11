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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


abstract contract ICompound {
    function markets(address cToken)
        external
        view
        virtual
        returns (bool isListed, uint256 collateralFactorMantissa);
}


abstract contract ICompoundToken is IERC20 {
    function underlying() external view virtual returns (address);

    function exchangeRateStored() external view virtual returns (uint256);

    function mint(uint256 mintAmount) external virtual returns (uint256);

    function redeem(uint256 redeemTokens) external virtual returns (uint256);
}


abstract contract ICompoundEther is IERC20 {
    function mint() external payable virtual;

    function redeem(uint256 redeemTokens) external virtual returns (uint256);
}
