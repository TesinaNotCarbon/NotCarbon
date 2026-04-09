// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IRoleManager.sol";
import "./Company.sol";
contract CompanyManager {

    mapping(address => bool) public registeredCompanies;
    address[] public companyList;
    IRoleManager public roleManager;

    event CompanyCreated(address indexed owner, address companyContract, string name);
    event CompanyApproved(address indexed companyContract);

    modifier onlyApprover() {
        require(roleManager.isStaffOrAdmin(msg.sender), "No tenes permiso");
        _;
    }

    constructor(address _roleManagerAddress) {
        roleManager = IRoleManager(_roleManagerAddress);
    }

    function createCompany(string memory _name, uint256 _monthlyEmissions) public returns (address) {
        Company company = new Company(msg.sender, _name, _monthlyEmissions, address(this));
        address contractAddr = address(company);

        registeredCompanies[contractAddr] = true;
        companyList.push(contractAddr);

        emit CompanyCreated(msg.sender, contractAddr, _name);
        return contractAddr;
    }

    function approveCompany(address payable _companyAddress) public onlyApprover {
        require(registeredCompanies[_companyAddress], "Empresa no registrada");
        Company company = Company(_companyAddress);
        company.approve();
        emit CompanyApproved(_companyAddress);
    }

    function isApproved(address payable _companyAddress) external view returns (bool) {
        Company company = Company(_companyAddress);
        return company.isApproved();
    }

    function getAllCompanies() public view returns (address[] memory) {
        return companyList;
    }
}
