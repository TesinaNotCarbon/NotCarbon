// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {CompanyManager} from "../src/CompanyManager.sol";
import {Company} from "../src/Company.sol";
import {BaseTest} from "./Base.t.sol";

contract CompanyManagerTest is BaseTest {
    event CompanyCreated(address indexed owner, address companyContract, string name);
    event CompanyApproved(address indexed companyContract);

    function setUp() public {
        _deployCore();
    }

    function test_createCompany_registersAndStores() public {
        vm.prank(companyOwner);
        address companyAddress = companyManager.createCompany("Acme", 150);

        assertTrue(companyManager.registeredCompanies(companyAddress));

        address[] memory companies = companyManager.getAllCompanies();
        assertEq(companies.length, 1);
        assertEq(companies[0], companyAddress);

        Company company = Company(payable(companyAddress));
        assertEq(company.owner(), companyOwner);
        assertEq(company.monthlyEmissions(), 150);
        assertEq(company.name(), "Acme");
    }

    function test_createCompany_emitsEvent() public {
        vm.prank(companyOwner);

        vm.expectEmit(true, false, false, false);
        emit CompanyCreated(companyOwner, address(0), "");
        address companyAddress = companyManager.createCompany("Acme", 150);

        assertTrue(companyAddress != address(0));
    }

    function test_approveCompany_revertsForNonApprover() public {
        vm.prank(companyOwner);
        address companyAddress = companyManager.createCompany("Acme", 150);

        vm.prank(outsider);
        vm.expectRevert("No tenes permiso");
        companyManager.approveCompany(payable(companyAddress));
    }

    function test_approveCompany_revertsIfNotRegistered() public {
        vm.expectRevert("Empresa no registrada");
        companyManager.approveCompany(payable(address(0x1234)));
    }

    function test_approveCompany_byAdmin() public {
        vm.prank(companyOwner);
        address companyAddress = companyManager.createCompany("Acme", 150);

        companyManager.approveCompany(payable(companyAddress));

        assertTrue(companyManager.isApproved(payable(companyAddress)));
    }

    function test_approveCompany_byStaff() public {
        _grantStaff(staff);

        vm.prank(companyOwner);
        address companyAddress = companyManager.createCompany("Acme", 150);

        vm.prank(staff);
        companyManager.approveCompany(payable(companyAddress));

        assertTrue(companyManager.isApproved(payable(companyAddress)));
    }

    function test_approveCompany_emitsEvent() public {
        vm.prank(companyOwner);
        address companyAddress = companyManager.createCompany("Acme", 150);

        vm.expectEmit(true, false, false, true);
        emit CompanyApproved(companyAddress);

        companyManager.approveCompany(payable(companyAddress));
    }

    function test_isApproved_revertsIfNotRegistered() public {
        vm.expectRevert("Empresa no registrada");
        companyManager.isApproved(payable(address(0x1234)));
    }
}
