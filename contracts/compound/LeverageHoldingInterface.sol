pragma solidity ^0.5.16;
import "./PriceOracle.sol";
import "./CToken.sol";
import "./LeverageHoldingComptrollerInterface.sol";

contract LeverageDelegatorStorage{
    /**
     * @notice Implementation address for this contract
     */
    address public implementationS1;
    
    address public implementationS2;
    
    address public admin;
    
    address public pendingAdmin;
}

contract LeverageHoldingStorage is LeverageDelegatorStorage{
    
    uint scale = 1e18; 
    
    //交易对  base  => quote
    mapping(address => mapping(address => bool)) public pairs;
 
    //用户杠杆借出金额存储  记录的是CToken数量
    mapping(address => mapping(address => mapping (address => PairCapital))) public pairCapitals;

    //用户金额借款 baseAssert => quoteAssert => user =>借款实体
    mapping(address => mapping(address => mapping(address => LeverageCapital))) public leverageCapitals;
    
    //几个安全线
    uint liquidationLine = 1.1e18;
    //清算奖励 针对本金 的比例
    uint liquidationActive = 0.15e18;
    //可借线
    uint loanableLine = 1.25e18;
    
    uint safeTransfeLine = 2e18;
    
    bool public totalWithdrawalAllowed = true;
    
    address public swapFactory_ ;
    
    address public marginHolding_ ;
    
    //jiekuan benjin //token0 => token1 => token0/token1 chun shuliang 
    mapping(address => mapping(address => mapping(address => uint))) public leveragePrincipals;
    mapping(address => mapping(address => mapping(address => uint))) public totalLeverages;
    mapping(address => mapping(address => mapping(address => uint))) public accrualBlockNumbers;
    //单个交易对提取安全开关
    
    //jiekuan zuida zhi 
    mapping(address => mapping(address => mapping(address => uint))) public amountLeveragedMax;
    //jiaoyidui zhong mouge bizhong de shouxufei lv
    mapping(address => mapping(address => mapping(address => uint))) public tokenLeverageRates;
    
    //清算
     /**
     * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
     */
    uint public closeFactorMantissa = 0.5e18;
    
    // closeFactorMantissa must be strictly greater than this value
    uint internal constant closeFactorMinMantissa = 0.05e18; // 0.05

    // closeFactorMantissa must not exceed this value
    uint internal constant closeFactorMaxMantissa = 1e18; // 1
    
    /**
     * @notice Multiplier representing the discount on collateral that a liquidator receives
     */
    uint public liquidationIncentiveMantissa;
    
    //价格合约
    PriceOracle public oracle;
    
    ComptrollerInterfaceV2 public comptrollerV2;
    
    //HTizhi
    address public baseEToken = address(0);
    
       
   LeverageHoldingComptrollerInterface public leverageComptroller;
    
    address public pauseGuardian;
    bool public _mintGuardianPaused;
    bool public _borrowGuardianPaused;
    bool public transferGuardianPaused;
    bool public seizeGuardianPaused;
    mapping(address => bool) public mintGuardianPaused;
    mapping(address => bool) public borrowGuardianPaused;
    
        
    //用户交易对资金存储模型
    struct PairCapital{
        uint free0;
        uint free1;
        uint freeze0;
        uint freeze1;
    }
    
    //杠杆资金
    struct LeverageCapital{
        uint pureBaseAmount0; //借款真实base币
        uint pureCTokens0;   //真实欠款cToken
        uint borrowAmount0;  //借款+利息
        uint interestIndex0; //利率
        uint pureBaseAmount1; //借款真实base币
        uint pureCTokens1;   //真实欠款cToken
        uint borrowAmount1;  //借款+利息
        uint interestIndex1; //利率
    }
    
}

contract LeverageHoldingInterface is LeverageHoldingStorage{
    function getAccountSnapshot(address eToken0, address eToken1, address account) external view returns (uint, uint, uint);
    
    function borrowBalanceStored(address eToken0, address eToken1, address assetsSelected, address account) public view returns (uint, uint, uint, uint, uint);
    
    
}


contract LeverageHoldingUnitrollerStorage{
    
    uint scale = 1e18; 
     /**
    * @notice Administrator for this contract
    */
    address public admin;

    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;

    /**
    * @notice Active brains of Unitroller
    */
    address public comptrollerImplementation;
}


contract LeverageHoldingComptrollerStorage is LeverageHoldingUnitrollerStorage{
    //交易对  base  => quote
    mapping(address => mapping(address => bool)) pairs;
    
    //价格合约
    PriceOracle public oracle;
    
    ComptrollerInterfaceV2 public comptrollerV2;
    
    LeverageHoldingInterface public leverageDelegator;
    
    
      //几个安全线
    uint liquidationLine = 1.1e18;
    //清算奖励 针对本金 的比例
    uint liquidationActive = 0.15e18;
    //可借线
    uint loanableLine = 1.25e18;
    
    uint safeTransfeLine = 2e18;

}




