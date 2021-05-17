// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "../common/LErc20DelegatorInterface.sol";
import "./LErc20Delegator.sol";
import "./EIP20Interface.sol";

import "hardhat/console.sol";

contract LErc20DelegatorFactory is LErc20DelegatorInterface {
    
    event NewDelegator(address token,address delegator);
    bytes32 public initCodeHash;

    /**
     * @notice Construct
     */
    constructor(address _implementation, address comptroller_, address intersetRateModel) {
        // Creator of the contract is admin during initialization
        admin_ = msg.sender;
        comptroller = ComptrollerInterface(comptroller_);
        implementation_ = _implementation;
        interestRateModel_ = InterestRateModel(intersetRateModel);
        initCodeHash = keccak256(abi.encodePacked(type(LErc20Delegator).creationCode));

        // bytes32 0x71a762e9b044ae662a0d792ceaa9aaa4bf09c9ecdd90967035ae11e75f841390
        console.logBytes32(initCodeHash);
    }
    
    //可以设置
    ComptrollerInterface public comptroller; // = ComptrollerInterface(0x07D7654836ee31D5Dc20c1Ee9716CCF240fC7BD2);
    //可以设置
    InterestRateModel public interestRateModel_; // = InterestRateModel(0x5f75DEB780493f57A82283aDc1Def47de8873E50);
    //?根据小数位数  计算
    uint initialExchangeRateMantissa_ = 20000000000000000000;
    uint8 public decimals_ = 18;
    address payable admin_ = 0x78A3970a965d347AD83c8350ab49eBFa62aC2Dc5;
    // delegate 地址
    address implementation_; // = 0x98872083585Cd54f6dfc2dB9894C5C1B816C3A55;
    //comptroller_ 地址
    bytes  becomeImplementationData ;
    //模拟
     mapping (address => address) public tokenKeyMapping;
     mapping (address => address) public cTokenKeyMapping;
    
    //根据 'token' 获得 'cToken'
    function getCTokenAddress(address token) override external returns (address cToken){
        //判断调用方这是否是swap pair 地址
        cToken =  tokenKeyMapping[token];
        //判断comptroller 中有没有 ctoken,有的话直接返回
        if(cToken == address(0)){
            cToken = newDelegator(token);
            console.log('ctoken of %s not exist, create it: %s', token, cToken);
        }
        //没有 则创建并返回
        return cToken;
    }
    
    // 只读 如果不存在 返回 0
    function getCTokenAddressPure(address token) override external view returns (address) {
        return tokenKeyMapping[token];
    }

    function getTokenAddress(address cToken) override external view returns (address) {
        return cTokenKeyMapping[cToken];
    }
    
    function newDelegator(address token_) public returns (address delegator) {
        require(token_ != address(0), 'ZERO_ADDRESS');
        
       // require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(LErc20Delegator).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token_));
        // console.logBytes32('salt:', salt);
        // console.logBytes(bytecode);
        assembly {
            delegator := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        // console.log('delegator:', delegator);
        //获得参数
        EIP20Interface hrc20 = EIP20Interface(token_);
        LErc20DelegatorInterface(delegator).delegateToInitialize(token_,
                comptroller,
                interestRateModel_,
                initialExchangeRateMantissa_,
                strConcat("L", hrc20.name()) ,
                strConcat("L",hrc20.symbol()) ,
                decimals_,
                admin_,
                implementation_,
                becomeImplementationData);

        addNewCToken(token_, delegator);
        // bytes4(keccak256(bytes('_supportMarket(address)')))
        address(comptroller).call(abi.encodeWithSelector(bytes4(keccak256(bytes('_supportMarket(address)'))), delegator));
        emit NewDelegator(token_, address(delegator));
        return delegator;
    }
    
    //像comportable 添加新币 对应关系
    function addNewCToken(address token,address cToken) private returns (uint){
        //包含两个币互相对应关系
        tokenKeyMapping[token] = cToken;
        cTokenKeyMapping[cToken] = token;
    }
    
     function strConcat(string memory _a ,string memory _b) public view returns (string memory){
            bytes memory _ba = bytes(_a);
            bytes memory _bb = bytes(_b);
            string memory ret = new string(_ba.length + _bb.length);
            bytes memory bret = bytes(ret);
            uint k = 0;
            for (uint i = 0; i < _ba.length; i++)bret[k++] = _ba[i];
            for (uint i = 0; i < _bb.length; i++) bret[k++] = _bb[i];
            return string(ret);
       }  

}


