pragma solidity ^0.5.16;

import "./Exponential.sol";
import "./EIP20Interface.sol";
import "./EIP20NonStandardInterface.sol";
import "./PriceOracle.sol";
import "./ErrorReporter.sol";
import "./ExponentialNoError.sol";
import "./LeverageHoldingInterface.sol";

contract LeverageHoldingDelegateS2 is LeverageHoldingInterface, LeverageError, CarefulMath, ExponentialNoError, Exponential{
   
     /**
     * @notice Construct
     */
    constructor() public {
   
    }
    
     /*** Admin Functions ***/
    
    function _approve( address token, address spender, uint amount) external returns (bool){
        // Check caller = admin
        if (msg.sender != admin) {
            return false;
        }
        bool result = EIP20Interface(token).approve(spender, amount);
        
    }
    
    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address payable newPendingAdmin) external returns (uint) {
        // Check caller = admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, Error.SET_PENDING_ADMIN_OWNER_CHECK);
        }

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() external returns (uint) {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        if (msg.sender != pendingAdmin || msg.sender == address(0)) {
            return fail(Error.UNAUTHORIZED, Error.ACCEPT_ADMIN_PENDING_ADMIN_CHECK);
        }

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        return uint(Error.NO_ERROR);
    }
   
     /**
      * @notice Sets a new comptroller for the market
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setComptroller(ComptrollerInterfaceV2 newComptroller) public returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, Error.SET_COMPTROLLER_OWNER_CHECK);
        }
        //set comptroller V2
        comptrollerV2 = newComptroller;
        return uint(Error.NO_ERROR);
    }
    
    /**
      * @notice Sets a new leverageComptroller
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setLeverageComptroller(LeverageHoldingComptrollerInterface leverageComptroller_) public returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, Error.SET_COMPTROLLER_OWNER_CHECK);
        }
        //set comptroller V2
        leverageComptroller = leverageComptroller_;
        return uint(Error.NO_ERROR);
    }
    
    /**
      * @notice Sets a new proceOracle
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPrice(PriceOracle oracle_) public returns (uint) {

        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, Error.SET_PENDING_IMPLEMENTATION_OWNER_CHECK);
        }
        oracle = oracle_;

        return uint(Error.NO_ERROR);
    }
    
    /**
      * @notice Sets a new leverageComptroller
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setBaseEToken(address baseEToken_) public returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, Error.SET_COMPTROLLER_OWNER_CHECK);
        }
        baseEToken = baseEToken_;
        return uint(Error.NO_ERROR);
    }
    
    //查询真实资产地址
    function getUnderlying_(address cToken_) private view returns (address){
        CTokenInterfaceHoding cToken = CTokenInterfaceHoding(cToken_);
        address underlying_ = cToken.underlying();
        require(underlying_ != address(0), "cToken's underlying is zero");
        
        return underlying_;
    }
    
    function getBorrowIndex(address cToken_) private view returns (uint) {
          CTokenInterfaceHoding cToken = CTokenInterfaceHoding(cToken_);
          return cToken.borrowIndex();
    }
    
    function transferOut(address eToken, address payable to, uint amount) internal {
        if(eToken == baseEToken){
           doMainTransferOut(to,amount);
        }else{
            doTokenTransferOut(to, amount, eToken);
        }
    }
    

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
    
    function doTransferOutBefore(address to_, uint amount, address eToken) internal{
         address payable to = address(uint160(to_));
        if(eToken == baseEToken){
            doMainTransferOut( to, amount);
           
        }else{
            doTokenTransferOut( to,amount, getUnderlying_(eToken));
        }
    }
    
    function doMainTransferOut(address payable to, uint amount) internal {
        /* Send the Ether, with minimal gas and revert on failure */
        to.transfer(amount);
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
    function doTokenTransferOut(address payable to, uint amount, address underlying_) internal {
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

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `cTokenBalance` is the number of cTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountLiquidityLocalVars {
        uint sumCollateral;
        uint sumBorrowPlusEffects;
        uint baseBalance;
        uint quoteBalance;
        uint borrowBalance;
        uint oraclePrice0Mantissa;
        uint oraclePrice1Mantissa;
    }

   
    //查询抵押的真实资产
    function getTokenAmount(address eToken_,uint eTokens) public view returns(uint){
        CTokenInterfaceHoding eToken = CTokenInterfaceHoding(eToken_);
        return mul_(eTokens,eToken.exchangeRateStored());
    }
    
     /**
     * @notice Get a snapshot of the account's balances, and the cached exchange rate
     * @dev This is used by comptroller to more efficiently perform liquidity checks.
     * @param account Address of the account to snapshot
     * @return (possible error, token balance, borrow balance, exchange rate mantissa)
     */
    function getAccountSnapshot(address eToken0, address eToken1, address account) external view returns (uint, uint, uint) {
        
        (uint error, address token0, address token1) = leverageComptroller.getPairAddr(eToken0, eToken1);
        if(error != 0){
            return (uint(Error.QUERY_ERROR), 0, 0);
        }
        PairCapital memory capital = pairCapitals[token0][token1][account];

        return (uint(Error.NO_ERROR), add_(capital.free0, capital.freeze0), add_(capital.free1, capital.freeze1));
    }

    struct BorrowBalance{
        uint principalTimesIndex0;
        uint principalTimesIndex1;
        uint result0;
        uint result1;
        uint pureLeverage0;
        uint interest0;
        uint pureLeverage1;
        uint interest1;
    }   
        
    /**
     * @notice Return the borrow balance of account based on stored data
     * @param account The address whose balance should be calculated
     * @return (error code, the calculated balance or 0 if error code is non-zero) 返回 欠款总额  ctoken转化 利息     
     */
    function borrowBalanceStored(address eToken0, address eToken1, address assetsSelected, address account) public view returns (uint, uint, uint, uint, uint) {
       
        BorrowBalance memory vars;
        
        (uint error, address token0, address token1) = leverageComptroller.getPairAddr(eToken0, eToken1);
        if(error != 0){
            return (uint(Error.QUERY_ERROR), 0, 0, 0, 0);
        }
        /* Get borrowBalance and borrowIndex */
        LeverageCapital storage borrowSnapshot = leverageCapitals[token0][token1][account];
 
        /* If borrowBalance = 0 then borrowIndex is likely also 0.
         * Rather than failing the calculation with a division by 0, we immediately return 0 in this case.
         */
        if (borrowSnapshot.borrowAmount0 == 0 && borrowSnapshot.borrowAmount1 == 0) {
            return (uint(Error.NO_ERROR), 0, 0, 0, 0);
        }
        
        require(assetsSelected == token0 || token1 == assetsSelected,"Wrong asset address");
        
        if(borrowSnapshot.borrowAmount0 > 0){
             //获得该市场现在的的borrow index
            uint borrowIndex0 = getBorrowIndex(token0);
            MathError mathErr;
            /* Calculate new borrow balance using the interest index:
             *  recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
             */
            (mathErr, vars.principalTimesIndex0) = mulUInt(borrowSnapshot.borrowAmount0, borrowIndex0);
            if (mathErr != MathError.NO_ERROR) {
                return (uint(Error.MATH_ERROR), 0, 0, 0, 0);
            }
    
            (mathErr, vars.result0) = divUInt(vars.principalTimesIndex0, borrowSnapshot.interestIndex0);
            if (mathErr != MathError.NO_ERROR) {
                return (uint(Error.MATH_ERROR), 0, 0, 0, 0);
            }
            //转化cToken 对应的Token数量  getTokenAmount(address dToken_,uint dTokens)
            vars.pureLeverage0 = getTokenAmount(token0,borrowSnapshot.pureCTokens0);
            //lixi
            vars.interest0 = sub_(vars.result0, borrowSnapshot.pureBaseAmount0);
        }
        if(borrowSnapshot.borrowAmount1 > 0){
             //获得该市场现在的的borrow index
            uint borrowIndex1 = getBorrowIndex(token1);
            MathError mathErr;
            /* Calculate new borrow balance using the interest index:
             *  recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
             */
            (mathErr, vars.principalTimesIndex1) = mulUInt(borrowSnapshot.borrowAmount1, borrowIndex1);
            if (mathErr != MathError.NO_ERROR) {
                return (uint(Error.MATH_ERROR), 0, 0, 0, 0);
            }
    
            (mathErr, vars.result1) = divUInt(vars.principalTimesIndex1, borrowSnapshot.interestIndex1);
            if (mathErr != MathError.NO_ERROR) {
                return (uint(Error.MATH_ERROR), 0, 0, 0, 0);
            }
            //转化cToken 对应的Token数量  getTokenAmount(address dToken_,uint dTokens)
            vars.pureLeverage1 = getTokenAmount(token1,borrowSnapshot.pureCTokens1);
            //lixi
            vars.interest1 = sub_(vars.result1, borrowSnapshot.pureBaseAmount1);
        }
        if(assetsSelected == token0){
             return (uint(Error.NO_ERROR), add_(vars.pureLeverage0,vars.interest0), vars.pureLeverage0, vars.interest0, vars.result0);
        }
        return (uint(Error.NO_ERROR), add_(vars.pureLeverage1,vars.interest1), vars.pureLeverage1, vars.interest1, vars.result1);
    }

     /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @dev Reverts upon any failure
     */
    function liquidateLeverage(address borrower,address token0, address token1, address eTokenLiquidated) external payable {
        require(eTokenLiquidated == token0 || eTokenLiquidated == token1, "invali_eTokenLiquidated");
        (uint err,) = liquidateBorrowInternal(borrower, token0, token1, msg.value, eTokenLiquidated);
        require(err == 0, "liquidateBorrow failed");
    }
    
    function liquidateLeverage(address borrower, uint repayAmount,address token0, address token1, address eTokenLiquidated) external returns (uint) {
        require(eTokenLiquidated == token0 || eTokenLiquidated == token1, "invali_eTokenLiquidated");
        (uint err,) = liquidateBorrowInternal(borrower, token0, token1, repayAmount, eTokenLiquidated);
        return err;
    }
    
      /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this cToken to be liquidated
     * @param repayAmount The amount of the underlying borrowed asset to repay
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function liquidateBorrowInternal(address borrower,address token0, address token1, uint repayAmount, address eTokenLiquidated) internal returns (uint, uint) {
        uint error = accrueInterest(eTokenLiquidated);
        if (error != uint(Error.NO_ERROR)) {
            // accrueInterest emits logs on errors, but we still want to log the fact that an attempted liquidation failed
            return (fail(Error(error), Error.LIQUIDATE_ACCRUE_BORROW_INTEREST_FAILED), 0);
        }

        //liquidateBorrowFresh emits borrow-specific logs on errors, so we don't need to
       return liquidateBorrowFresh(msg.sender,borrower, token0, token1, repayAmount, eTokenLiquidated);
    }
    
     struct LiquidateBorrow{
        uint repayBorrowError;
        uint actualRepayAmount;
        uint amountSeizeError;
        uint seizeTokens;
        uint eTokenBlance;
        uint sendAmounts;
    }
    
    
    /**
     * @notice The liquidator liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this cToken to be liquidated
     * @param repayAmount The amount of the underlying borrowed asset to repay
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function liquidateBorrowFresh(address liquidator,address borrower,address token0, address token1, uint repayAmount, address eTokenLiquidated) internal returns (uint, uint) {
        LiquidateBorrow memory vars;
        
        /* Fail if liquidate not allowed */
        (uint allowed, , uint getPledgeVAlue) = liquidateBorrowAllowed(borrower, token0, token1, repayAmount, eTokenLiquidated);
        
        if (allowed != 0) {
            return (failOpaque(Error.COMPTROLLER_REJECTION, Error.LIQUIDATE_COMPTROLLER_REJECTION, allowed), 0);
        }
        /* Verify market's block number equals current block number */
        if (verifyBlocks(eTokenLiquidated)) {
            return (fail(Error.MARKET_NOT_FRESH, Error.LIQUIDATE_FRESHNESS_CHECK), 0);
        }

        /* Fail if borrower = liquidator */
        if (borrower == liquidator) {
            return (fail(Error.INVALID_ACCOUNT_PAIR, Error.LIQUIDATE_LIQUIDATOR_IS_BORROWER), 0);
        }

        /* Fail if repayAmount = 0 */
        if (repayAmount == 0) {
            return (fail(Error.INVALID_CLOSE_AMOUNT_REQUESTED, Error.LIQUIDATE_CLOSE_AMOUNT_IS_ZERO), 0);
        }

        /* Fail if repayAmount = -1 */
        if (repayAmount == uint(-1)) {
            return (fail(Error.INVALID_CLOSE_AMOUNT_REQUESTED, Error.LIQUIDATE_CLOSE_AMOUNT_IS_UINT_MAX), 0);
        }


        /* Fail if repayBorrow fails */
        (vars.repayBorrowError, vars.actualRepayAmount) = repayLeverageFresh(liquidator, token0, token1, eTokenLiquidated, borrower, repayAmount);
        if (vars.repayBorrowError != uint(Error.NO_ERROR)) {
            return (fail(Error(vars.repayBorrowError), Error.LIQUIDATE_REPAY_BORROW_FRESH_FAILED), 0);
        }

        // /////////////////////////
        // // EFFECTS & INTERACTIONS
        // // (No safe failures beyond this point)
        

        /* We calculate the number of collateral tokens that will be seized */
        (vars.amountSeizeError, vars.seizeTokens) = liquidateCalculateSeizeTokens(eTokenLiquidated, vars.actualRepayAmount);
        require(vars.amountSeizeError == uint(Error.NO_ERROR), "LIQUIDATE_COMPTROLLER_CALCULATE_AMOUNT_SEIZE_FAILED");
        //gen'ju根据qiangsuan bili jisuan  qu xiao
        vars.sendAmounts = vars.seizeTokens <= getPledgeVAlue ? vars.seizeTokens :getPledgeVAlue;
        
        PairCapital storage capital =  pairCapitals[token0][token1][borrower];
        if(eTokenLiquidated == token0){
            vars.eTokenBlance = capital.free0;
        }else{
            vars.eTokenBlance = capital.free1;
        }
        /* Revert if borrower collateral token balance < seizeTokens */
        require(vars.eTokenBlance >= vars.seizeTokens, "LIQUIDATE_SEIZE_TOO_MUCH");

        // If this is also the collateral, run seizeInternal to avoid re-entrancy, otherwise make an external call
        uint seizeError = seizeInternal(address(this), liquidator, borrower, vars.seizeTokens);
        /* Revert if seize tokens fails (since we cannot be sure of side effects) */
        require(seizeError == uint(Error.NO_ERROR), "token seizure failed");

        /* We emit a LiquidateBorrow event */
        //emit LiquidateBorrow(liquidator, borrower, actualRepayAmount, address(cTokenCollateral), seizeTokens);

        /* We call the defense hook */
      // comptroller.liquidateBorrowVerify(address(this), address(cTokenCollateral), liquidator, borrower, actualRepayAmount, seizeTokens);

        return (uint(Error.NO_ERROR), vars.actualRepayAmount);
    }
    
    //清算----------------------------
    /**
     * @notice Checks if the liquidation should be allowed to occur
     * @param repayAmount The amount of underlying being repaid
     */
    function liquidateBorrowAllowed(address borrower,address token0, address token1, uint repayAmount, address eTokenLiquidated) public view returns (uint, uint, uint) {
        /* The borrower must have shortfall in order to be liquidatable */
        (uint err, , uint levaraged, ) = leverageComptroller.getHypotheticalAccountLiquidityInternal(borrower,token0,token1,0,0,0,0);
        if (err != uint(Error.NO_ERROR)) {
            return (uint(err), 0, 0);
        }
    
        return executable(levaraged, borrower, token0, token1, repayAmount, eTokenLiquidated);
    }
    
    struct Executable{
        uint maxClose;
        uint oraclePriceMantissa;
        
        uint assetRatio0;
        uint assetRatio1;
        uint oraclePrice0Mantissa;
        uint oraclePrice1Mantissa;
        uint leverageRatio0;
        uint leverageRatio1;
        uint liquidationRatio;
        uint LiquidationMax;
        uint getPledgeVAlue;
        uint repayValue;
        
    }
    
    /**
     * Is the maximum executable value exceeded  jisuan shifou keyi bei qingsuan
     */
    function executable(uint levaraged, address borrower,address token0, address token1, uint repayAmount, address eTokenLiquidated)  public view returns(uint,uint,uint){
       
       Executable memory vars;
        /* The liquidator may not repay more than what is allowed by the closeFactor */
        vars.maxClose = mul_ScalarTruncate(Exp({mantissa: closeFactorMantissa}), levaraged);
         //基础币的 价格
        vars.oraclePriceMantissa = oracle.getUnderlyingPrice(CToken(eTokenLiquidated));
        vars.repayValue = mul_(repayAmount, vars.oraclePriceMantissa);

        if (vars.repayValue > vars.maxClose) {
            return (uint(Error.TOO_MUCH_REPAY), 0, 0);
        }
        //buyunxu chaoguo jin e
        (uint mError, uint borrowBalance, , , ) = borrowBalanceStored(token0,token1,eTokenLiquidated,borrower);
          if (mError != uint(Error.NO_ERROR)) {
            return (uint(Error.MATH_ERROR), 0, 0);
        }
        uint tokenLeverage =  mul_(vars.oraclePriceMantissa, borrowBalance);
        if (vars.repayValue > tokenLeverage) {
            return (uint(Error.TOO_MUCH_REPAY), 0, 0);  
        }
         //基础币的 价格
        vars.oraclePrice0Mantissa = oracle.getUnderlyingPrice(CToken(token0));
        //计价币的价格
        vars.oraclePrice1Mantissa = oracle.getUnderlyingPrice(CToken(token1));
        
        //jisuan cun kuan  bili
         //总计账户剩余金额
        (vars.getPledgeVAlue, vars.assetRatio0, vars.assetRatio1) = leverageComptroller.getPledgeAsserts(token0,token1,borrower,vars.oraclePrice0Mantissa,vars.oraclePrice1Mantissa,0,0);
        
         //ji'suan  qiankuan bili 
        (, , vars.leverageRatio0, vars.leverageRatio1) = leverageComptroller.getLeverageAsserts(token0,token1,borrower,vars.oraclePrice0Mantissa,vars.oraclePrice1Mantissa,0,0);
        
        //根据帮还款项比例，就算出给的抵押物。 比较抵押物  和  还款额加上清算奖励。去小
        vars.liquidationRatio = vars.assetRatio1 <=  vars.leverageRatio1 ? vars.assetRatio1 : vars.leverageRatio1;
        
        //genju  qingsuan bili jisuan ke qingsuan jiekuan E
        //根据最大可清算比例计算最大可以还款数量
        vars.LiquidationMax = mul_(vars.liquidationRatio, levaraged);
        if (vars.repayValue > vars.LiquidationMax) {
            return (uint(Error.TOO_MUCH_REPAY), 0, 0);
        }
        return (uint(Error.NO_ERROR), vars.repayValue, vars.getPledgeVAlue);
    }
    
    
  
    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Called only during an in-kind liquidation, or by liquidateBorrow during the liquidation of another CToken.
     *  Its absolutely critical to use msg.sender as the seizer cToken and not a parameter.
     * @param seizerToken The contract seizing the collateral (i.e. borrowed cToken)
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of cTokens to seize
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function seizeInternal(address seizerToken, address liquidator, address borrower, uint seizeTokens) internal returns (uint) {
        /* Fail if seize not allowed */
        //uint allowed = comptroller.seizeAllowed(address(this), seizerToken, liquidator, borrower, seizeTokens);
        // if (allowed != 0) {
        //     return failOpaque(Error.COMPTROLLER_REJECTION, FailureInfo.LIQUIDATE_SEIZE_COMPTROLLER_REJECTION, allowed);
        // }

        /* Fail if borrower = liquidator */
        if (borrower == liquidator) {
            return fail(Error.INVALID_ACCOUNT_PAIR, Error.LIQUIDATE_SEIZE_LIQUIDATOR_IS_BORROWER);
        }

        // MathError mathErr;
        // uint borrowerTokensNew;
        // uint liquidatorTokensNew;

        /*
         * We calculate the new borrower and liquidator token balances, failing on underflow/overflow:
         *  borrowerTokensNew = accountTokens[borrower] - seizeTokens
         *  liquidatorTokensNew = accountTokens[liquidator] + seizeTokens
         */
         
        doTransferOutBefore(liquidator, seizeTokens, seizerToken);

        /* Emit a Transfer event */
       // emit Transfer(borrower, liquidator, seizeTokens);

        /* We call the defense hook */
        //comptroller.seizeVerify(address(this), seizerToken, liquidator, borrower, seizeTokens);

        return uint(Error.NO_ERROR);
    }
    
      function liquidateCalculateSeizeTokens(address eTokenLiquidated, uint actualRepayAmount) public view returns (uint, uint) {
        /* Read oracle prices for borrowed and collateral markets */
        uint priceLiquidatedMantissa = oracle.getUnderlyingPrice(CToken(eTokenLiquidated));
        if (priceLiquidatedMantissa == 0) {
            return (uint(Error.PRICE_ERROR), 0);
        }

        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint exchangeRateMantissa = CToken(eTokenLiquidated).exchangeRateStored(); // Note: reverts on error
        uint seizeTokens;
        Exp memory numerator;
        Exp memory denominator;
        Exp memory ratio;

        numerator = mul_(Exp({mantissa: liquidationIncentiveMantissa}), Exp({mantissa: priceLiquidatedMantissa}));
        denominator = mul_(Exp({mantissa: priceLiquidatedMantissa}), Exp({mantissa: exchangeRateMantissa}));
        ratio = div_(numerator, denominator);

        seizeTokens = mul_ScalarTruncate(ratio, actualRepayAmount);

        return (uint(Error.NO_ERROR), seizeTokens);
    }
    
    
     struct RepayBorrowLocalVars {
        Error err;
        uint mathErr;
        uint repayAmount;
        uint borrowerIndex;
        uint accountBorrows;
        uint accountBorrowsNew;
        uint totalBorrowsNew;
        uint actualRepayAmount;
        uint pureLeverage;
        uint interest;
        uint pureBaseAmountNew; //借款真实base币
        uint pureCTokensNew;   //真实欠款cToken
        uint borrowAmount;
        uint borrowAmountNew; //借款+利息
        uint interestIndexNew; //利率
        uint interestRepayed;
        uint pureRepayed;
    }
    
     /**
     * @notice Borrows are repaid by another user (possibly the borrower).
     * @param payer the account paying off the borrow
     * @param borrower the account with the debt being payed off
     * @param repayAmount the amount of undelrying tokens being returned
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function repayLeverageFresh(address payer, address token0, address token1, address repayAssert, address borrower, uint repayAmount) internal returns (uint, uint) {
        /* Fail if repayBorrow not allowed */
        // uint allowed = comptroller.repayBorrowAllowed(address(this), payer, borrower, repayAmount);
        // if (allowed != 0) {
        //     return (failOpaque(Error.COMPTROLLER_REJECTION, FailureInfo.REPAY_BORROW_COMPTROLLER_REJECTION, allowed), 0);
        // }

        /* Verify market's block number equals current block number */
        if (verifyBlocks(repayAssert)) {
            return (fail(Error.MARKET_NOT_FRESH, Error.REPAY_BORROW_FRESHNESS_CHECK), 0);
        }
        
        require(repayAssert == token0 || token1 == repayAssert,"Wrong asset address");
        
        RepayBorrowLocalVars memory vars;
        
        /* We fetch the amount the borrower owes, with accumulated interest */
        (vars.mathErr, vars.accountBorrows, vars.pureLeverage, vars.interest, vars.borrowAmount) = borrowBalanceStored(token0,token1,repayAssert,borrower);
        if (vars.mathErr != uint(Error.NO_ERROR)) {
            return (failOpaque(Error.MATH_ERROR, Error.REPAY_BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED, uint(vars.mathErr)), 0);
        }
        //payAmount shi token
        /* If repayAmount == -1, repayAmount = accountBorrows */
        if (repayAmount == uint(-1)) {
            vars.repayAmount = vars.accountBorrows;
        } else {
            vars.repayAmount = repayAmount;
        }
        if(repayAssert == baseEToken){
            vars.actualRepayAmount = doTransferin(payer, vars.repayAmount,address(0));
        }else{
            vars.actualRepayAmount = doTransferin(payer, vars.repayAmount,getUnderlying_(repayAssert));
        }

        /*
         * We calculate the new borrower and total borrow balances, failing on underflow:
         *  accountBorrowsNew = accountBorrows - actualRepayAmount
         *  totalBorrowsNew = totalBorrows - actualRepayAmount
         */
       //vars.accountBorrowsNew = sub_(vars.accountBorrows, vars.actualRepayAmount);
        
        //判断利息部分是否被还完 
        if(vars.actualRepayAmount <= vars.interest){
            vars.borrowAmountNew = sub_(vars.borrowAmount,vars.interest);
            //yihuan lixi
            vars.interestRepayed = vars.actualRepayAmount;
            
            //xiugai
            updateAfterRepayIntrest(token0, token1, borrower, repayAssert, vars.borrowAmountNew, vars.interestRepayed);
        }else{
            //lixi
            vars.interestRepayed = vars.interest;
            
            vars.pureBaseAmountNew = vars.accountBorrowsNew;
            vars.pureCTokensNew = div_(vars.accountBorrowsNew,exchangeRateStored(repayAssert));
            vars.borrowAmountNew = vars.accountBorrowsNew;
            
            //benjin huan de shuliang
            
            vars.pureRepayed = sub_(vars.actualRepayAmount, vars.interest);
            //xiugai
            updateAfterRepayPure(token0, token1, borrower, repayAssert, vars.borrowAmountNew, vars.interestRepayed, vars.pureBaseAmountNew, vars.pureCTokensNew, vars.pureRepayed);
        }
        //updateAfterRepay(token0, token1, repayAssert, vars.borrowAmountNew, vars.interestRepayed, vars.pureBaseAmountNew, vars.pureCTokensNew);
        
        /* We emit a RepayBorrow event */
        //emit RepayBorrow(payer, borrower, vars.actualRepayAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);

        /* We call the defense hook */
        //comptroller.repayBorrowVerify(address(this), payer, borrower, vars.actualRepayAmount, vars.borrowerIndex);

        return (uint(Error.NO_ERROR), vars.actualRepayAmount);
    }
    
    function updateAfterRepayIntrest(address token0, address token1, address borrower, address repayAssert, uint borrowAmountNew, uint interestRepayed) private{
        LeverageCapital storage levarageCapital = leverageCapitals[token0][token1][borrower];
        if(repayAssert == token0){
            /* We write the previously calculated values into storage */
            levarageCapital.borrowAmount0 = borrowAmountNew;
            levarageCapital.interestIndex0 = getBorrowIndex(repayAssert);
        }else{
             /* We write the previously calculated values into storage */
            levarageCapital.borrowAmount1 = borrowAmountNew;
            levarageCapital.interestIndex1 = getBorrowIndex(repayAssert);
        }
        //zhuanzhang
        transferTomarket(interestRepayed, repayAssert);
    }
    
    function updateAfterRepayPure(address token0, address token1, address borrower, address repayAssert, uint borrowAmountNew, uint interestRepayed, uint pureBaseAmountNew, uint pureCTokensNew, uint pureRepayed) private{
        LeverageCapital storage levarageCapital = leverageCapitals[token0][token1][borrower];
        if(repayAssert == token0){
            /* We write the previously calculated values into storage */
            levarageCapital.borrowAmount0 = borrowAmountNew;
             /* We write the previously calculated values into storage */
            levarageCapital.pureBaseAmount0 = pureBaseAmountNew;
            levarageCapital.pureCTokens0 = pureCTokensNew;

            levarageCapital.interestIndex0 = getBorrowIndex(repayAssert);
        }else{
             /* We write the previously calculated values into storage */
            levarageCapital.borrowAmount1 = borrowAmountNew;
             /* We write the previously calculated values into storage */
            levarageCapital.pureBaseAmount1 = pureBaseAmountNew;
            levarageCapital.pureCTokens1 = pureCTokensNew;

            levarageCapital.interestIndex1 = getBorrowIndex(repayAssert);
        }
        //zhuanzhang
        transferTomarket(interestRepayed, repayAssert);
        //chuli benjin bufen
        //uint mintTokens = CTokenInterfaceHoding.mint
        uint mintTokens = mintToken(repayAssert, pureRepayed);
        //huan eTokens  
        CTokenInterfaceHoding(repayAssert).redeemLeverage(mintTokens);
    }
  
   //cunkuan 
   function mintToken(address eToken_, uint amountToken) internal returns(uint) {
       uint minETokens;
       if(eToken_ == baseEToken){
          minETokens = HTInterface(eToken_).mint.value(amountToken)();
       }else{
          minETokens = CTokenInterfaceHoding(eToken_).mint(amountToken);
       }
   }
    
    function transferTomarket( uint amount, address eToken_) internal{
        
        address payable eToken = address(uint160(eToken_));
        
        //gentu tokeno he  token1 cha'xun查询   shichang dizhi 
        doTransferOutBefore(eToken, amount, eToken);
    }
    
    //swap
    //chauxn pairdizhi
    function getPair(address token0, address token1) public view returns (address){
        address underlying0 = CTokenInterfaceHoding(token0).underlying();
        address underlying1 = CTokenInterfaceHoding(token1).underlying();
        return ISwapInterface(swapFactory_).getPair(underlying0, underlying1);
    }
    
    struct CommissionOrder{
        uint add0;
        uint add1;
        uint levarage0;
        uint levarage1;
        uint err;
        uint surplus;
        uint levaraged;
        uint ratio;
    }
    
    
    
    function verifyBlocks(address eToken_) public view returns(bool) {
         CTokenInterfaceHoding eToken = CTokenInterfaceHoding(eToken_);
         return eToken.accrualBlockNumber() ==  getBlockNumber();
    }
    
    function exchangeRateStored(address dToken_) internal view returns(uint){
        CTokenInterfaceHoding dToken = CTokenInterfaceHoding(dToken_);
        return dToken.exchangeRateStored();
    }
    
    function getBlockNumber() public view returns(uint){
        return block.number;
    }
    
    function accrueInterest(address eToken_) public returns(uint){
        CTokenInterfaceHoding eToken = CTokenInterfaceHoding(eToken_);
        return eToken.accrueInterest();
    }
    
    struct OnFulfiled{
        address token0;
        address token1;
    }
    
    // --------------------------------------- dingdanbu
    
    //guadan  test
    function commissionOrder(address token0, address token1, address srcToken, address destToken, uint amountIn, uint guaranteeAmountOut, uint expiredAt, uint flag) external returns(uint){
        (,token0, token1) = leverageComptroller.getPairAddr(token0, token1);
        require(srcToken == token0 || srcToken == token1 ,"invalid srcToken");
        require(srcToken == token0 || srcToken == token1 ,"invalid srcToken");
        //guadan
        CommissionOrder memory vars;
        if(srcToken == token0){
            //maichu token0
            vars.levarage0 = guaranteeAmountOut;
            vars.add1 = amountIn;
        }else{
            vars.add0 = amountIn;
            vars.levarage1 = guaranteeAmountOut;
        }
        (vars.err, vars.surplus, vars.levaraged, vars.ratio) = leverageComptroller.getHypotheticalAccountLiquidityInternal(msg.sender,token0,token1,vars.add0,vars.add1,vars.levarage0,vars.levarage1);
        require(vars.ratio > liquidationLine,"reach the clearing line");
        
        IMarginHolding marginHolding = IMarginHolding(marginHolding_);
        uint result;
        //panduan  ht
        if(srcToken == baseEToken){
           result = marginHolding.createOrder.value(guaranteeAmountOut)(srcToken, destToken, msg.sender, amountIn, guaranteeAmountOut, expiredAt, flag); 
           //dongjie ????????????????
        }else{
            result = marginHolding.createOrder.value(0)(srcToken, destToken, msg.sender, amountIn, guaranteeAmountOut, expiredAt, flag);
        }
        return result;
    }    
    
    struct Accrue{
        uint currentBlockNumber;
        uint accrualBlockNumberPrior;
        uint interestAccumulated;
        uint totalBorrowsNew;
    }
    
    /**
     * @notice Applies accrued interest to total borrows and reserves
     * @dev This calculates interest accrued from the last checkpointed block
     *   up to the current block and writes new checkpoint to storage.
     */
    function accrueInterest(address token0, address token1, address tokenAccrued) public returns (uint) {
        Accrue memory vars;
        /* Remember the initial block number */
        vars.currentBlockNumber = getBlockNumber();
        vars.accrualBlockNumberPrior = accrualBlockNumbers[token0][token1][tokenAccrued];

        /* Short-circuit accumulating 0 interest */
        if (vars.accrualBlockNumberPrior == vars.currentBlockNumber) {
            return uint(Error.NO_ERROR);
        }
        CTokenInterfaceHoding eToken = CTokenInterfaceHoding(tokenAccrued);
        
        /* Read the previous values out of storage */
        uint borrowsPrior = totalLeverages[token0][token1][tokenAccrued];
        //????????????????????????????????????????????????????????????????????sikao  xuyao dandu  shezhi ma
        //uint borrowIndexPrior = eToken.borrowIndex();

        /* Calculate the current borrow interest rate */
        uint borrowRateMantissa = tokenLeverageRates[token0][token1][tokenAccrued];
        if(borrowRateMantissa == 0){
            borrowRateMantissa = eToken.getBorrowRate();
        }
        /* Calculate the number of blocks elapsed since the last accrual */
        (MathError mathErr, uint blockDelta) = subUInt(vars.currentBlockNumber, vars.accrualBlockNumberPrior);
        require(mathErr == MathError.NO_ERROR, "could not calculate block delta");

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */

        Exp memory simpleInterestFactor;
        

        (mathErr, simpleInterestFactor) = mulScalar(Exp({mantissa: borrowRateMantissa}), blockDelta);
        if (mathErr != MathError.NO_ERROR) {
            return failOpaque(Error.MATH_ERROR, Error.ACCRUE_INTEREST_SIMPLE_INTEREST_FACTOR_CALCULATION_FAILED, uint(mathErr));
        }

        (mathErr, vars.interestAccumulated) = mulScalarTruncate(simpleInterestFactor, borrowsPrior);
        if (mathErr != MathError.NO_ERROR) {
            return failOpaque(Error.MATH_ERROR, Error.ACCRUE_INTEREST_ACCUMULATED_INTEREST_CALCULATION_FAILED, uint(mathErr));
        }

        (mathErr, vars.totalBorrowsNew) = addUInt(vars.interestAccumulated, borrowsPrior);
        if (mathErr != MathError.NO_ERROR) {
            return failOpaque(Error.MATH_ERROR, Error.ACCRUE_INTEREST_NEW_TOTAL_BORROWS_CALCULATION_FAILED, uint(mathErr));
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We write the previously calculated values into storage */
        accrualBlockNumbers[token0][token1][tokenAccrued] = vars.currentBlockNumber;
        totalLeverages[token0][token1][tokenAccrued] = vars.totalBorrowsNew;

        /* We emit an AccrueInterest event */
        //emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
        
        //tian jia  dao  shichang   !!!!!!!!!!!!!storage
        eToken.externalDebtAdd(sub_(vars.totalBorrowsNew,borrowsPrior));
        return uint(Error.NO_ERROR);
    }
    
  // owner: 杠杆用户
  // fulfiled: 买到的token数量
  // amt: 卖出的token数量
  function onFulfiled(address owner, address tokenOut, address tokenIn, uint fulfiled, uint amt) external{
      OnFulfiled memory vars;
      //swap dizhi
      require(msg.sender == address(0));
      //maichu jianqu   mairu  jiashang
      (,vars.token0, vars.token1) = leverageComptroller.getPairAddr(tokenOut, tokenIn);
      //yonghu zichan
      PairCapital storage capital =  pairCapitals[vars.token0][vars.token1][owner];
      if(tokenOut == vars.token0){
          capital.freeze0 = sub_(capital.freeze0,amt);
          capital.free1 = add_(capital.free1,fulfiled);
      }else{
          capital.freeze1 = sub_(capital.freeze1,amt);
          capital.free0 = add_(capital.free0,fulfiled);
      }
  }
  
  //quxiao  huidiao
  function onCanceled(address owner, address token0, address token1, address tokenReturn, uint amt) external {
      require(msg.sender == address(0));
       //maichu jianqu   mairu  jiashang
      (,token0, token1) = leverageComptroller.getPairAddr(token0, token1);
      require(tokenReturn == token0 || tokenReturn == token1);
      //yonghu zichan
      PairCapital storage capital =  pairCapitals[token0][token1][owner];
      
      if(tokenReturn == token0){
          capital.freeze0 = sub_(capital.freeze0, amt);
          capital.free0 = sub_(capital.free0, amt);
      }else{
           capital.freeze1 = sub_(capital.freeze1, amt);
           capital.free1 = sub_(capital.free1, amt);
      }
  }
    
}

