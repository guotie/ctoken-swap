pragma solidity ^0.5.16;
  contract LErc20DelegatorFactoryInterface{
      
      /**
     * @notice 根据token地址，查询/创建 cToken地址
     * @return The address of cToken
     */
    function getCTokenAddress(address token) external returns (address cToken){}
    
     /**
     * @notice cToken，查询 token地址
     * @return The address of token
     */
    function getTokenAddress(address cToken) external view returns (address){}
  }