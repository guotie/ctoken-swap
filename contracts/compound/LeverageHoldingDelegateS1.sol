pragma solidity ^0.5.16;

import "./Exponential.sol";
import "./EIP20Interface.sol";
import "./EIP20NonStandardInterface.sol";
import "./PriceOracle.sol";
import "./ErrorReporter.sol";
import "./ExponentialNoError.sol";
import "./LeverageHoldingInterface.sol";

contract LeverageHoldingDelegateS1 is LeverageHoldingInterface, LeverageError, CarefulMath, ExponentialNoError, Exponential{
   
     /**
     * @notice Construct
     */
    constructor() public {
       
    }
    
    function approveInternal( address token, address spender, uint amount) internal returns (bool){
        bool result = EIP20Interface(token).approve(spender, amount);
        return result;
    }
    
    //存入
    function deposit(address eTokenA, address eTokenB, address assertIn, uint amountIn) external payable returns(Error) {
       
        (uint error, address token0,address token1) = leverageComptroller.depositAllowed(eTokenA, eTokenB);
        require(error == 0,"pair query error");
        require(assertIn == token0 || assertIn == token1,"invalid assertIn");
        uint eTokens;
        //确认是否转进来这么多钱
        //判断基础资产是否为eth
        if(assertIn == baseEToken){
            eTokens = HTInterface(token0).mint.value(msg.value)();
        }else{
            amountIn = doTransferin(msg.sender, amountIn, getUnderlying_(assertIn));
            //杠杆存款
            bool result = approveInternal(getUnderlying_(assertIn), token0, amountIn);
            require(result, "approve fail");
            eTokens = CTokenInterfaceHoding(token0).mint(amountIn);
        }

        //资金都转入资金池，token =》 dToken ,存储当前的比例
        //存储数量
        PairCapital storage capital =  pairCapitals[token0][token1][msg.sender];
        if(assertIn == token0){
            capital.free0 = add_(capital.free0,eTokens);
        }else{
            capital.free1 = add_(capital.free1,eTokens);
        }
        return Error.NO_ERROR;
    
    }
    
    //杠杆资金
    struct LeverageBorrow{
       uint levarageTokens0; 
       uint levarageTokens1;
       uint surplus;
       uint levaraged;
       uint ratio;
       uint err;
    }
    //杠杆借款  根据转入的资产借款
    /**
      * @notice 杠杆借款到指定的代持合约账户
      address baseAssert 基础资产, address quoteAssert  计价资产  dToekn地址
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function leverageBorrow(address eTokenA, address eTokenB, address asserOut, uint leverageAmount) external returns (uint) {
        LeverageBorrow memory vars;
      
       (uint error, address token0,address token1) = leverageComptroller.leverageAllowed(eTokenA, eTokenB);
        require(error == 0,"pair query error");
        require(asserOut == eTokenA || asserOut == eTokenB);
        
        //计算借出资金 是否超出 限制  判断资金费率是否低于 设定的值 
         (vars.err, vars.surplus, vars.levaraged, vars.ratio) = leverageComptroller.getHypotheticalAccountLiquidityInternal(msg.sender,token0,token1,0,0,0,0);
        require(vars.err == uint(Error.NO_ERROR),"Miscalculation of liquidity");
        
        //判断风险率 不能低于最大可借风险率
        require(vars.ratio > loanableLine,"The maximum loan risk rate must be exceeded");
        
        //累加用户欠款
        LeverageCapital storage levarageCapital = leverageCapitals[token0][token1][msg.sender];
        // //token0
        if(asserOut == token0){
             //给用户发送借款代币  和 累加用户欠款
            vars.levarageTokens0 = CTokenInterfaceHoding(token0).leverageBorrow(leverageAmount);
            //xiu'gai修改shuju
            levarageCapital.pureCTokens0 = add_(levarageCapital.pureCTokens0,vars.levarageTokens0);
            levarageCapital.pureBaseAmount0 = add_(levarageCapital.pureBaseAmount0,leverageAmount);
            
            // uint borrowAmount;  //借款+利息
            // uint interestIndex; //利率
            (uint errUint0,uint borrowAmountNew0, uint interestIndexNew0) = borrowFresh(token0, token1, token0, msg.sender, leverageAmount);
            if(errUint0 == uint(Error.NO_ERROR)){
                levarageCapital.borrowAmount0 = borrowAmountNew0;
                levarageCapital.interestIndex0 = interestIndexNew0;
                require(leveragedMax(token0, token1, token0, borrowAmountNew0),"leverage too much");
            }
        }else{
             //给用户发送借款代币  和 累加用户欠款
            vars.levarageTokens1 = CTokenInterfaceHoding(token1).leverageBorrow(leverageAmount);
            //xiugaishuju
            levarageCapital.pureCTokens1 = add_(levarageCapital.pureCTokens1,vars.levarageTokens1);
            levarageCapital.pureBaseAmount1 = add_(levarageCapital.pureBaseAmount0,leverageAmount);
            
            // uint borrowAmount;  //借款+利息
            // uint interestIndex; //利率
            (uint errUint1,uint borrowAmountNew1, uint interestIndexNew1) = borrowFresh(token0, token1, token1, msg.sender, leverageAmount);
            if(errUint1 == uint(Error.NO_ERROR)){
                levarageCapital.borrowAmount1 = borrowAmountNew1;
                levarageCapital.interestIndex1 = interestIndexNew1;
                //shifou chaochu
                require(leveragedMax(token0, token1, token1, borrowAmountNew1),"leverage too much");
            }
        }
        
        //zaiciyanzhong
        uint err = leverageComptroller.leverageVerify(token0, token1, msg.sender);
        require(err == uint(Error.NO_ERROR),"Miscalculation of liquidity");

    }
    
    function leveragedMax(address token0, address token1, address leveraged, uint amount) internal view returns (bool){
        uint maximum = amountLeveragedMax[token0][token1][leveraged];
        if(maximum > 0 && amount > maximum){
            return false;
        }
        return true;
    }
    
    /**
      * @notice 转出可以转出部分
      address baseAssert 基础资产, address quoteAssert  计价资产  dToekn地址
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function withdraw(address eTokenA, address eTokenB, uint withdraw0, uint withdraw1) external returns (uint) {

       require(totalWithdrawalAllowed ,"withdraw isn't allowed");
       (uint error, address token0,address token1) = leverageComptroller.withdrawAllowed(eTokenA, eTokenB, msg.sender);
       
       require(error == 0,"pair query error");
        uint transferedETokens0;
        //取出  
        if(withdraw0 > 0){
            CTokenInterfaceHoding cToken = CTokenInterfaceHoding(token0);
            (,,transferedETokens0) = cToken.redeemUnderlying(withdraw0);
        }
        
        uint transferedETokens1;
        if(withdraw1 > 0){
              CTokenInterfaceHoding cToken = CTokenInterfaceHoding(token1);
              (,,transferedETokens1) = cToken.redeemUnderlying(withdraw1);
        }
        
        PairCapital storage capital =  pairCapitals[token0][token1][msg.sender];
        
        require(capital.free0 > transferedETokens0,"Insufficient baseAssert");
        require(capital.free1 > transferedETokens1,"Insufficient quoteAssert");
        
        //用户修改余额 
        capital.free0 = sub_(capital.free0,transferedETokens0);
        capital.free1 = add_(capital.free1,transferedETokens1);

        //再次查询和确认 
       uint err = leverageComptroller.withdrawVerify(token0, token1, msg.sender);
       require(err == uint(Error.NO_ERROR),"Miscalculation of liquidity");
        
        //转账 
        transferOut(token0, msg.sender, withdraw0);
        transferOut(token1, msg.sender, withdraw1);
    }
    
    struct BorrowLocalVars {
        uint mathErr;
        uint uintErr;
        uint accountBorrows;
        uint accountBorrowsNew;
        uint totalBorrowsNew;
        uint totalPrincipalsNew;
        uint pureLeverage;
        uint interest;
        uint accumulatedInterest;
    }
    
    /**
      * @notice Users borrow assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function borrowFresh(address token0, address token1, address assertSelected, address borrower, uint borrowAmount) internal returns (uint,uint,uint) {
      
        /* Verify market's block number equals current block number */
        if (verifyBlocks(assertSelected)) {
            return (fail(Error.MARKET_NOT_FRESH, Error.BORROW_FRESHNESS_CHECK), 0, 0);
        }
  
        BorrowLocalVars memory vars;

        /*
         * We calculate the new borrower and total borrow balances, failing on overflow:
         *  accountBorrowsNew = accountBorrows + borrowAmount
         *  totalBorrowsNew = totalBorrows + borrowAmount
         欠款总额  ctoken转化 利息    
         */
        (vars.mathErr, vars.accountBorrows, vars.pureLeverage, vars.interest, vars.accumulatedInterest) = borrowBalanceStored(token0,token1,assertSelected,borrower);
        if (vars.mathErr != uint(Error.NO_ERROR)) {
            return (failOpaque(Error.MATH_ERROR, Error.BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED, uint(vars.mathErr)),0,0);
        }
        
        uint totalBorrows = totalLeverages[token0][token1][assertSelected];
        uint totalPrincipals =  leveragePrincipals[token0][token1][assertSelected];
        vars.totalBorrowsNew = add_(totalBorrows, borrowAmount);
        vars.totalPrincipalsNew = add_(totalPrincipals, borrowAmount);
        if (vars.mathErr != uint(Error.NO_ERROR)) {
            return (failOpaque(Error.MATH_ERROR, Error.BORROW_NEW_TOTAL_BALANCE_CALCULATION_FAILED, uint(vars.mathErr)), 0, 0);
        }    
        
        vars.accountBorrowsNew = add_(vars.accountBorrows, borrowAmount);
        totalLeverages[token0][token1][assertSelected] = vars.totalBorrowsNew;
        leveragePrincipals[token0][token1][assertSelected] = vars.totalPrincipalsNew;
        
        /* We emit a Borrow event */
        //emit Borrow(borrower, borrowAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);

        return (uint(Error.NO_ERROR),vars.accountBorrowsNew,getBorrowIndex(assertSelected));
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