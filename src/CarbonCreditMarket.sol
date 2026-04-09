// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ProjectManager.sol";
import "./interfaces/ICompanyManager.sol";
import "./interfaces/IProject.sol";

contract CarbonCreditMarket {
    ProjectManager public projectManager;
    ICompanyManager public companyManager;

    event BuyFromAnyStarted(address indexed buyer, uint256 totalAmount, uint256 msgValue);
    event ProjectChecked(address indexed project, uint256 available, uint256 pricePerToken);
    event TokensPurchasedFromProject(address indexed project, address indexed buyer, uint256 amount, uint256 cost);
    event BuyFromAnyCompleted(uint256 totalSpent, uint256 refunded);

    constructor(address _projectManager, address _companyManager) {
        projectManager = ProjectManager(_projectManager);
        companyManager = ICompanyManager(_companyManager);
    }

    function buyFromAny(uint256 totalAmount, address payable buyer) public payable {
        emit BuyFromAnyStarted(buyer, totalAmount, msg.value);
        
        require(companyManager.isApproved(buyer), "Company not approved");

        uint256 remaining = totalAmount;
        uint256 totalSpent = 0;

        address[] memory projects = projectManager.getAllProjects();

        for (uint i = 0; i < projects.length && remaining > 0; i++) {
            IProject p = IProject(projects[i]);

            uint256 available = p.getAvailableTokens();
            uint256 price = p.pricePerToken();
            emit ProjectChecked(projects[i], available, price);

            if (available > 0) {
                uint256 toBuy = available >= remaining ? remaining : available;
                uint256 cost = toBuy * price;

                require(msg.value >= totalSpent + cost, "Insufficient ETH");

                p.buyFor{value: cost}(buyer, toBuy);
                emit TokensPurchasedFromProject(projects[i], buyer, toBuy, cost);

                remaining -= toBuy;
                totalSpent += cost;
            }
        }
        
        require(remaining == 0, "Could not complete purchase with available projects");

        // Devolver ETH sobrante
        uint256 refund = 0;
        if (msg.value > totalSpent) {
            refund = msg.value - totalSpent;
            buyer.transfer(refund);
        }
        
        emit BuyFromAnyCompleted(totalSpent, refund);
    }
}
