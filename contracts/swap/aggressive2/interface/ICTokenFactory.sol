// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;


interface ICTokenFactory {
    // 根据 token 地址获取对应的 ctoken 地址
    function getCTokenAddressPure(address token) external view returns (address);

    // 根据 ctoken 地址获取对应的 token 地址
    function getTokenAddress(address cToken) external view returns (address);
}
