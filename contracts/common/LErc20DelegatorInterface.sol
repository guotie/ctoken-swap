pragma solidity =0.7.6;
import "./CTokenInterfaces.sol";

contract LErc20DelegatorInterface {
      function delegateToInitialize(address underlying_,
                ComptrollerInterface comptroller_,
                InterestRateModel interestRateModel_,
                uint initialExchangeRateMantissa_,
                string memory name_,
                string memory symbol_,
                uint8 decimals_,
                address payable admin_,
                address implementation_,
                bytes memory becomeImplementationData) public {}
}