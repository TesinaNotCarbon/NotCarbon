// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";

contract CarbonCreditTokenTest is Test {
    RoleManager internal roleManager;
    CarbonCreditToken internal token;

    address internal projectManager = address(this);
    address internal staff = address(0xA11CE);
    address internal outsider = address(0xBEEF);
    address internal alice = address(0xAAA1);
    address internal bob = address(0xBBB1);
    address internal spender = address(0xCCC1);

    event TokensMinted(address indexed to, uint256 amount);

    function setUp() public {
        roleManager = new RoleManager();
        token = new CarbonCreditToken(projectManager, address(roleManager));
    }

    function test_constructor_setsCoreValues() public view {
        assertEq(token.admin(), address(this));
        assertEq(token.projectManager(), projectManager);
        assertEq(address(token.roleManager()), address(roleManager));
        assertEq(token.name(), "CarbonCreditToken");
        assertEq(token.symbol(), "CCT");
    }

    function test_mint_byAdmin() public {
        vm.expectEmit(true, false, false, true);
        emit TokensMinted(address(token), 1000);

        token.mint(1000);

        assertEq(token.balanceOf(address(token)), 1000);
        assertEq(token.totalSupply(), 1000);
    }

    function test_mint_byStaff() public {
        roleManager.addStaff(staff);

        vm.prank(staff);
        token.mint(500);

        assertEq(token.balanceOf(address(token)), 500);
    }

    function test_mint_revertsForUnauthorized() public {
        vm.prank(outsider);
        vm.expectRevert("Only staff or admin can execute this function.");
        token.mint(1000);
    }

    function test_transferTokens_revertsForNonProjectManager() public {
        token.mint(1000);

        vm.prank(outsider);
        vm.expectRevert("Only the project manager can execute this function.");
        token.transferTokens(alice, 100);
    }

    function test_transferTokens_revertsForInsufficientContractBalance() public {
        vm.expectRevert("Insufficient token balance in contract");
        token.transferTokens(alice, 1);
    }

    function test_transferTokens_success() public {
        token.mint(1000);

        token.transferTokens(alice, 250);

        assertEq(token.balanceOf(address(token)), 750);
        assertEq(token.balanceOf(alice), 250);
    }

    function test_burn_reducesBalanceAndSupply() public {
        token.mint(1000);
        token.transferTokens(alice, 300);

        vm.prank(alice);
        token.burn(100);

        assertEq(token.balanceOf(alice), 200);
        assertEq(token.totalSupply(), 900);
    }

    function test_transfer_worksAsERC20() public {
        token.mint(1000);
        token.transferTokens(alice, 300);

        vm.prank(alice);
        bool ok = token.transfer(bob, 120);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 180);
        assertEq(token.balanceOf(bob), 120);
    }

    function test_transferFrom_worksAsERC20() public {
        token.mint(1000);
        token.transferTokens(alice, 300);

        vm.prank(alice);
        token.approve(spender, 200);

        vm.prank(spender);
        bool ok = token.transferFrom(alice, bob, 150);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 150);
        assertEq(token.balanceOf(bob), 150);
        assertEq(token.allowance(alice, spender), 50);
    }
}
