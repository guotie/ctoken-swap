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
pragma experimental ABIEncoderV2;
// pragma abicoder v2;

import "../LErc20.sol";
import "../CToken.sol";
import "../PriceOracle.sol";
import "../EIP20Interface.sol";
import "../Governance/LendHub.sol";
import "../SimplePriceOracle.sol";

interface ComptrollerLensInterface {

    function compSpeeds(address) external view returns (uint);
    function compSupplyState(address) external view returns(uint224, uint32);
    function compBorrowState(address) external view returns(uint224, uint32);
    function compSupplierIndex(address, address) external view returns (uint);
    function compBorrowerIndex(address, address) external view returns (uint);

    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (CToken[] memory);
    function claimComp(address) external;
    function compAccrued(address) external view returns (uint);
    function getCompAddress() external view returns (address);
}

contract LendHubLensLHB is ExponentialNoError {
    struct CTokenLHBData {
        address cToken;
        uint supplyLHBAPY;
        uint borrowLHBAPY;
    }

    function cTokenLHBMetadata(CToken cToken) view public returns (CTokenLHBData memory) {
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
        uint speed = comptroller.compSpeeds(address(cToken));
        SimplePriceOracle priceOracle = SimplePriceOracle(address(comptroller.oracle()));
        uint lhbPrice = priceOracle.assetPrices(comptroller.getCompAddress());
        // 24位小数
        uint exchangeRateCurrent = cToken.exchangeRateStored();
        uint totalPrice = cToken.totalSupply() * exchangeRateCurrent * priceOracle.getUnderlyingPrice(cToken);
        uint supplyAPY = 1000000000000000000 * 1000000 * 10512000 * speed * lhbPrice / totalPrice;
        uint totalBorrowPrice = cToken.totalBorrows() * priceOracle.getUnderlyingPrice(cToken);
        uint borrowLHBAPY = 1000000 * 10512000 * speed * lhbPrice / totalBorrowPrice;

        return CTokenLHBData({
            cToken: address(cToken),
            supplyLHBAPY: supplyAPY,
            borrowLHBAPY: borrowLHBAPY
            });
    }

    function calcLHBAPYs(CToken[] memory cTokens) public view returns (CTokenLHBData[] memory)  {
        uint cTokenCount = cTokens.length;
        CTokenLHBData[] memory res = new CTokenLHBData[](cTokenCount);

        for (uint i = 0; i < cTokenCount; i++) {
            CToken cToken = cTokens[i];
            res[i] = cTokenLHBMetadata(cToken);
        }
        return res;
    }
}
