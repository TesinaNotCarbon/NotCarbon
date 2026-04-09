// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IProjectManager.sol";
import "./ICompanyManager.sol";

interface ICarbonCreditMarket {
    function buyFromAny(uint256 totalAmount, address payable buyer) external payable;

    function projectManager() external view returns (IProjectManager);

    function companyManager() external view returns (ICompanyManager);
}
