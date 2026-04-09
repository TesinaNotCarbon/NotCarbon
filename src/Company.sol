// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ICompanyManager.sol";
import "./interfaces/IProject.sol";
import "./interfaces/ICarbonCreditMarket.sol";
contract Company {
    address public owner;
    address public companyManager;
    string public name;
    uint256 public monthlyEmissions;
    uint256 public carbonCredits;
    bool public approved;

    event CarbonCreditsPurchased(address indexed market, uint256 amount);

    constructor(address _owner, string memory _name, uint256 _monthlyEmissions, address _companyManager) {
        owner = _owner;
        name = _name;
        monthlyEmissions = _monthlyEmissions;
        carbonCredits = 0;
        companyManager = _companyManager;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyCompanyManager() {
        require(msg.sender == companyManager, "Not the company manager");
        _;
    }

    function buyFromProject(address payable projectAddress, uint256 amount) external payable onlyOwner {
        IProject project = IProject(projectAddress);
        project.buyCarbonCredits{value: msg.value}(amount);
        carbonCredits += amount;
        emit CarbonCreditsPurchased(projectAddress, amount);
    }

    function buyFromMarket(address market, uint256 amount) external payable onlyOwner {

        ICarbonCreditMarket marketContract = ICarbonCreditMarket(market);
        marketContract.buyFromAny{value: msg.value}(amount, payable(address(this)));

        carbonCredits += amount;
        emit CarbonCreditsPurchased(market, amount);
    }

    function approve() external onlyCompanyManager {
        approved = true;
    }

    function isApproved() external view returns (bool) {
        return approved;
    }

    receive() external payable {}
}
