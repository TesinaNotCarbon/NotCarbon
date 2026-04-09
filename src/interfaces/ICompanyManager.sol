// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICompanyManager {
    function registerCompany(string memory _name, uint256 _monthlyEmissions) external;

    function approveCompany(address _company) external;

    function isApproved(address _company) external view returns (bool);
}