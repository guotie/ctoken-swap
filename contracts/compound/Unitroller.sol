pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;
import "./ErrorReporter.sol";
import "./ComptrollerStorage.sol";
/**
 * @title ComptrollerCore
 * @dev Storage for the comptroller is at this address, while execution is delegated to the `comptrollerImplementation`.
 * CTokens should reference this contract as their comptroller.
 */
contract Unitroller is UnitrollerAdminStorage, ComptrollerErrorReporter {
    
    /**
      * @notice Emitted when pendingAdmin is changed
      */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
      * @notice Emitted when pendingAdmin is accepted, which means admin is updated
      */
    event NewAdmin(address oldAdmin, address newAdmin);

    constructor() public {
        // Set admin to caller
        admin = msg.sender;
    }

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address newPendingAdmin) public returns (uint) {
        // Check caller = admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PENDING_ADMIN_OWNER_CHECK);
        }

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() public returns (uint) {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        if (msg.sender != pendingAdmin || msg.sender == address(0)) {
            return fail(Error.UNAUTHORIZED, FailureInfo.ACCEPT_ADMIN_PENDING_ADMIN_CHECK);
        }

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);

        return uint(Error.NO_ERROR);
    }

     /**
      * @notice 设置methodid 和 实现地址的 索引
      */
    function _setMethodId(bytes[] memory methodArray , uint[] memory implementationArray) public returns (uint) {

        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PENDING_IMPLEMENTATION_OWNER_CHECK);
        }
        
        //长度必须一致
        require(methodArray.length > 0 && methodArray.length == implementationArray.length,"Inconsistent length");
        
        //存储methodId -> implementation 索引
        for(uint i = 0; i < methodArray.length; i++){
            methodImplements[methodArray[i]] = implementationArray[i];
        }
        
        return uint(Error.NO_ERROR);
    }
    
    
    /**
      * @notice 设置实现地址 implementation 
      */
    function _setImplementation(uint index , address implementation) public returns (uint) {

        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PENDING_IMPLEMENTATION_OWNER_CHECK);
        }
        
        //设置成功
        implementsMapping[index] = implementation;
        
        return uint(Error.NO_ERROR);
    }
    
    /**
      * @notice 设置实现地址 _setDelegateFactoryAddress 
      */
    function _setDelegateFactoryAddress(address _delegateFactoryAddress) public returns (uint) {

        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PENDING_IMPLEMENTATION_OWNER_CHECK);
        }
        
        //设置成功
        delegateFactoryAddress = _delegateFactoryAddress;
        
        return uint(Error.NO_ERROR);
    }
    
    
    /**
      * @notice 获取前十个字节
      */
    function strSlice(bytes memory val) public pure returns (bytes memory){
            bytes memory _val = val;
            bytes memory bret = new bytes(4);
            if(_val.length >= 4 ){
                 for (uint i = 0; i < 4; i++)bret[i] = _val[i];
            }
            return bret;
       } 
    
    /**
     * @dev Delegates execution to an implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    function () payable external {
        //解析msg.data 获得方法的methodId
        bytes memory methodId = strSlice(msg.data);
        
        //根据methodId 查询 implementation 索引
        uint implementationKey = methodImplements[methodId];
        
        //根据索引查询 implementation地址
        address implementation = implementsMapping[implementationKey];
        
        require(implementation != address(0),"invalid implementation");
        
        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);

        assembly {
              let free_mem_ptr := mload(0x40)
              returndatacopy(free_mem_ptr, 0, returndatasize)

              switch success
              case 0 { revert(free_mem_ptr, returndatasize) }
              default { return(free_mem_ptr, returndatasize) }
        }
    }
}
