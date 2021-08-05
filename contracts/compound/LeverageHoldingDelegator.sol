pragma solidity ^0.5.16;

import "./Exponential.sol";
import "./EIP20Interface.sol";
import "./EIP20NonStandardInterface.sol";
import "./PriceOracle.sol";
import "./ErrorReporter.sol";
import "./ExponentialNoError.sol";
import "./LeverageHoldingInterface.sol";

contract LeverageHoldingDelegator is LeverageDelegatorStorage , LeverageHoldingInterface, LeverageError, CarefulMath, ExponentialNoError, Exponential{
   
   event NewImplementation(address newImplementationS1, address NewImplementationS2);
   
     /**
     * @notice Construct
     */
    constructor() public {
        admin = msg.sender;
    }
    
    /*** Admin Functions ***/
    
     function _approve( address token, address spender, uint amount) external {
         delegateAndReturnS2();
    }
    
    function _setImplementation(address implementationS1_, address implementationS2_) public {
        require(msg.sender == admin, "CErc20Delegator::_setImplementation: Caller must be admin");

        if(implementationS1_ != address(0)){
           implementationS1 = implementationS1_;
        }
        
        if(implementationS2_ != address(0)){
           implementationS2 = implementationS2_;
        }
        
        emit NewImplementation(implementationS1_, implementationS2_);
    }
    
     /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address payable newPendingAdmin) external returns (uint) {
        delegateAndReturnS2();
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() external returns (uint) {
        delegateAndReturnS2();
    }
   
     /**
      * @notice Sets a new comptroller for the market
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setComptroller(ComptrollerInterfaceV2 newComptroller) public returns (uint) {
         delegateAndReturnS2();
    }
    
    /**
      * @notice Sets a new leverageComptroller
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setLeverageComptroller(LeverageHoldingComptrollerInterface leverageComptroller_) public returns (uint) {
        delegateAndReturnS2();
    }
    
    /**
      * @notice Sets a new proceOracle
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPrice(PriceOracle oracle_) public returns (uint) {

        delegateAndReturnS2();
    }
    
    /**
      * @notice Sets a new leverageComptroller
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setBaseEToken(address baseEToken_) public returns (uint) {
       delegateAndReturnS2();
    }
    
    
    //存入
    function deposit(address eTokenA, address eTokenB, address asserIn, uint amountIn) external payable returns(Error) {
        delegateAndReturnS1();
    }
    
    //杠杆借款  根据转入的资产借款
    /**
      * @notice 杠杆借款到指定的代持合约账户
      address baseAssert 基础资产, address quoteAssert  计价资产  dToekn地址
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function leverageBorrow(address eTokenA, address eTokenB, address asserOut, uint leverageAmount) external returns (uint) {
        delegateAndReturnS1();
    }

    /**
      * @notice 转出可以转出部分
      address baseAssert 基础资产, address quoteAssert  计价资产  dToekn地址
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function withdraw(address eTokenA, address eTokenB, uint withdraw0, uint withdraw1) external returns (uint) {

        delegateAndReturnS1();
    } 


    //查询抵押的真实资产
    function getTokenAmount(address eToken_,uint eTokens) public view returns(uint){
         delegateToViewAndReturnS1();
    }
    
     /**
     * @notice Get a snapshot of the account's balances, and the cached exchange rate
     * @dev This is used by comptroller to more efficiently perform liquidity checks.
     * @param account Address of the account to snapshot
     * @return (possible error, token balance, borrow balance, exchange rate mantissa)
     */
    function getAccountSnapshot(address eToken0, address eToken1, address account) external view returns (uint, uint, uint) {
        
       delegateToViewAndReturnS1();
    }

 
    /**
     * @notice Return the borrow balance of account based on stored data
     * @param account The address whose balance should be calculated
     * @return (error code, the calculated balance or 0 if error code is non-zero) 返回 欠款总额  ctoken转化 利息     
     */
    function borrowBalanceStored(address eToken0, address eToken1, address assetsSelected, address account) public view returns (uint, uint, uint, uint, uint) {
       delegateToViewAndReturnS1();
    }

     /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @dev Reverts upon any failure
     */
    function liquidateLeverage(address borrower,address token0, address token1, address eTokenLiquidated) external payable {
        delegateAndReturnS1();
    }
    
    function liquidateLeverage(address borrower, uint repayAmount,address token0, address token1, address eTokenLiquidated) external returns (uint) {
        delegateAndReturnS1();
    }
    
    //清算----------------------------
    /**
     * @notice Checks if the liquidation should be allowed to occur
     * @param repayAmount The amount of underlying being repaid
     */
    function liquidateBorrowAllowed(address borrower,address token0, address token1, uint repayAmount, address eTokenLiquidated) public view returns (uint, uint, uint) {
       delegateToViewAndReturnS1();
    }
    

    /**
     * Is the maximum executable value exceeded  jisuan shifou keyi bei qingsuan
     */
    function executable(uint levaraged, address borrower,address token0, address token1, uint repayAmount, address eTokenLiquidated)  public view returns(uint,uint,uint){
       
       delegateToViewAndReturnS1();
    }

    
      function liquidateCalculateSeizeTokens(address eTokenLiquidated, uint actualRepayAmount) public view returns (uint, uint) {
       delegateToViewAndReturnS1();
    }
    
    //swap
    //chauxn pairdizhi
    function getPair(address token0, address token1) public view returns (address){
       delegateToViewAndReturnS1();
    }
    
  
    function verifyBlocks(address eToken_) public view returns(bool) {
        delegateToViewAndReturnS1();
    }
    
    function exchangeRateStored(address dToken_) internal view returns(uint){
       delegateToViewAndReturnS1();
    }
    
    function getBlockNumber() public view returns(uint){
        return block.number;
    }
    
    function accrueInterest(address eToken_) public returns(uint){
        delegateAndReturnS1();
    }
    
    struct OnFulfiled{
        address token0;
        address token1;
    }
    
    // --------------------------------------- dingdanbu
    
    //guadan  test
    function commissionOrder(address token0, address token1, address srcToken, address destToken, uint amountIn, uint guaranteeAmountOut, uint expiredAt, uint flag) external returns(uint){
       delegateAndReturnS1();
    }    
    
    
    /**
     * @notice Applies accrued interest to total borrows and reserves
     * @dev This calculates interest accrued from the last checkpointed block
     *   up to the current block and writes new checkpoint to storage.
     */
    function accrueInterest(address token0, address token1, address tokenAccrued) public returns (uint) {
       delegateAndReturnS1();
    }
    
  // owner: 杠杆用户
  // fulfiled: 买到的token数量
  // amt: 卖出的token数量
  function onFulfiled(address owner, address tokenOut, address tokenIn, uint fulfiled, uint amt) external{
      delegateAndReturnS1();
  }
  
  //quxiao  huidiao
  function onCanceled(address owner, address token0, address token1, address tokenReturn, uint amt) external {
     delegateAndReturnS1();
  }
  
  /**
     * @notice Internal method to delegate execution to another contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param callee The contract to delegatecall
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateTo(address callee, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize)
            }
        }
        return returnData;
    }

    /**
     * @notice Delegates execution to the implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToImplementationS1(bytes memory data) public returns (bytes memory) {
        return delegateTo(implementationS1, data);
    }
    
    
    function delegateToImplementationS2(bytes memory data) public returns (bytes memory) {
        return delegateTo(implementationS2, data);
    }
    /**
     * @notice Delegates execution to an implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     *  There are an additional 2 prefix uints from the wrapper returndata, which we ignore since we make an extra hop.
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToViewImplementation(bytes memory data) public view returns (bytes memory) {
        (bool success, bytes memory returnData) = address(this).staticcall(abi.encodeWithSignature("delegateToImplementation(bytes)", data));
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize)
            }
        }
        return abi.decode(returnData, (bytes));
    }

    function delegateToViewAndReturnS1() private view returns (bytes memory) {
        (bool success, ) = address(this).staticcall(abi.encodeWithSignature("delegateToImplementationS1(bytes)", msg.data));

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize)

            switch success
            case 0 { revert(free_mem_ptr, returndatasize) }
            default { return(add(free_mem_ptr, 0x40), returndatasize) }
        }
    }
    
    function delegateToViewAndReturnS2() private view returns (bytes memory) {
        (bool success, ) = address(this).staticcall(abi.encodeWithSignature("delegateToImplementationS2(bytes)", msg.data));

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize)

            switch success
            case 0 { revert(free_mem_ptr, returndatasize) }
            default { return(add(free_mem_ptr, 0x40), returndatasize) }
        }
    }
    
    function delegateAndReturnS1() private returns (bytes memory) {
        (bool success, ) = implementationS1.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize)

            switch success
            case 0 { revert(free_mem_ptr, returndatasize) }
            default { return(free_mem_ptr, returndatasize) }
        }
    }
    
    function delegateAndReturnS2() private returns (bytes memory) {
        (bool success, ) = implementationS2.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize)

            switch success
            case 0 { revert(free_mem_ptr, returndatasize) }
            default { return(free_mem_ptr, returndatasize) }
        }
    }
    /**
     * @notice Delegates execution to an implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     */
    function () external payable {
        // delegate all other functions to current implementation
        delegateAndReturnS1();
    }
    
}
