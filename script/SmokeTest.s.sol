// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ProjectManager} from "../src/ProjectManager.sol";
import {CompanyManager} from "../src/CompanyManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";
import {CarbonCreditMarket} from "../src/CarbonCreditMarket.sol";
import {Company} from "../src/Company.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {IProjectValidationOracle} from "../src/interfaces/IProjectValidationOracle.sol";

contract SmokeTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address projectManagerAddress = vm.envAddress("PROJECT_MANAGER_ADDRESS");
        address companyManagerAddress = vm.envAddress("COMPANY_MANAGER_ADDRESS");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address marketAddress = vm.envAddress("MARKET_ADDRESS");

        address projectAddress = vm.envOr("PROJECT_ADDRESS", address(0));
        string memory projectName = vm.envOr("PROJECT_NAME", string("SmokeProject"));
        string memory projectDescription = vm.envOr("PROJECT_DESCRIPTION", string("Smoke test project"));
        uint256 projectTotalTokens = vm.envOr("PROJECT_TOTAL_TOKENS", uint256(1000));
        string memory projectCellId = vm.envOr("PROJECT_CELL_ID", string("CELL-SMOKE-001"));

        address companyAddress = vm.envOr("COMPANY_ADDRESS", address(0));
        string memory companyName = vm.envOr("COMPANY_NAME", string("SmokeCompany"));
        uint256 companyEmissions = vm.envOr("COMPANY_MONTHLY_EMISSIONS", uint256(100));

        uint256 buyAmount = vm.envOr("BUY_AMOUNT", uint256(10));

        ProjectManager projectManager = ProjectManager(projectManagerAddress);
        CompanyManager companyManager = CompanyManager(companyManagerAddress);
        CarbonCreditToken token = CarbonCreditToken(tokenAddress);
        CarbonCreditMarket market = CarbonCreditMarket(marketAddress);

        vm.startBroadcast(deployerPrivateKey);

        if (projectAddress == address(0)) {
            projectAddress = projectManager.registerProject(
                projectName, projectDescription, address(token), projectTotalTokens, projectCellId
            );
        }

        IProject project = IProject(projectAddress);
        IProject.ProjectState currentState = project.currentState();

        if (uint256(currentState) < uint256(IProject.ProjectState.Validated)) {
            address adapter = projectManager.validationOracleAdapter();
            bool oracleConfigured =
                adapter != address(0) && IProjectValidationOracle(adapter).isConfigured();
            if (!oracleConfigured) {
                projectManager.mockValidationResult(projectAddress, false, false);
                currentState = project.currentState();
            } else {
                bytes32 requestId = projectManager.requestProjectValidation(projectAddress);
                console2.log("Validation requested:");
                console2.logBytes32(requestId);
                console2.log("Project address:", projectAddress);
                vm.stopBroadcast();
                return;
            }
        }

        _advanceIfNeeded(projectManager, projectAddress, IProject.ProjectState.Approved);
        _advanceIfNeeded(projectManager, projectAddress, IProject.ProjectState.Milestone1);
        _advanceIfNeeded(projectManager, projectAddress, IProject.ProjectState.Milestone2);
        _advanceIfNeeded(projectManager, projectAddress, IProject.ProjectState.Milestone3);
        _advanceIfNeeded(projectManager, projectAddress, IProject.ProjectState.Milestone4);

        if (companyAddress == address(0)) {
            companyAddress = companyManager.createCompany(companyName, companyEmissions);
        }
        companyManager.approveCompany(payable(companyAddress));

        uint256 price = project.pricePerToken();
        uint256 totalCost = buyAmount * price;

        Company company = Company(payable(companyAddress));
        company.buyFromMarket{value: totalCost}(address(market), buyAmount);

        vm.stopBroadcast();

        console2.log("Project:", projectAddress);
        console2.log("Company:", companyAddress);
        console2.log("BuyAmount:", buyAmount);
        console2.log("TotalCost:", totalCost);
    }

    function _advanceIfNeeded(ProjectManager projectManager, address projectAddress, IProject.ProjectState targetState)
        internal
    {
        IProject project = IProject(projectAddress);
        if (uint256(project.currentState()) < uint256(targetState)) {
            projectManager.updateProjectStatus(projectAddress, targetState);
        }
    }
}
