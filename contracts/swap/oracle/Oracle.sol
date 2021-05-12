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
pragma solidity =0.7.6;

import "../../common/IMdexFactory.sol";
import "../../common/IMdexPair.sol";

import "../../common/libraries/FixedPoint.sol";

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

// library FixedPoint {
//     // range: [0, 2**112 - 1]
//     // resolution: 1 / 2**112
//     struct uq112x112 {
//         uint224 _x;
//     }

//     // range: [0, 2**144 - 1]
//     // resolution: 1 / 2**112
//     struct uq144x112 {
//         uint _x;
//     }

//     uint8 private constant RESOLUTION = 112;

//     // encode a uint112 as a UQ112x112
//     function encode(uint112 x) internal pure returns (uq112x112 memory) {
//         return uq112x112(uint224(x) << RESOLUTION);
//     }

//     // encodes a uint144 as a UQ144x112
//     function encode144(uint144 x) internal pure returns (uq144x112 memory) {
//         return uq144x112(uint256(x) << RESOLUTION);
//     }

//     // divide a UQ112x112 by a uint112, returning a UQ112x112
//     function div(uq112x112 memory self, uint112 x) internal pure returns (uq112x112 memory) {
//         require(x != 0, 'FixedPoint: DIV_BY_ZERO');
//         return uq112x112(self._x / uint224(x));
//     }

//     // multiply a UQ112x112 by a uint, returning a UQ144x112
//     // reverts on overflow
//     function mul(uq112x112 memory self, uint y) internal pure returns (uq144x112 memory) {
//         uint z;
//         require(y == 0 || (z = uint(self._x) * y) / y == uint(self._x), "FixedPoint: MULTIPLICATION_OVERFLOW");
//         return uq144x112(z);
//     }

//     // returns a UQ112x112 which represents the ratio of the numerator to the denominator
//     // equivalent to encode(numerator).div(denominator)
//     function fraction(uint112 numerator, uint112 denominator) internal pure returns (uq112x112 memory) {
//         require(denominator > 0, "FixedPoint: DIV_BY_ZERO");
//         return uq112x112((uint224(numerator) << RESOLUTION) / denominator);
//     }

//     // decode a UQ112x112 into a uint112 by truncating after the radix point
//     function decode(uq112x112 memory self) internal pure returns (uint112) {
//         return uint112(self._x >> RESOLUTION);
//     }

//     // decode a UQ144x112 into a uint144 by truncating after the radix point
//     function decode144(uq144x112 memory self) internal pure returns (uint144) {
//         return uint144(self._x >> RESOLUTION);
//     }
// }

library MdexOracleLibrary {
    using FixedPoint for *;

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(
        address pair
    ) internal view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IMdexPair(pair).price0CumulativeLast();
        price1Cumulative = IMdexPair(pair).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IMdexPair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
            // counterfactual
            price1Cumulative += uint(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
        }
    }
}

contract Oracle {
    using FixedPoint for *;
    using SafeMath for uint;

    struct Observation {
        uint timestamp;
        uint price0Cumulative;
        uint price1Cumulative;
    }

    address public immutable factory;
    uint public constant CYCLE = 30 minutes;

    // mapping from pair address to a list of price observations of that pair
    mapping(address => Observation) public pairObservations;

    constructor(address factory_) {
        factory = factory_;
    }


    function update(address tokenA, address tokenB) external {
        address pair = IMdexFactory(factory).pairFor(tokenA, tokenB);

        Observation storage observation = pairObservations[pair];
        uint timeElapsed = block.timestamp - observation.timestamp;
        require(timeElapsed >= CYCLE, 'MDEXOracle: PERIOD_NOT_ELAPSED');
        (uint price0Cumulative, uint price1Cumulative,) = MdexOracleLibrary.currentCumulativePrices(pair);
        observation.timestamp = block.timestamp;
        observation.price0Cumulative = price0Cumulative;
        observation.price1Cumulative = price1Cumulative;
    }


    function computeAmountOut(
        uint priceCumulativeStart, uint priceCumulativeEnd,
        uint timeElapsed, uint amountIn
    ) private pure returns (uint amountOut) {
        // overflow is desired.
        FixedPoint.uq112x112 memory priceAverage = FixedPoint.uq112x112(
            uint224((priceCumulativeEnd - priceCumulativeStart) / timeElapsed)
        );
        amountOut = priceAverage.mul(amountIn).decode144();
    }


    function consult(address tokenIn, uint amountIn, address tokenOut) external view returns (uint amountOut) {
        address pair = IMdexFactory(factory).pairFor(tokenIn, tokenOut);
        Observation storage observation = pairObservations[pair];
        uint timeElapsed = block.timestamp - observation.timestamp;
        (uint price0Cumulative, uint price1Cumulative,) = MdexOracleLibrary.currentCumulativePrices(pair);
        (address token0,) = IMdexFactory(factory).sortTokens(tokenIn, tokenOut);

        if (token0 == tokenIn) {
            return computeAmountOut(observation.price0Cumulative, price0Cumulative, timeElapsed, amountIn);
        } else {
            return computeAmountOut(observation.price1Cumulative, price1Cumulative, timeElapsed, amountIn);
        }
    }
}
