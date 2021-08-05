pragma solidity ^0.5.16;

import "./LErc20DelegatorInterface.sol";
import "./LErc20Delegator.sol";
import "./EIP20Interface.sol";
import "./ComptrollerInterfaceV2.sol";

contract LErc20DelegatorFactory is LErc20DelegatorInterface {
    
    //发布 delegator
    event NewDelegator(address token,address delegator);
    
    //设置 swap 地址
    event NewSwapPairAddress(address newSwapPairAddress);
    
    //设置 compotroller 地址
    event NewComptroller(ComptrollerInterfaceV2 oldComptroller, ComptrollerInterfaceV2 newComptroller);
    
    //设置 interestRateModel 地址
    event NewInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel interestRateModel);
    
    //设置  implementation地址
    event NewImplementation(address oldImplementation, address implementation);
    
    event NewDelegatorAdmin(address oldDelegatorAdmin, address delegatorAdmin);
    
    /**
     * @notice Construct
     */
    constructor() public {
        // Creator of the contract is admin during initialization
        admin = msg.sender;
    }
    
      /*** Admin Functions ***/
      
      
    function _setPendingAdmin(address payable pendingAdmin_) public {
        require(msg.sender == admin, "only the admin may call _setPendingAdmin");
        pendingAdmin = pendingAdmin_;
    }
    
    function _acceptAdmin() public {
        require(msg.sender == pendingAdmin, "only the pendingAdmin may call _acceptAdmin");
        admin = pendingAdmin;
    }  
      
     /**
     * @notice 设置swap地址
     */
    function _setSwapPairAddress(address swapPairAddress_, bool flag) public{

        require(admin == msg.sender,"Permission denied");
        swapPairAddress[swapPairAddress_] = flag;

        emit NewSwapPairAddress(swapPairAddress_);

    }
    
     /**
     * @notice 设置comptroller地址
     */
    function _setComptroller(ComptrollerInterfaceV2 comptroller_) public{

        require(admin == msg.sender,"Permission denied");
        ComptrollerInterfaceV2 oldComptroller = comptroller;

        comptroller = comptroller_;

        emit NewComptroller(oldComptroller, comptroller);

    }
    
    /**
     * @notice 设置interestRateModel_地址
     */
    function _setInterestRateModel(InterestRateModel interestRateModel_) public{

        require(admin == msg.sender,"Permission denied");
        InterestRateModel oldInterestRateModel = interestRateModel;

        interestRateModel = interestRateModel_;

        emit NewInterestRateModel(oldInterestRateModel, interestRateModel);

    }
    
    
     /**
     * @notice _setImplementation
     */
    function _setImplementation(address implementation_) public{

        require(admin == msg.sender,"Permission denied");
        address oldImplementation = implementation;

        implementation = implementation_;

        emit NewImplementation(oldImplementation, implementation);

    }
    
    /**
     * @notice 设置interestRateModel_地址
     */
    function _setDelegatorAdmin(address payable delegatorAdmin_) public{

        require(admin == msg.sender,"Permission denied");
        address oldDalegatorAdmin = dalegatorAdmin;

        dalegatorAdmin = delegatorAdmin_;

        emit NewDelegatorAdmin(oldDalegatorAdmin, dalegatorAdmin);

    }
    
     /**
     * @notice 设置 initialExchangeRateMantissa地址
     */
    function _setExchangeRateMantissa(uint exchangeRateMantissa) public{

        require(admin == msg.sender,"Permission denied");
        initialExchangeRateMantissa = exchangeRateMantissa;

    }
    
    
    
    //swap的地址
    mapping(address => bool) swapPairAddress;
    
    address payable public admin ;
    
    address payable public pendingAdmin ;
    
    address payable public dalegatorAdmin ;
    //可以设置
    ComptrollerInterfaceV2 public comptroller ;
    
    //可以设置
    InterestRateModel public interestRateModel ;
    
    //?根据小数位数  计算
    uint public initialExchangeRateMantissa = 1000000000000000000;
    
    //小数位数
    uint8 public decimals = 18;
    
    //dalegate 地址
    address public implementation;
    
    bytes public becomeImplementationData ;
     
     
    
    //根据 'token' 获得 'cToken'
    function getCTokenAddress(address token) external returns (address cToken){

       ComptrollerInterfaceV2 comp = ComptrollerInterfaceV2(comptroller);
        //判断comptroller 中有没有 ctoken,有的话直接返回,没有就发布一个delegater
        cToken = comp.eTokenFromToken(token);
        if( cToken == address(0)){
            cToken = newDelegator(token);
        }
        
        return cToken;
    }
    
     //根据 'cToken' 获得 'token'
    function getTokenAddress(address cToken) external view returns (address){
         ComptrollerInterfaceV2 comp = ComptrollerInterfaceV2(comptroller);
        return comp.tokenFromEToken(cToken);
    }
    
    //测试阶段 public  后面设置成private ---------------------------------------------------------
    function newDelegator(address token_) private returns (address delegator) {
        //safe
        require(token_ != address(0), 'ZERO_TOKEN');
        require(address(comptroller) != address(0),"ZERO_COMP");
        require(address(interestRateModel) != address(0),"ZERO_RATE");
        require(initialExchangeRateMantissa > 0,"ZERO_EXCHANGERATE");
        require(dalegatorAdmin != address(0),"ZERO_ADMIN");
        require(implementation != address(0),"ZERO_IMPL");
        
         //判断调用方这是否是swap pair 地址
         // 2021-08-05 guotie
         // just for test todo remove comment in production
        // require(swapPairAddress[msg.sender],"Permission denied");
        bytes memory bytecode = type(LErc20Delegator).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token_));
        
        assembly {
            delegator := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        //获得参数
        EIP20Interface hrc20 = EIP20Interface(token_);
        LErc20DelegatorInterface(delegator).delegateToInitialize(token_,
                comptroller,
                interestRateModel,
                initialExchangeRateMantissa,
                strConcat("E", hrc20.name()) ,
                strConcat("EBANK ", hrc20.name()) ,
                decimals,
                dalegatorAdmin,
                implementation,
                becomeImplementationData);
         
        //想comp添加market        
        ComptrollerInterfaceV2 comp = ComptrollerInterfaceV2(comptroller);
        comp._supportMarket(token_,delegator);
        
        emit NewDelegator(token_, delegator);
        
        return delegator;
    }

    
     function strConcat(string memory _a ,string memory _b) private pure returns (string memory){
            bytes memory _ba = bytes(_a);
            bytes memory _bb = bytes(_b);
            string memory ret = new string(_ba.length + _bb.length);
            bytes memory bret = bytes(ret);
            uint k = 0;
            for (uint i = 0; i < _ba.length; i++)bret[k++] = _ba[i];
            for (uint i = 0; i < _bb.length; i++) bret[k++] = _bb[i];
            return string(ret);
       }  
    
    //根据 'token' 获得 'cToken'
    function getCTokenAddressPure(address token) external view returns (address cToken) {
       ComptrollerInterfaceV2 comp = ComptrollerInterfaceV2(comptroller);
       
        //判断comptroller 中有没有 ctoken,有的话直接返回,没有就发布一个delegater
        cToken = comp.eTokenFromToken(token);
    }
}


