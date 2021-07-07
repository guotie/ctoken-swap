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

import { DataTypes } from "./DataTypes.sol";

library OBPairConfig {
    uint constant internal MASK_MIN_AMOUNT = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff; // prettier-ignore
    uint constant internal MASK_FEE_MAKER  = 0xffffffffffffffff000000000000000000000000000000000000000000000000; // prettier-ignore
    uint constant internal MASK_FEE_TAKER  = 0x0000000000000000ffffffffffffffff00000000000000000000000000000000; // prettier-ignore
    uint constant internal FEE_DENOMINATOR = 10000;

    uint constant internal SHIFT_FEE_MAKER = 128;
    uint constant internal SHIFT_FEE_TAKER = 192;

    /**
    * @dev Gets the min amount of order book pair
    * @param self The order book pair configuration
    * @return The min amount
    **/
    function minAmount(DataTypes.OBPairConfigMap storage self) public view returns (uint256) {
        uint amt = self.data & MASK_MIN_AMOUNT;
        return amt == 0 ? 0 : amt - 1;
    }

    /**
    * @dev Gets the maker fee of order book pair
    * @param self The order book pair configuration
    * @return The maker fee
    **/
    function feeMaker(DataTypes.OBPairConfigMap storage self) public view returns (uint256) {
        uint fee = ((self.data & MASK_FEE_MAKER) >> SHIFT_FEE_MAKER);
        return fee == 0 ? 0 : fee - 1;
    }

    /**
    * @dev Gets the taker fee of order book pair
    * @param self The order book pair configuration
    * @return The taker fee
    **/
    function feeTaker(DataTypes.OBPairConfigMap storage self) public view returns (uint256) {
        uint fee = ((self.data & MASK_FEE_TAKER) >> SHIFT_FEE_TAKER);
        return fee == 0 ? 0 : fee - 1;
    }

    /**
    * @dev Sets min amount of order book pair
    * @param self The order book pair configuration
    * @param amt min amount to set
    **/
    function setMinAmount(DataTypes.OBPairConfigMap storage self, uint amt) public {
        require(amt < MASK_MIN_AMOUNT, "amount invalid");
        self.data = (self.data & ~MASK_MIN_AMOUNT) | (amt+1);
    }
    
    /**
    * @dev Sets the maker fee of order book pair
    * @param self The order book pair configuration
    * @param fee taker fee to set
    **/
    function setFeeMaker(DataTypes.OBPairConfigMap storage self, uint fee) public {
        require(fee < MASK_MIN_AMOUNT, "maker fee invalid");
        self.data = (self.data & ~MASK_FEE_MAKER) | ((fee+1) << SHIFT_FEE_MAKER);
    }

    /**
    * @dev Sets the maker fee of order book pair
    * @param self The order book pair configuration
    * @param fee maker fee to set
    **/
    function setFeeTaker(DataTypes.OBPairConfigMap storage self, uint fee) public {
        require(fee < MASK_MIN_AMOUNT, "taker fee invalid");
        self.data = (self.data & ~MASK_FEE_TAKER) | ((fee+1) << SHIFT_FEE_TAKER);
    }
}
