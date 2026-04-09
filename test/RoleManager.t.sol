// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {RoleManager} from "../src/RoleManager.sol";

contract RoleManagerTest is Test {
    RoleManager public roleManager;

    function setUp() public {
        roleManager = new RoleManager();
    }

    function test_AdminIsDeployer() public {
        assertEq(roleManager.admin(), address(this));
    }

    function test_AddStaff() public {
        address staffMember = address(0xBEEF);
        roleManager.addStaff(staffMember);
        assertTrue(roleManager.isStaff(staffMember));
    }
}
