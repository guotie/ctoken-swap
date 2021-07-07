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
    uint constant internal MASK_FEE_MAKER  = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff; // prettier-ignore
    uint constant internal MASK_FEE_TAKER  = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000; // prettier-ignore
    uint constant internal FEE_DENOMINATOR = 10000;

    uint constant internal MAX_FEE_RATE = 1000; // 10%

    uint constant internal SHIFT_FEE_TAKER = 128;

    /**
    * @dev Gets the maker fee of order book pair
    * @param self The order book pair configuration
    * @return The maker fee + 1 if fee exist or else 0
    **/
    function feeMaker(DataTypes.OBPairConfigMap storage self) public view returns (uint256) {
        return (self.data & MASK_FEE_MAKER);
    }

    /**
    * @dev Gets the taker fee of order book pair
    * @param self The order book pair configuration
    * @return The taker fee + 1 if fee exist or else 0
    **/
    function feeTaker(DataTypes.OBPairConfigMap storage self) public view returns (uint256) {
        return ((self.data & MASK_FEE_TAKER) >> SHIFT_FEE_TAKER);
    }
    
    /**
    * @dev Sets the maker fee of order book pair
    * @param self The order book pair configuration
    * @param fee taker fee to set
    **/
    function setFeeMaker(DataTypes.OBPairConfigMap storage self, uint fee) public {
        require(fee < MAX_FEE_RATE, "maker fee invalid");
        self.data = (self.data & ~MASK_FEE_MAKER) | (fee+1);
    }

    /**
    * @dev Sets the maker fee of order book pair
    * @param self The order book pair configuration
    * @param fee maker fee to set
    **/
    function setFeeTaker(DataTypes.OBPairConfigMap storage self, uint fee) public {
        require(fee < MAX_FEE_RATE, "taker fee invalid");
        self.data = (self.data & ~MASK_FEE_TAKER) | ((fee+1) << SHIFT_FEE_TAKER);
    }
}
