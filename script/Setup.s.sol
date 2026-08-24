// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {ProjectManager} from "../src/ProjectManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {CREValidationOracle} from "../src/oracles/CREValidationOracle.sol";
import {CREScoringOracle} from "../src/oracles/CREScoringOracle.sol";

contract Setup is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address roleManagerAddress = vm.envAddress("ROLE_MANAGER_ADDRESS");
        address projectManagerAddress = vm.envAddress("PROJECT_MANAGER_ADDRESS");
        address tokenAddress = vm.envAddress("CARBON_CREDIT_TOKEN_ADDRESS");

        address staffAddress = vm.envOr("STAFF_ADDRESS", address(0));
        uint256 pricePerToken = vm.envOr("PRICE_PER_TOKEN", uint256(10));
        uint256 mintAmount = vm.envOr("MINT_AMOUNT", uint256(10000));
        uint256 setCre = vm.envOr("SET_CRE", uint256(0));
        uint256 setScoringCre = vm.envOr("SET_SCORING_CRE", setCre);
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

        if (setCre == 1) {
            address validationOracleAdapter = vm.envAddress("VALIDATION_ORACLE_ADAPTER");
            address creForwarder = vm.envOr("CRE_FORWARDER", address(0));
            projectManager.setValidationOracleAdapter(validationOracleAdapter);
            if (creForwarder != address(0)) {
                CREValidationOracle(validationOracleAdapter).setForwarderAddress(creForwarder);
            }
            mockValidation = 0;
        }

        if (setScoringCre == 1) {
            address scoringOracleAdapter = vm.envAddress("SCORING_ORACLE_ADAPTER");
            address creForwarder = vm.envOr("CRE_FORWARDER", address(0));
            projectManager.setScoringOracleAdapter(scoringOracleAdapter);
            if (creForwarder != address(0)) {
                CREScoringOracle(scoringOracleAdapter).setForwarderAddress(creForwarder);
            }
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
        if (setCre == 1) {
            console2.log("CREValidation: enabled");
        }
        if (setScoringCre == 1) {
            console2.log("CREScoring: enabled");
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
