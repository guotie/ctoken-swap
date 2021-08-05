pragma solidity ^0.5.16;
import "./LeverageHoldingInterface.sol";
import "./LeverageHoldingComptrollerInterface.sol";
import "./ErrorReporter.sol";

contract LeverageHoldingComptroller is LeverageHoldingComptrollerStorage, LeverageHoldingComptrollerInterface, LeverageComprollerError, CarefulMath, ExponentialNoError, Exponential {
    
    event NewComptrollerV2(ComptrollerInterfaceV2 comptrollerV2Old, ComptrollerInterfaceV2 comptrollerV2New);
    event NewPriceOracle(PriceOracle oracleOld, PriceOracle oracleNew);
    event NewDelegator(LeverageHoldingInterface delegatorOld, LeverageHoldingInterface delegatorNew);
    
    // admin -  -- - - -
    
    function _setComptrollerV2(ComptrollerInterfaceV2 comptrollerV2_) public returns (uint) {

        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, Error.SET_PENDING_IMPLEMENTATION_OWNER_CHECK);
        }

        ComptrollerInterfaceV2 oldComproller = comptrollerV2;

        comptrollerV2 = comptrollerV2_;

        emit NewComptrollerV2(oldComproller, comptrollerV2);

        return uint(Error.NO_ERROR);
    }
    //   //价格合约
    
    // LeverageHoldingInterface public leverageDelegator;
    function _setPrice(PriceOracle oracle_) public returns (uint) {

        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, Error.SET_PENDING_IMPLEMENTATION_OWNER_CHECK);
        }

        PriceOracle oldOracle = oracle;

        oracle = oracle_;

        emit NewPriceOracle(oldOracle, oracle);

        return uint(Error.NO_ERROR);
    }
    
    
    function _setDelegator(LeverageHoldingInterface delegator_) public returns (uint) {

        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, Error.SET_PENDING_IMPLEMENTATION_OWNER_CHECK);
        }

        LeverageHoldingInterface delegatorOld = leverageDelegator;

        leverageDelegator = delegator_;

        emit NewDelegator(delegatorOld, leverageDelegator);

        return uint(Error.NO_ERROR);
    }
        
    //admin
    function _openLeverage(address eTokenA, address eTokenB) external {

        (uint error, address token0, address token1) = getPairAddr(eTokenA, eTokenB);
        require(error == 0);
        pairs[token0][token1] = true;
    }
    
    function _closeLeverage(address eTokenA, address eTokenB) external{
        (uint error, address token0, address token1) = getPairAddr(eTokenA, eTokenB);
         require(error == 0);
        pairs[token0][token1] = false;
    }
    
    //--
    function getPairAddr(address eTokenA, address eTokenB) public pure returns (uint, address, address){
         if(eTokenA == eTokenB){
             return (uint(Error.SAME_ADDR), address(0), address(0));
         }
        (address token0, address token1) = eTokenA < eTokenB ? (eTokenA, eTokenB) : (eTokenB, eTokenA);
        if(token0 == address(0)){
             return (uint(Error.ZERO_ADDR), address(0), address(0));
        }
        return(uint(Error.NO_ERROR), token0, token1);
    }
    
    //zhuanru  alloed yanzheng
    function depositAllowed(address eToken0, address eToken1) external view returns (uint, address, address){
        
        (uint error, address token0, address token1) = getPairAddr(eToken0, eToken1);
        if(error != 0){
            return (uint(Error.QUERY_ERROR), address(0), address(0));
        }
        // if(!pairs[token0][token1]){
        //     return (uint(Error.UNOPENED_LEVER), address(0), address(0));
        // }
         //判断是否属于市场地址
        if(!comptrollerV2.isCToken(token0) || !comptrollerV2.isCToken(token1)){
            return (uint(Error.INVALID_ADDR), address(0), address(0));
        }
        return (uint(Error.NO_ERROR), token0, token1);
    }
    
  
    
    function leverageAllowed(address eToken0, address eToken1) external view returns (uint, address, address){
        
       (uint error, address token0, address token1) = getPairAddr(eToken0, eToken1);
        if(error != 0){
            return (uint(Error.QUERY_ERROR), address(0), address(0));
        }
        if(!pairs[token0][token1]){
            return (uint(Error.UNOPENED_LEVER), address(0), address(0));
        }
         //判断是否属于市场地址
        if(!comptrollerV2.isCToken(token0) || !comptrollerV2.isCToken(token1)){
            return (uint(Error.INVALID_ADDR), address(0), address(0));
        }
        return (uint(Error.NO_ERROR), token0, token1);
        
    }
    

    function leverageVerify(address eToken0, address eToken1, address account) external view returns (uint){
       (uint error, address token0, address token1) = getPairAddr(eToken0, eToken1);
        if(error != 0){
            return (uint(Error.QUERY_ERROR));
        }
        (uint err, , , uint ratio) = getHypotheticalAccountLiquidityInternal(account,token0,token1,0,0,0,0);
        require(err == uint(Error.NO_ERROR),"Miscalculation of liquidity");
        
        //判断风险率 不能低于最大可借风险率
        if(ratio <= loanableLine){
            return uint(Error.INSUFFICIENT_SHORTFALL);
        }
        return uint(Error.NO_ERROR);
        
    }
    
     function withdrawAllowed(address eToken0, address eToken1, address account) external view returns (uint, address, address){
        
       (uint error, address token0, address token1) = getPairAddr(eToken0, eToken1);
        if(error != 0){
            return (uint(Error.QUERY_ERROR), address(0), address(0));
        }
         //判断是否属于市场地址
        if(!comptrollerV2.isCToken(token0) || !comptrollerV2.isCToken(token1)){
            return (uint(Error.INVALID_ADDR), address(0), address(0));
        }
       
        //计算借出资金 是否超出 限制  判断资金费率是否低于 设定的值
         (uint err, , , uint ratio) = getHypotheticalAccountLiquidityInternal(account,token0,token1,0,0,0,0);
        if(err != uint(Error.NO_ERROR)){
            return (uint(Error.QUERY_ERROR), address(0), address(0));
        }

        if(ratio <= safeTransfeLine){
            return ( uint(Error.INSUFFICIENT_SHORTFALL), address(0), address(0));
        }
        
        return (uint(Error.NO_ERROR), token0, token1);
    }
    
    function withdrawVerify(address eToken0, address eToken1, address account) external view returns (uint){
       (uint error, address token0, address token1) = getPairAddr(eToken0, eToken1);
        if(error != 0){
            return (uint(Error.QUERY_ERROR));
        }
        (uint err, , , uint ratio) = getHypotheticalAccountLiquidityInternal(account,token0,token1,0,0,0,0);
        require(err == uint(Error.NO_ERROR),"Miscalculation of liquidity");
        
        //
        if(ratio <= safeTransfeLine){
            return uint(Error.INSUFFICIENT_SHORTFALL);
        }
        return uint(Error.NO_ERROR);
        
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
    
    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `cTokenBalance` is the number of cTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    function getHypotheticalAccountLiquidityInternal(
        address account,
        address token0, 
        address token1,
        uint deposit0,
        uint deposit1,
        uint leverage0,
        uint leverage1) public view returns (uint, uint, uint, uint) {

        AccountLiquidityLocalVars memory vars; // Holds all our calculation results
        //true token0 token1
        (,token0,token1) = getPairAddr(token0, token1);
        //基础币的 价格
        vars.oraclePrice0Mantissa = oracle.getUnderlyingPrice(CToken(token0));
        //计价币的价格
        vars.oraclePrice1Mantissa = oracle.getUnderlyingPrice(CToken(token1));
        
        //总计账户剩余金额
        (vars.sumCollateral, , ) = getPledgeAsserts(token0,token1,account,vars.oraclePrice0Mantissa,vars.oraclePrice1Mantissa,deposit0,deposit1);

        //判断价格都要存在
        require(vars.oraclePrice0Mantissa > 0 && vars.oraclePrice1Mantissa > 0,"Price cannot be equal to 0");

        //计算借出币的资产价值 + 本次需要借出的价值
        //查询已经借款的数量
        uint mError;
        (mError, vars.borrowBalance , ,) = getLeverageAsserts(token0,token1,account,vars.oraclePrice0Mantissa,vars.oraclePrice1Mantissa,leverage0,leverage1);
        
        if (mError != uint(Error.NO_ERROR)) {
            return (uint(Error.MATH_ERROR), 0, 0, 0);
        }
        //总计欠款
        vars.sumBorrowPlusEffects = vars.borrowBalance;
        uint ratioMatissa = 0;
        //计算不超过清算线 账户剩余资产/借出资产
        if(vars.sumBorrowPlusEffects == 0){
            ratioMatissa = 99e18;
        }else{
            ratioMatissa  = div_(mul_(vars.sumCollateral,scale), vars.sumBorrowPlusEffects);
        }
        
        //返回结果 
        return (uint(Error.NO_ERROR), vars.sumCollateral, vars.sumBorrowPlusEffects, ratioMatissa);
    }
    
    
    struct pledgeAssert{
        uint eToken0Amount;
        uint eTtoken1Amount;
    }
    
      //获得账户现有的资产 返回的是USDT的数量   diaoyong  gengxin lilv
    function getPledgeAsserts(address eToken0, address eToken1, address account, uint price0, uint price1, uint deposit0, uint deposit1) public view returns(uint, uint, uint){
        pledgeAssert memory vars;
        
        (uint error, address token0, address token1) = getPairAddr(eToken0, eToken1);
        if(error != 0){
            return (uint(Error.QUERY_ERROR), 0, 0);
        }
       
        (error, vars.eToken0Amount, vars.eTtoken1Amount) = leverageDelegator.getAccountSnapshot(token0, token1, account);
        if(error != 0){
            return (uint(Error.QUERY_ERROR), 0, 0);
        }
        //获得基础币种 真实抵押资产
        
        uint token0Tokens = getTokenAmount(token0,vars.eToken0Amount);
        //获得 计价币 真实抵押资产
        uint token1Tokens = getTokenAmount(token1,vars.eTtoken1Amount);
        //根据价格 相乘 计算当前存款价值
        uint token0Value = mul_(price0,add_(token0Tokens,deposit0));
        uint token1Value = mul_(price1,add_(token1Tokens,deposit1));
        
        uint addTokenValue = add_(token0Value,token1Value);
        return (addTokenValue, div_(token0Value,addTokenValue), div_(token1Value, addTokenValue));
    }
    
    struct LeverageAsserts{
        uint error;
        address token0;
        address token1;
        //
         uint borrowBalance0;
         uint pureLeverage0;
         uint interest0;
         uint accumulatedInterest0;
         //
         uint borrowBalance1;
         uint pureLeverage1;
         uint interest1;
         uint accumulatedInterest1;
        //
        uint token0Leverage;
        uint token1Leverage;
        uint allLeverage;
    }    
     
     // 获得借款的资产 返回的是USDT的数量
     function getLeverageAsserts(address eToken0, address eToken1, address account,uint price0, uint price1, uint leverage0, uint leverage1) public view returns(uint,uint,uint,uint){
         uint mError;
         LeverageAsserts memory vars;   
         
         (vars.error, vars.token0, vars.token1) = getPairAddr(eToken0, eToken1);
        if(vars.error != 0){
            return (uint(Error.QUERY_ERROR), 0, 0, 0);
        }
         
         (mError, vars.borrowBalance0, vars.pureLeverage0, vars.interest0, vars.accumulatedInterest0) = leverageDelegator.borrowBalanceStored(vars.token0, vars.token1, vars.token0, account);
          if (mError != uint(Error.NO_ERROR)) {
            return (uint(Error.MATH_ERROR), 0, 0, 0);
        }
        vars.token0Leverage =  mul_(price0,add_(leverage0,vars.borrowBalance0));
         (mError, vars.borrowBalance1, vars.pureLeverage1, vars.interest1, vars.accumulatedInterest1) = leverageDelegator.borrowBalanceStored(vars.token0, vars.token1, vars.token1, account);
          if (mError != uint(Error.NO_ERROR)) {
            return (uint(Error.MATH_ERROR), 0, 0, 0);
        }
        vars.token1Leverage =  mul_(price1,add_(leverage1,vars.borrowBalance1));
        
        vars.allLeverage = add_(vars.token0Leverage, vars.token1Leverage);
        uint ratio0 = vars.allLeverage > 0 ? div_(mul_(vars.token0Leverage, scale), vars.allLeverage) : 0;
        uint ratio1 = vars.allLeverage > 0 ? div_(mul_(vars.token1Leverage, scale), vars.allLeverage) : 0;
        return (uint(Error.MATH_ERROR), vars.allLeverage, ratio0, ratio1);
    }
    
    
    //查询抵押的真实资产
    function getTokenAmount(address eToken_,uint eTokens) public view returns(uint){
        CTokenInterfaceHoding eToken = CTokenInterfaceHoding(eToken_);
        (, uint tokenAmount) = mulScalarTruncate(Exp({mantissa: eToken.exchangeRateStored()}), eTokens);
        return tokenAmount;
    }
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