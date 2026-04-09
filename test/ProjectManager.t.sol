// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ProjectManager} from "../src/ProjectManager.sol";
import {Project} from "../src/Project.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {BaseTest} from "./Base.t.sol";

contract ProjectManagerTest is BaseTest {
    event ProjectRegistered(address indexed projectAddress, string name, string description, address creator);
    event ProjectStateUpdated(address indexed projectAddress, IProject.ProjectState newState);

    function setUp() public {
        _deployCore();
    }

    function test_setPricePerToken_revertsForUnauthorized() public {
        vm.prank(outsider);
        vm.expectRevert("Only staff or admin can execute this function.");
        projectManager.setPricePerToken(1 ether);
    }

    function test_setPricePerToken_byStaff() public {
        _grantStaff(staff);

        vm.prank(staff);
        projectManager.setPricePerToken(1 ether);

        token.mint(1000);
        Project project = _registerProject(creator, "Solar", "Solar farm", 1000);

        assertEq(project.pricePerToken(), 1 ether);
    }

    function test_registerProject_revertsWhenTokenPoolInsufficient() public {
        projectManager.setPricePerToken(1 ether);

        vm.prank(creator);
        vm.expectRevert("Insufficient token balance in contract");
        projectManager.registerProject("Solar", "Solar farm", address(token), 1000);
    }

    function test_registerProject_success() public {
        _bootstrapPriceAndMint(2 ether, 2000);

        vm.prank(creator);
        address projectAddress = projectManager.registerProject("Solar", "Solar farm", address(token), 500);

        assertTrue(projectManager.isProjectRegistered(projectAddress));

        address[] memory projects = projectManager.getAllProjects();
        assertEq(projects.length, 1);
        assertEq(projects[0], projectAddress);

        Project project = Project(payable(projectAddress));
        assertEq(project.getCreator(), creator);
        assertEq(project.pricePerToken(), 2 ether);
        assertEq(token.balanceOf(projectAddress), 500);
    }

    function test_updateProjectStatus_revertsForUnauthorized() public {
        _bootstrapPriceAndMint(1 ether, 1000);
        Project project = _registerProject(creator, "Solar", "Solar farm", 200);

        vm.prank(outsider);
        vm.expectRevert("Only staff or admin can execute this function.");
        projectManager.updateProjectStatus(address(project), IProject.ProjectState.Phase1);
    }

    function test_updateProjectStatus_revertsForUnregisteredProject() public {
        vm.expectRevert("Project is not registered.");
        projectManager.updateProjectStatus(address(0x1234), IProject.ProjectState.Phase1);
    }

    function test_updateProjectStatus_successByAdmin() public {
        _bootstrapPriceAndMint(1 ether, 1000);
        Project project = _registerProject(creator, "Solar", "Solar farm", 200);

        vm.expectEmit(true, false, false, true);
        emit ProjectStateUpdated(address(project), IProject.ProjectState.Phase1);
        projectManager.updateProjectStatus(address(project), IProject.ProjectState.Phase1);

        assertEq(uint256(project.currentState()), uint256(IProject.ProjectState.Phase1));
    }
}
