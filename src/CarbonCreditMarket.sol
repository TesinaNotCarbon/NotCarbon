// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IProjectManager} from "./interfaces/IProjectManager.sol";
import {ICompanyManager} from "./interfaces/ICompanyManager.sol";
import {IProject} from "./interfaces/IProject.sol";
import {ICarbonCreditMarket} from "./interfaces/ICarbonCreditMarket.sol";

contract CarbonCreditMarket is Initializable, UUPSUpgradeable, ICarbonCreditMarket {
    IProjectManager public override projectManager;
    ICompanyManager public override companyManager;
    address public upgradeController;

    event BuyFromAnyStarted(address indexed buyer, uint256 totalAmount, uint256 msgValue);
    event ProjectChecked(address indexed project, uint256 available, uint256 pricePerToken);
    event TokensPurchasedFromProject(address indexed project, address indexed buyer, uint256 amount, uint256 cost);
    event BuyFromAnyCompleted(uint256 totalSpent, uint256 refunded);

    modifier onlyUpgradeController() {
        require(msg.sender == upgradeController, "Only upgrade controller.");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _projectManager, address _companyManager, address _upgradeController)
        public
        initializer
    {
        require(_projectManager != address(0), "Invalid project manager.");
        require(_companyManager != address(0), "Invalid company manager.");
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        projectManager = IProjectManager(_projectManager);
        companyManager = ICompanyManager(_companyManager);
        upgradeController = _upgradeController;
    }

    function setUpgradeController(address _upgradeController) external onlyUpgradeController {
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        upgradeController = _upgradeController;
    }

    function buyFromAny(uint256 totalAmount, address payable buyer) external payable override {
        emit BuyFromAnyStarted(buyer, totalAmount, msg.value);

        require(companyManager.isApproved(buyer), "Company not approved");

        uint256 remaining = totalAmount;
        uint256 totalSpent = 0;

        address[] memory projects = projectManager.getAllProjects();

        for (uint256 i = 0; i < projects.length && remaining > 0; i++) {
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

        // Refund excess ETH.
        uint256 refund = 0;
        if (msg.value > totalSpent) {
            refund = msg.value - totalSpent;
            (bool ok,) = buyer.call{value: refund}("");
            require(ok, "Refund failed");
        }

        emit BuyFromAnyCompleted(totalSpent, refund);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgradeController {}

    uint256[50] private __gap;
}
