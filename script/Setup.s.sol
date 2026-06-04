// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {ProjectManager} from "../src/ProjectManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {ChainlinkValidationOracle} from "../src/oracles/ChainlinkValidationOracle.sol";

contract Setup is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address roleManagerAddress = vm.envAddress("ROLE_MANAGER_ADDRESS");
        address projectManagerAddress = vm.envAddress("PROJECT_MANAGER_ADDRESS");
        address tokenAddress = vm.envAddress("CARBON_CREDIT_TOKEN_ADDRESS");

        address staffAddress = vm.envOr("STAFF_ADDRESS", address(0));
        uint256 pricePerToken = vm.envOr("PRICE_PER_TOKEN", uint256(10));
        uint256 mintAmount = vm.envOr("MINT_AMOUNT", uint256(10000));
        uint256 setChainlink = vm.envOr("SET_CHAINLINK", uint256(0));
        uint256 setupProjects = vm.envOr("SETUP_PROJECTS", uint256(1));
        uint256 mockValidation = vm.envOr("MOCK_VALIDATION", uint256(1));
        uint256 advanceProject2 = vm.envOr("ADVANCE_PROJECT2", uint256(1));

        string memory project1Name = vm.envOr("PROJECT1_NAME", string("Reforestacion A"));
        string memory project1Description = vm.envOr("PROJECT1_DESCRIPTION", string("Proyecto inicial"));
        uint256 project1Tokens = vm.envOr("PROJECT1_TOKENS", uint256(1000));
        string memory project1CellId = vm.envOr("PROJECT1_CELL_ID", string("cell-1"));

        string memory project2Name = vm.envOr("PROJECT2_NAME", string("Eolico B"));
        string memory project2Description = vm.envOr("PROJECT2_DESCRIPTION", string("Proyecto en fase 1"));
        uint256 project2Tokens = vm.envOr("PROJECT2_TOKENS", uint256(2000));
        string memory project2CellId = vm.envOr("PROJECT2_CELL_ID", string("cell-2"));

        RoleManager roleManager = RoleManager(roleManagerAddress);
        ProjectManager projectManager = ProjectManager(projectManagerAddress);
        CarbonCreditToken token = CarbonCreditToken(tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        if (staffAddress != address(0) && !roleManager.isStaff(staffAddress)) {
            roleManager.addStaff(staffAddress);
        }

        projectManager.setPricePerToken(pricePerToken);

        if (setupProjects == 1) {
            uint256 requiredMint = project1Tokens + project2Tokens;
            if (mintAmount < requiredMint) {
                mintAmount = requiredMint;
            }
        }

        if (mintAmount > 0) {
            token.mint(mintAmount);
        }

        if (setChainlink == 1) {
            address validationOracleAdapter = vm.envAddress("VALIDATION_ORACLE_ADAPTER");
            address creForwarder = vm.envAddress("CRE_FORWARDER");
            address workflowOwner = vm.envAddress("CRE_WORKFLOW_OWNER");
            bytes10 workflowName = bytes10(vm.envBytes32("CRE_WORKFLOW_NAME"));
            bytes2 reportName = bytes2(vm.envBytes32("CRE_REPORT_NAME"));

            projectManager.setValidationOracleAdapter(validationOracleAdapter);

            ChainlinkValidationOracle oracle = ChainlinkValidationOracle(validationOracleAdapter);
            ChainlinkValidationOracle.Permission[] memory permissions =
                new ChainlinkValidationOracle.Permission[](1);
            permissions[0] = ChainlinkValidationOracle.Permission({
                forwarder: creForwarder,
                workflowName: workflowName,
                reportName: reportName,
                workflowOwner: workflowOwner,
                isAllowed: true
            });
            oracle.setReportPermissions(permissions);
            mockValidation = 0;
        }

        address project1Address = address(0);
        address project2Address = address(0);

        if (setupProjects == 1) {
            project1Address = projectManager.registerProject(
                project1Name, project1Description, tokenAddress, project1Tokens, project1CellId
            );
            project2Address = projectManager.registerProject(
                project2Name, project2Description, tokenAddress, project2Tokens, project2CellId
            );

            if (advanceProject2 == 1 && mockValidation == 1) {
                projectManager.mockValidationResult(project2Address, false, false);
                projectManager.updateProjectStatus(project2Address, IProject.ProjectState.Approved);
                projectManager.updateProjectStatus(project2Address, IProject.ProjectState.Milestone1);
            }
        }

        vm.stopBroadcast();

        console2.log("RoleManager:", roleManagerAddress);
        console2.log("ProjectManager:", projectManagerAddress);
        console2.log("Token:", tokenAddress);
        if (staffAddress != address(0)) {
            console2.log("StaffAdded:", staffAddress);
        }
        console2.log("PricePerToken:", pricePerToken);
        console2.log("MintAmount:", mintAmount);
        if (setChainlink == 1) {
            console2.log("CREConfig: enabled");
        }
        if (setupProjects == 1) {
            console2.log("Project1:", project1Address);
            console2.log("Project2:", project2Address);
            if (advanceProject2 == 1 && mockValidation == 1) {
                console2.log("Project2State: Milestone1");
            } else if (advanceProject2 == 1) {
                console2.log("Project2State: advance skipped (needs validation)");
            }
        }
    }
}
