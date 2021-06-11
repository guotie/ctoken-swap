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

import "./PriceOracle.sol";
import "./LErc20.sol";

contract SimplePriceOracle is PriceOracle {
    mapping(address => uint) prices;
    uint baseTokenPrice;
    string public baseSymbol;

    address admin;
    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);

    constructor(string memory symbol) public {
        admin = msg.sender;
        baseSymbol = symbol;
    }

    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        if (compareStrings(cToken.symbol(), baseSymbol)) {
            return baseTokenPrice;
        } else {
            return prices[address(LErc20(address(cToken)).underlying())];
        }
    }

    function setUnderlyingPrice(CToken cToken, uint underlyingPriceMantissa) public {
        require(msg.sender == admin, "only the admin may call setUnderlyingPrice");
        if (compareStrings(cToken.symbol(), baseSymbol)) {
            baseTokenPrice = underlyingPriceMantissa;
        } else {
            address asset = address(LErc20(address(cToken)).underlying());
            emit PricePosted(asset, prices[asset], underlyingPriceMantissa, underlyingPriceMantissa);
            prices[asset] = underlyingPriceMantissa;
        }
    }

    function setDirectPrice(address asset, uint price) public {
        require(msg.sender == admin, "only the admin may call setDirectPrice");
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    function changeAdmin(address newAdmin) public {
        require(msg.sender == admin, "only the admin may call changeAdmin");
        admin = newAdmin;
    }

    // v1 price oracle interface for use as backing of proxy
    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function setSymbol(string memory symbol) public {
        require(msg.sender == admin, "only the admin may call changeAdmin");
        baseSymbol = symbol;
    }
}

