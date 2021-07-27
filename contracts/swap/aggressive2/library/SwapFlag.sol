// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./DataTypes.sol";

library SwapFlag {
    uint256 public constant FLAG_TOKEN_IN_ETH          = 0x000000000100; // prettier-ignore
    uint256 public constant FLAG_TOKEN_TOKEN           = 0x000000000200; // prettier-ignore
    uint256 public constant FLAG_TOKEN_CTOKEN          = 0x000000000400; // prettier-ignore
    uint256 public constant FLAG_TOKEN_OUT_ETH         = 0x000000000800; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_OUT_TOKEN       = 0x000000001000; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_OUT_CTOKEN      = 0x000000002000; // prettier-ignore
    // uint256 public constant FLAG_TOKEN_OUT_CETH        = 0x0000000040; // prettier-ignore

    uint256 internal constant _MASK_PARTS           = 0x00000000000000000000ff; // prettier-ignore
    uint256 internal constant _MASK_MAIN_ROUTES     = 0x00ff000000000000000000; // prettier-ignore
    uint256 internal constant _MASK_COMPLEX_LEVEL   = 0x0300000000000000000000; // prettier-ignore
    uint256 internal constant _MASK_PARTIAL_FILL    = 0x0400000000000000000000; // prettier-ignore
    uint256 internal constant _MASK_BURN_CHI        = 0x0800000000000000000000; // prettier-ignore

    // uint256 internal constant _SHIFT_PARTS          = 64; // prettier-ignore
    uint256 internal constant _SHIFT_MAIN_ROUTES    = 72; // prettier-ignore
    uint256 internal constant _SHIFT_COMPLEX_LEVEL  = 80; // prettier-ignore

    /// @dev if token in/out is token
    function tokenIsToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_TOKEN) != 0;
    }

    function tokenIsToken(uint flag) public pure returns (bool) {
        return (flag & FLAG_TOKEN_TOKEN) != 0;
    }
    
    /// @dev if token in/out is ctoken
    function tokenIsCToken(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_CTOKEN) != 0;
    }

    /// @dev if token in is ETH
    function tokenInIsETH(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_IN_ETH) != 0;
    }

    /// @dev if token out is ETH
    function tokenOutIsETH(DataTypes.SwapFlagMap memory self) public pure returns (bool) {
        return (self.data & FLAG_TOKEN_OUT_ETH) != 0;
    }

    /// @dev get param split parts
    function getParts(DataTypes.SwapFlagMap memory self) public pure returns (uint256) {
        return (self.data & _MASK_PARTS);
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
