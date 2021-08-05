pragma solidity ^0.5.16;

contract ComptrollerInterfaceV2 {
    
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true;

    //设置delegate工厂地址
    function _setDelegateFactoryAddress(address  delegateFactoryAddress_) external returns (uint);
    
    //支持市场（初始化市场）
    function _supportMarket(address token,address cTokenAddress) external returns (uint);    
    
     /**
     * @notice 资产 和 ctoken绑定集合 k:cToken  v:token
     * @dev Used e.g. to determine if a market is supported
     */
     function tokenFromEToken( address eToken) external view returns (address);
    
    /**
     * @notice 资产 和 ctoken绑定集合 k:token  v:cToken
     * @dev Used e.g. to determine if a market is supported
     */
    function eTokenFromToken( address token) external view returns (address);


    // function leverageBorrowAllowed(address cTokenLeveraged,address leverageUser, uint leverageAmount) external returns (uint);

    // function leverageBorrowVerify(address cTokenLeveraged,address leverageUser, uint leverageAmount ,uint pledgeAmount) external;
    
    function isCToken( address cToken) external view returns (bool);
    //确定是查询 还是设置
    //function oracle() external view returns (bool);
    function isLP(address eToken) external view returns (bool);
    
    function _updateMarket(address eTokenAddress, bool isLPPool) external returns (uint);
    
    function _grantComp(address recipient, uint amount) public;

}
