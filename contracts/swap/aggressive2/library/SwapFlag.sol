// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./DataTypes.sol";

library SwapFlag {
    uint256 public constant FLAG_TOKEN_IN_ETH          = 0x0000000001; // prettier-ignore
    uint256 public constant FLAG_TOKEN_IN_TOKEN        = 0x0000000002; // prettier-ignore
    uint256 public constant FLAG_TOKEN_IN_CTOKEN       = 0x0000000004; // prettier-ignore
    uint256 public constant FLAG_TOKEN_OUT_ETH         = 0x0000000008; // prettier-ignore
    uint256 public constant FLAG_TOKEN_OUT_TOKEN       = 0x0000000010; // prettier-ignore
    uint256 public constant FLAG_TOKEN_OUT_CTOKEN      = 0x0000000020; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_OUT_CETH        = 0x0000000040; // prettier-ignore

    uint256 internal constant _MASK_PARTS           = 0x0000ff0000000000000000; // prettier-ignore
    uint256 internal constant _MASK_MAIN_ROUTES     = 0x00ff000000000000000000; // prettier-ignore
    uint256 internal constant _MASK_COMPLEX_LEVEL   = 0x0300000000000000000000; // prettier-ignore
    uint256 internal constant _MASK_PARTIAL_FILL    = 0x0400000000000000000000; // prettier-ignore
    uint256 internal constant _MASK_BURN_CHI        = 0x0800000000000000000000; // prettier-ignore

    uint256 internal constant _SHIFT_PARTS          = 64; // prettier-ignore
    uint256 internal constant _SHIFT_MAIN_ROUTES    = 72; // prettier-ignore
    uint256 internal constant _SHIFT_COMPLEX_LEVEL  = 80; // prettier-ignore

    /// @dev if token in is ctoken
    function tokenInIsCToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_IN_CTOKEN) != 0;
    }

    /// @dev if token out is ctoken
    function tokenOutIsCToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_OUT_CTOKEN) != 0;
    }


    /// @dev get param split parts
    function getParts(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_PARTS) >> _SHIFT_PARTS;
    }

    /// @dev get param main routes max port
    function getMainRoutes(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_MAIN_ROUTES) >> _SHIFT_MAIN_ROUTES;
    }

    /// @dev get param complex level
    function getComplexLevel(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_COMPLEX_LEVEL) >> _SHIFT_COMPLEX_LEVEL;
    }

    /// @dev get param allow partial fill
    function allowPartialFill(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & _MASK_PARTIAL_FILL) != 0;
    }

    /// @dev get param burn CHI
    function burnCHI(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & _MASK_BURN_CHI) != 0;
    }
}