contract HTInterface{
   function mint() external payable returns (uint);
}

contract CTokenInterfaceHoding{
    function underlying() external view returns(address);
    
    function borrowIndex() external view returns(uint);
    
    function exchangeRateStored() public view returns (uint);
   
    function leverageBorrow(uint mintAmount) external returns (uint);
    
    //uint fzhi值 需要修改 
   function redeem(uint redeemTokens) external returns (uint,uint,uint);
   
   function redeemUnderlying(uint redeemAmount) external returns (uint,uint,uint);
    
    function accrueInterest() public returns (uint);
    
    function mint(uint mintAmount) external returns (uint);
    
    function accrualBlockNumber() public view returns (uint);
    
    function getBorrowRate() public view returns(uint);
    
    function externalDebtAdd(uint addBorrow) external returns (uint);
    
    function redeemLeverage(uint redeemTokens) external returns (uint, uint);
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);
}


interface IMarginHolding {
  //guadan
  function createOrder(
        address srcToken,//maichu
        address destToken,//dedao
        address to,             // 兑换得到的token发送地址, 杠杆传用户地址
        uint amountIn,
        uint guaranteeAmountOut,       // 
        uint expiredAt,          // 过期时间
        uint flag) external payable returns (uint);
}

contract ISwapInterface{
    function getPair(address token0, address token1) external view returns(address);
}