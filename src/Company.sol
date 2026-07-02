// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ICompanyManager} from "./interfaces/ICompanyManager.sol";
import {IProject} from "./interfaces/IProject.sol";
import {ICarbonCreditMarket} from "./interfaces/ICarbonCreditMarket.sol";
import {ICompany} from "./interfaces/ICompany.sol";

contract Company is ICompany {
    struct CompanyInfo {
        address owner;
        string name;
        uint256 monthlyEmissions;
        uint256 carbonCredits;
        bool approved;
    }

    CompanyInfo private info;
    address private companyManagerAddress;

    event CarbonCreditsPurchased(address indexed market, uint256 amount);

    constructor(address _owner, string memory _name, uint256 _monthlyEmissions, address _companyManager) {
        info.owner = _owner;
        info.name = _name;
        info.monthlyEmissions = _monthlyEmissions;
        info.carbonCredits = 0;
        companyManagerAddress = _companyManager;
    }

    function owner() public view returns (address) {
        return info.owner;
    }

    function companyManager() public view returns (address) {
        return companyManagerAddress;
    }

    function name() public view returns (string memory) {
        return info.name;
    }

    function monthlyEmissions() public view returns (uint256) {
        return info.monthlyEmissions;
    }

    function carbonCredits() public view returns (uint256) {
        return info.carbonCredits;
    }

    function approved() public view returns (bool) {
        return info.approved;
    }

    modifier onlyOwner() {
        require(msg.sender == info.owner, "Not the owner");
        _;
    }

    modifier onlyCompanyManager() {
        require(msg.sender == companyManagerAddress, "Not the company manager");
        _;
    }

    function buyFromProject(address payable projectAddress, uint256 amount) external payable override onlyOwner {
        IProject project = IProject(projectAddress);
        project.buyCarbonCredits{value: msg.value}(amount);
        info.carbonCredits += amount;
        emit CarbonCreditsPurchased(projectAddress, amount);
    }

    function buyFromMarket(address market, uint256 amount) external payable override onlyOwner {
        ICarbonCreditMarket marketContract = ICarbonCreditMarket(market);
        marketContract.buyFromAny{value: msg.value}(amount, payable(address(this)));

        info.carbonCredits += amount;
        emit CarbonCreditsPurchased(market, amount);
    }

    function approve() external override onlyCompanyManager {
        info.approved = true;
    }

    function isApproved() external view override returns (bool) {
        return info.approved;
    }

    receive() external payable {}
}
