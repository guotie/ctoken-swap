pragma solidity ^0.5.16;
import "./CToken.sol";
import "./ErrorReporter.sol";
import "./PriceOracle.sol";
import "./ComptrollerInterfaceV2.sol";
import "./ComptrollerStorage.sol";
import "./Unitroller.sol";
import "./Governance/LendHub.sol";

/**
 * @title Compound's ComptrollerV2 Contract
 * @author Compound
 */
contract ComptrollerV2 is ComptrollerV5Storage, ComptrollerInterfaceV2, ComptrollerErrorReporter, ExponentialNoError {
    /// @notice Emitted when an admin supports a market
    event MarketListed(CToken cToken);
    
    /// @notice Emitted when LHB is granted by admin
    event CompGranted(address recipient, uint amount);

    /**
      * @notice set delegateFactoryAddress  ----------------------------------------------------------------需要补充 验证
      */
    function _setDelegateFactoryAddress(address  delegateFactoryAddress_) external returns (uint) {
        // Check caller = admin
        require (msg.sender == admin,"UNAUTHORIZED");
        delegateFactoryAddress = delegateFactoryAddress_;
        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Add the market to the markets mapping and set it as listed
      * @dev Admin function to set isListed and add support for the market
      * @dev cTokenAddress The address of the market (token) to list
      * @return uint 0=success, otherwise a failure. (See enum Error for details)
      */
    function _supportMarket(address token,address cTokenAddress) external returns (uint) {
        if (msg.sender != admin && msg.sender != delegateFactoryAddress) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SUPPORT_MARKET_OWNER_CHECK);
        }

        if (markets[cTokenAddress].isListed) {
            return fail(Error.MARKET_ALREADY_LISTED, FailureInfo.SUPPORT_MARKET_EXISTS);
        }
        CToken cToken = CToken(cTokenAddress);
        // --------------------修改 ---
        require(cToken.isCToken(),"its not a CToken"); // Sanity check to make sure its really a CToken
        
        //根据token查询 不能存在 cToken
        require(tokensMapping[token] == address(0),"This token had been supported");
        
        // -------------------修改borrowFactorMantissa: 0
        markets[address(cToken)] = Market({isListed: true, isComped: false, collateralFactorMantissa: 0, borrowFactorMantissa: 1000000000000000000, isLPPool: false});

        _addMarketInternal(token,address(cToken));

        emit MarketListed(cToken);

        return uint(Error.NO_ERROR);
    }
    
    //xiugai shi chang shi fou  shi  lp shi chang
    function _updateMarket(address eTokenAddress, bool isLPPool) external returns (uint) {

        if (msg.sender != admin && msg.sender != delegateFactoryAddress) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SUPPORT_MARKET_OWNER_CHECK);
        }
        Market storage market =  markets[eTokenAddress];
        if (market.isListed) {
            return fail(Error.MARKET_ALREADY_LISTED, FailureInfo.SUPPORT_MARKET_EXISTS);
        }
        market.isLPPool = isLPPool;
        
        return uint(Error.NO_ERROR);
    }
    
     /**
     * @notice Transfer LHB to the user
     * @dev Note: If there is not enough LHB, we do not perform the transfer all.
     * @param user The address of the user to transfer LHB to
     * @param amount The amount of LHB to (possibly) transfer
     * @return The amount of LHB which was NOT transferred to the user
     */
    function grantCompInternal(address user, uint amount) internal returns (uint) {
        LendHub lhb = LendHub(getCompAddress());
        uint compRemaining = lhb.balanceOf(address(this));
        if (amount <= compRemaining) {
            lhb.transfer(user, amount);
            return 0;
        }
        return amount;
    }

    /*** LHB Distribution Admin ***/

    /**
     * @notice Transfer LHB to the recipient
     * @dev Note: If there is not enough LHB, we do not perform the transfer all.
     * @param recipient The address of the recipient to transfer LHB to
     * @param amount The amount of LHB to (possibly) transfer
     */
    function _grantComp(address recipient, uint amount) public {
        require(adminOrInitializing(), "only admin can grant LHB");
        uint amountLeft = grantCompInternal(recipient, amount);
        require(amountLeft == 0, "insufficient LHB for grant");
        emit CompGranted(recipient, amount);
    }
    
    // // ?????????????????问题 -----------------------------------------------------------------------------------------------------------------------------------------------------------------allMarkets 长度会无线增加  修改了 判断结构
    function _addMarketInternal(address token,address eToken) private {
        require(eTokensMapping[eToken] == address(0), "market already added");
        
        // 存储 token -> cToken
        tokensMapping[token] = eToken;
        
        //存储 CToken -> token
        eTokensMapping[eToken] = token;
        
        //tianjia添加dao添加到添加到所有suoyou添加到所有所有添加到所有所有市场li
        allMarkets.push(CToken(eToken));
    }
    
        
    //----------------------------------------------------------------------添加
     /**
     * @notice 资产 和 ctoken绑定集合 k:cToken  v:token
     * @dev Used e.g. to determine if a market is supported
     */
     function tokenFromEToken( address eToken) external view returns (address){
         return  eTokensMapping[eToken];
     }
    
    /**
     * @notice 资产 和 ctoken绑定集合 k:token  v:cToken
     * @dev Used e.g. to determine if a market is supported
     */
    function eTokenFromToken( address token) external view returns (address){
        return tokensMapping[token];
    }
    
    /**
     * @notice 验证cToken 是否真实市场
     * @dev Used e.g. to determine if a market is supported
     */
    function isCToken( address cToken) external view returns (bool){
         if (markets[cToken].isListed) {
            return true;
        }
        return false;
    }
    
    function isLP(address eToken) external view returns (bool){
        Market storage market =  markets[eToken];
       
        return market.isLPPool;
    }
    
     function getBlockNumber() public view returns (uint) {
        return block.number;
    }

     /**
     * @notice Checks caller is admin, or this contract is becoming the new implementation
     */
    function adminOrInitializing() internal view returns (bool) {
        return msg.sender == admin ; 
    }
    
      /*** Assets You Are In ***/
    
     /**
     * @notice Returns the assets an account has entered
     * @param account The address of the account to pull assets for
     * @return A dynamic list with the assets the account has entered
     */
    function getAssetsIn(address account) external view returns (CToken[] memory) {
        CToken[] memory assetsIn = accountAssets[account];

        return assetsIn;
    }
    
   
    /**
     * @notice Returns whether the given account is entered in the given asset
     * @param account The address of the account to check
     * @param cToken The cToken to check
     * @return True if the account is in the asset, otherwise false.
     */
    function checkMembership(address account, CToken cToken) external view returns (bool) {
        return markets[address(cToken)].accountMembership[account];
    }
    
    
    /**
     * @notice Return the address of the LHB token
     * @return The address of LHB
     */
    function getCompAddress() public view returns (address) {
        return 0x8F67854497218043E1f72908FFE38D0Ed7F24721;
    }
}
