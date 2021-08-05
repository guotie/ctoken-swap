pragma solidity ^0.5.16;

import "./Exponential.sol";
import "./EIP20Interface.sol";
import "./EIP20NonStandardInterface.sol";
import "./PriceOracle.sol";
import "./ErrorReporter.sol";
import "./CToken.sol";
import "./ExponentialNoError.sol";

contract LPPool is LPPoolError, CarefulMath, ExponentialNoError, Exponential{
    
    mapping(address => mapping( address => uint)) accountTokens;
    
    //mint
    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function mint(uint mintAmount, address pool) external returns (uint) {
        (, ,uint accountTokensNew) = mintInternal(mintAmount, pool);
        return accountTokensNew;
    }
    
     /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual mint amount.
     */
    function mintInternal(uint mintAmount, address pool) internal returns (uint, uint, uint) {
        
        return mintFresh(msg.sender, mintAmount, pool);
    }
    
   /**
     * @notice User supplies assets into the market and receives cTokens in exchange
     * @dev Assumes interest has already been accrued up to the current block
     * @param minter The address of the account which is supplying the assets
     * @param mintAmount The amount of the underlying asset to supply
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual mint amount.
     */
    function mintFresh(address minter, uint mintAmount, address pool) internal returns (uint, uint, uint) {
        uint actualMintAmount = doTransferin(minter, mintAmount, pool);
        uint accountTokenPrior = accountTokens[pool][minter];
        uint accountTokenNew = add_(accountTokenPrior, actualMintAmount);
        
        //storage
        accountTokens[pool][minter] = accountTokenNew;
        
        return (uint(Error.NO_ERROR), actualMintAmount, accountTokenNew);
    }
    
    
    //qu
     /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeeem(uint mintAmount, address pool) external returns (uint) {
        (, ,uint mintTokens) = mintInternal(mintAmount, pool);
        return mintTokens;
    }
    
     /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of the underlying asset to supply
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual mint amount.
     */
    function redeeemInternal(uint redeemAmount, address pool) internal returns (uint, uint, uint) {
        
        return redeeemFresh(msg.sender, redeemAmount, pool);
    }
    
   /**
     * @notice User supplies assets into the market and receives cTokens in exchange
     * @dev Assumes interest has already been accrued up to the current block
     * @param redeeemer The address of the account which is supplying the assets
     * @param redeemAmount The amount of the underlying asset to supply
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual mint amount.
     */
    function redeeemFresh(address redeeemer, uint redeemAmount, address pool) internal returns (uint, uint, uint) {
        
        uint accountTokenPrior = accountTokens[pool][redeeemer];
        
        require(accountTokenPrior >= redeemAmount,"");
        
        uint accountTokenNew = sub_(accountTokenPrior, redeemAmount);
        
        doTransferOut(redeeemer, redeemAmount, pool);
        //storage
        accountTokens[pool][redeeemer] = accountTokenNew;
        
        return (uint(Error.NO_ERROR), redeemAmount, accountTokenNew);
    }
    
    
    //jie
    
    
    //huan
    
    
    //qingsuan
    
    
    
    function doTransferin(address from, uint amount, address underlying_) internal returns (uint) {
        if(underlying_ == address(0)){
            //ht
            // Sanity checks
            require(msg.value == amount, "value mismatch");
            return amount;
        }else{
             EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying_);
            uint balanceBefore = EIP20Interface(underlying_).balanceOf(address(this));
            token.transferFrom(from, address(this), amount);
    
            bool success;
            assembly {
                switch returndatasize()
                    case 0 {                       // This is a non-standard ERC-20
                        success := not(0)          // set success to true
                    }
                    case 32 {                      // This is a compliant ERC-20
                        returndatacopy(0, 0, 32)
                        success := mload(0)        // Set `success = returndata` of external call
                    }
                    default {                      // This is an excessively non-compliant ERC-20, revert.
                        revert(0, 0)
                    }
            }
            require(success, "TOKEN_TRANSFER_IN_FAILED");
    
            // Calculate the amount that was *actually* transferred
            uint balanceAfter = EIP20Interface(underlying_).balanceOf(address(this));
            require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
            return balanceAfter - balanceBefore;   // underflow already checked above, just subtract
        }
    }
    
    /**
     * @dev Similar to EIP20 transfer, except it handles a False success from `transfer` and returns an explanatory
     *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
     *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
     *      it is >= amount, this should not revert in normal conditions.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferOut(address to, uint amount, address underlying_) internal {
        EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying_);
        token.transfer(to, amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {                      // This is a non-standard ERC-20
                    success := not(0)          // set success to true
                }
                case 32 {                     // This is a complaint ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0)        // Set `success = returndata` of external call
                }
                default {                     // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_OUT_FAILED");
    }
    
    //genju shichang de  jiedailv  jisuan jiazhi 
    // function getLpValue(address pool, address account){
        
    // }
    
}