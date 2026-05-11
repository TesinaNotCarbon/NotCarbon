// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {BaseTest} from "./Base.t.sol";
import {Company} from "../src/Company.sol";
import {Project} from "../src/Project.sol";

contract IntegrationFlowTest is BaseTest {
    function setUp() public {
        _deployCore();
    }

    function test_endToEnd_companyBuysFromMarket() public {
        _grantStaff(staff);
        _bootstrapPriceAndMint(1 ether, 10_000);

        Company company = _createCompany(companyOwner, "Acme", 100);
        _approveCompany(address(company), address(this));

        Project p1 = _registerProject(creator, "P1", "Forest restoration", 100, "CELL-001");
        Project p2 = _registerProject(creator, "P2", "Wind expansion", 100, "CELL-002");

        _advanceToMilestone4(address(p1));
        _advanceToMilestone4(address(p2));

        string[] memory approvedCellIds = projectManager.getApprovedCellIds();
        assertEq(approvedCellIds.length, 2);
        assertEq(approvedCellIds[0], "CELL-001");
        assertEq(approvedCellIds[1], "CELL-002");
        assertTrue(projectManager.isApprovedCellId("CELL-001"));
        assertTrue(projectManager.isApprovedCellId("CELL-002"));

        vm.prank(companyOwner);
        company.buyFromMarket{value: 10 ether}(address(market), 10);

        assertEq(company.carbonCredits(), 10);
        assertEq(token.balanceOf(address(company)), 10);
    }
}
