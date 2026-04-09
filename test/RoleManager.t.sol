// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {RoleManager} from "../src/RoleManager.sol";

contract RoleManagerTest is Test {
    RoleManager public roleManager;
    address public staffMember = address(0xBEEF);
    address public outsider = address(0xABCD);

    event StaffAdded(address indexed staffMember);
    event StaffRemoved(address indexed staffMember);

    function setUp() public {
        roleManager = new RoleManager();
    }

    function test_adminIsDeployer() public view {
        assertEq(roleManager.admin(), address(this));
    }

    function test_addStaff_byAdmin() public {
        roleManager.addStaff(staffMember);
        assertTrue(roleManager.isStaff(staffMember));
    }

    function test_addStaff_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit StaffAdded(staffMember);

        roleManager.addStaff(staffMember);
    }

    function test_addStaff_revertsForNonAdmin() public {
        vm.prank(outsider);
        vm.expectRevert("Solo el administrador puede ejecutar esta accion");
        roleManager.addStaff(staffMember);
    }

    function test_addStaff_revertsIfAlreadyStaff() public {
        roleManager.addStaff(staffMember);

        vm.expectRevert("Este usuario ya es staff");
        roleManager.addStaff(staffMember);
    }

    function test_removeStaff_byAdmin() public {
        roleManager.addStaff(staffMember);
        roleManager.removeStaff(staffMember);

        assertFalse(roleManager.isStaff(staffMember));
    }

    function test_removeStaff_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit StaffRemoved(staffMember);

        roleManager.removeStaff(staffMember);
    }

    function test_removeStaff_revertsForNonAdmin() public {
        vm.prank(outsider);
        vm.expectRevert("Solo el administrador puede ejecutar esta accion");
        roleManager.removeStaff(staffMember);
    }

    function test_isStaffOrAdmin_checksAllCases() public {
        roleManager.addStaff(staffMember);

        assertTrue(roleManager.isStaffOrAdmin(address(this)));
        assertTrue(roleManager.isStaffOrAdmin(staffMember));
        assertFalse(roleManager.isStaffOrAdmin(outsider));
    }
}
