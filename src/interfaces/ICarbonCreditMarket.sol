// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICarbonCreditMarket {
    function buyFromAny(uint256 totalAmount, address payable buyer) external payable;
    
    function projectManager() external view returns (address);
    
    function companyRegistry() external view returns (address);
}
