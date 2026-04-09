// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICompanyManager {
    function createCompany(string memory _name, uint256 _monthlyEmissions) external returns (address);

    function approveCompany(address payable _companyAddress) external;

    function isApproved(address payable _companyAddress) external view returns (bool);

    function getAllCompanies() external view returns (address[] memory);
}