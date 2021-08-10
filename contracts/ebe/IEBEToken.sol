// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.5.16;

interface IEBEToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function mint(address _to, uint256 _amount) external returns (bool);
    // function reward(uint256 ebePerBlock) external view returns (uint256);
    function reward(uint256 ebePerBlock, uint256 blockNumber) external view returns (uint256);
    function getEbeReward(uint256 ebePerBlock, uint256 _lastRewardBlock) external view returns (uint256);
}
