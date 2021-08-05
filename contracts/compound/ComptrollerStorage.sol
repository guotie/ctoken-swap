pragma solidity ^0.5.16;

import "./CToken.sol";
import "./PriceOracle.sol";

contract UnitrollerAdminStorage { 
    /**
    * @notice Administrator for this contract
    */
    address public admin;
    
     /**
    * @notice The address of delegateFactory
    */
    address public delegateFactoryAddress;
    
    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;

    /**
    * @notice Pending brains of Unitroller
    */
    address public pendingComptrollerImplementation;
    
    // @notice 每一个方法 对应的 implemention地址 的索引
    mapping(bytes => uint) public methodImplements; 

    // @notice 实现地址.集合的
    mapping(uint => address) public implementsMapping;
}

contract ComptrollerV1Storage is UnitrollerAdminStorage {

    /**
     * @notice Oracle which gives the price of any given asset
     */
    PriceOracle public oracle;

    /**
     * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
     */
    uint public closeFactorMantissa;

    /**
     * @notice Multiplier representing the discount on collateral that a liquidator receives
     */
    uint public liquidationIncentiveMantissa;

    /**
     * @notice Max number of assets a single account can participate in (borrow or use as collateral)
     */
    uint public maxAssets;

    /**
     * @notice Per-account mapping of "assets you are in", capped by maxAssets
     */
    mapping(address => CToken[]) public accountAssets;

}

contract ComptrollerV2Storage is ComptrollerV1Storage {
    struct Market {
        /// @notice Whether or not this market is listed
        bool isListed;

        /**
         * @notice Multiplier representing the most one can borrow against their collateral in this market.
         *  For instance, 0.9 to allow borrowing 90% of collateral value.
         *  Must be between 0 and 1, and stored as a mantissa.
         */
        uint collateralFactorMantissa;

        /// @notice Per-market mapping of "accounts in this asset"
        mapping(address => bool) accountMembership;

        /// @notice Whether or not this market receives LHB
        bool isComped;
          //--修改  borrowFactorMantissa
         /**
         * @notice Multiplier representing the most one can borrow against their collateral in this market.
         *  For instance, 1 to allow borrowing 100% of borrow value.
         *  Must be between 0 and 1, and stored as a mantissa.
         */
        uint borrowFactorMantissa;
        
        bool isLPPool;
    }

    /**
     * @notice Official mapping of cTokens -> Market metadata
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => Market) public markets;    // 资产地址
    
     /**
     * @notice 资产 和 ctoken绑定集合 k:eToken  v:token
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => address) public eTokensMapping;
    
    /**
     * @notice 资产 和 ctoken绑定集合 k:token  v:eToken
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => address) public tokensMapping;
    
    /**
     * @notice The Pause Guardian can pause certain actions as a safety mechanism.
     *  Actions which allow users to remove their own assets cannot be paused.
     *  Liquidation / seizing / transfer can only be paused globally, not by market.
     */
    address public pauseGuardian;
    bool public _mintGuardianPaused;
    bool public _borrowGuardianPaused;
    bool public transferGuardianPaused;
    bool public seizeGuardianPaused;
    mapping(address => bool) public mintGuardianPaused;
    mapping(address => bool) public borrowGuardianPaused;
}

contract ComptrollerV3Storage is ComptrollerV2Storage {
    struct CompMarketState {
        /// @notice The market's last updated compBorrowIndex or compSupplyIndex
        uint224 index;

        /// @notice The block number the index was last updated at
        uint32 block;
    }

    /// @notice A list of all markets
    CToken[] public allMarkets;

    /// @notice The rate at which the flywheel distributes LHB, per block
    uint public compRate;

    /// @notice The portion of compRate that each market currently receives
    mapping(address => uint) public compSpeeds;

    /// @notice The LHB market supply state for each market
    mapping(address => CompMarketState) public compSupplyState;

    /// @notice The LHB market borrow state for each market
    mapping(address => CompMarketState) public compBorrowState;

    /// @notice The LHB borrow index for each market for each supplier as of the last time they accrued LHB
    mapping(address => mapping(address => uint)) public compSupplierIndex;

    /// @notice The LHB borrow index for each market for each borrower as of the last time they accrued LHB
    mapping(address => mapping(address => uint)) public compBorrowerIndex;

    /// @notice The LHB accrued but not yet transferred to each user
    mapping(address => uint) public compAccrued;
}

contract ComptrollerV4Storage is ComptrollerV3Storage {
    // @notice The borrowCapGuardian can set borrowCaps to any number for any market. Lowering the borrow cap could disable borrowing on the given market.
    address public borrowCapGuardian;

    // @notice Borrow caps enforced by borrowAllowed for each cToken address. Defaults to zero which corresponds to unlimited borrowing.
    mapping(address => uint) public borrowCaps;

    
    /// @notice The threshold above which the flywheel transfers LHB, in wei
    uint public constant compClaimThreshold = 0.001e18;

    /// @notice The initial LHB index for a market
    uint224 public constant compInitialIndex = 1e36;

    // closeFactorMantissa must be strictly greater than this value
    uint internal constant closeFactorMinMantissa = 0.05e18; // 0.05

    // closeFactorMantissa must not exceed this value
    uint internal constant closeFactorMaxMantissa = 0.9e18; // 0.9

    // No collateralFactorMantissa may exceed this value
    uint internal constant collateralFactorMaxMantissa = 0.9e18; // 0.9

    // No borrowFactorMantissa may exceed this value   0.9 shezhicheng 10/9 
    uint internal constant borrowFactorMaxMantissa = 1e18; // 1

}

contract ComptrollerV5Storage is ComptrollerV4Storage {
    
    mapping(address => uint) public pledgedMaxs;
    
    mapping(address => uint) public pledgeAmounts;
}