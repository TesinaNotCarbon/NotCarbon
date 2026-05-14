// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";
import {ICompanyManager} from "./interfaces/ICompanyManager.sol";
import {Company} from "./Company.sol";

contract CompanyManager is Initializable, UUPSUpgradeable, ICompanyManager {
    mapping(address => bool) public registeredCompanies;
    address[] public companyList;
    IRoleManager public roleManager;
    address public upgradeController;

    event CompanyCreated(address indexed owner, address companyContract, string name);
    event CompanyApproved(address indexed companyContract);

    modifier onlyApprover() {
        require(roleManager.isStaffOrAdmin(msg.sender), "Only staff or admin can execute this action.");
        _;
    }

    modifier onlyUpgradeController() {
        require(msg.sender == upgradeController, "Only upgrade controller.");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _roleManagerAddress, address _upgradeController) public initializer {
        require(_roleManagerAddress != address(0), "Invalid role manager.");
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        roleManager = IRoleManager(_roleManagerAddress);
        upgradeController = _upgradeController;
    }

    function setUpgradeController(address _upgradeController) external onlyUpgradeController {
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        upgradeController = _upgradeController;
    }

    function createCompany(string memory _name, uint256 _monthlyEmissions) public override returns (address) {
        Company company = new Company(msg.sender, _name, _monthlyEmissions, address(this));
        address contractAddr = address(company);

        registeredCompanies[contractAddr] = true;
        companyList.push(contractAddr);

        emit CompanyCreated(msg.sender, contractAddr, _name);
        return contractAddr;
    }

    function approveCompany(address payable _companyAddress) public override onlyApprover {
        require(registeredCompanies[_companyAddress], "Company not registered.");
        Company company = Company(_companyAddress);
        company.approve();
        emit CompanyApproved(_companyAddress);
    }

    function isApproved(address payable _companyAddress) external view override returns (bool) {
        require(registeredCompanies[_companyAddress], "Company not registered.");
        Company company = Company(_companyAddress);
        return company.isApproved();
    }

    function getAllCompanies() public view override returns (address[] memory) {
        return companyList;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgradeController {}

    uint256[50] private __gap;
}
