pragma solidity ^0.5.16;

contract LeverageHoldingComptrollerInterface{
    function getPairAddr(address eTokenA, address eTokenB) public pure returns (uint, address, address);
    
    function depositAllowed(address eToken0, address eToken1) external view returns (uint, address, address);
    
    function leverageAllowed(address eToken0, address eToken1) external view returns (uint, address, address);
    
    function getLeverageAsserts(address eToken0, address eToken1, address account,uint price0, uint price1, uint leverage0, uint leverage1) public view returns(uint,uint,uint,uint);
    
    function getPledgeAsserts(address eToken0, address eToken1, address account, uint price0, uint price1, uint deposit0, uint deposit1) public view returns(uint, uint, uint);
    
    function getHypotheticalAccountLiquidityInternal(
        address account,
        address token0, 
        address token1,
        uint deposit0,
        uint deposit1,
        uint leverage0,
        uint leverage1) public view returns (uint, uint, uint, uint);
        
    function leverageVerify(address eToken0, address eToken1, address account) external view returns (uint);
    
    function withdrawAllowed(address eToken0, address eToken1, address account) external view returns (uint, address, address);
    
    function withdrawVerify(address eToken0, address eToken1, address account) external view returns (uint);
    
}