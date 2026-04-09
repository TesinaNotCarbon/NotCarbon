// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {CompanyManager} from "../src/CompanyManager.sol";
import {ProjectManager} from "../src/ProjectManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";
import {CarbonCreditMarket} from "../src/CarbonCreditMarket.sol";
import {Company} from "../src/Company.sol";
import {Project} from "../src/Project.sol";
import {IProject} from "../src/interfaces/IProject.sol";

abstract contract BaseTest is Test {
    address internal staff = address(0xA11CE);
    address internal outsider = address(0xBEEF);
    address internal companyOwner = address(0xC0FFEE);
    address internal buyer = address(0xB0B);
    address internal creator = address(0xCAFE);

    RoleManager internal roleManager;
    CompanyManager internal companyManager;
    ProjectManager internal projectManager;
    CarbonCreditToken internal token;
    CarbonCreditMarket internal market;

    function _deployCore() internal {
        roleManager = new RoleManager();
        companyManager = new CompanyManager(address(roleManager));
        projectManager = new ProjectManager(address(roleManager), address(companyManager));
        token = new CarbonCreditToken(address(projectManager), address(roleManager));
        market = new CarbonCreditMarket(address(projectManager), address(companyManager));

        vm.deal(staff, 100 ether);
        vm.deal(outsider, 100 ether);
        vm.deal(companyOwner, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(creator, 100 ether);
    }

    function _grantStaff(address _staff) internal {
        roleManager.addStaff(_staff);
    }

    function _bootstrapPriceAndMint(uint256 price, uint256 amount) internal {
        projectManager.setPricePerToken(price);
        token.mint(amount);
    }

    function _createCompany(address owner, string memory name, uint256 emissions) internal returns (Company) {
        vm.prank(owner);
        address companyAddress = companyManager.createCompany(name, emissions);
        return Company(payable(companyAddress));
    }

    function _approveCompany(address companyAddress, address approver) internal {
        vm.prank(approver);
        companyManager.approveCompany(payable(companyAddress));
    }

    function _registerProject(
        address projectCreator,
        string memory name,
        string memory description,
        uint256 totalTokens
    ) internal returns (Project) {
        vm.prank(projectCreator);
        address projectAddress = projectManager.registerProject(name, description, address(token), totalTokens);
        return Project(payable(projectAddress));
    }

    function _advanceToPhase4(address projectAddress) internal {
        projectManager.updateProjectStatus(projectAddress, IProject.ProjectState.Phase1);
        projectManager.updateProjectStatus(projectAddress, IProject.ProjectState.Phase2);
        projectManager.updateProjectStatus(projectAddress, IProject.ProjectState.Phase3);
        projectManager.updateProjectStatus(projectAddress, IProject.ProjectState.Phase4);
    }
}
