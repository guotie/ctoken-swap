pragma solidity ^0.5.16;
import "./CTokenInterfaces.sol";
import "./ComptrollerInterfaceV2.sol";

contract LErc20DelegatorInterface {
      function delegateToInitialize(address underlying_,
                ComptrollerInterfaceV2 comptroller_,
                InterestRateModel interestRateModel_,
                uint initialExchangeRateMantissa_,
                string memory name_,
                string memory symbol_,
                uint8 decimals_,
                address payable admin_,
                address implementation_,
                bytes memory becomeImplementationData) public {}
}