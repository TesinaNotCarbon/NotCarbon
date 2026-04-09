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

        Project p1 = _registerProject(creator, "P1", "Forest restoration", 100);
        Project p2 = _registerProject(creator, "P2", "Wind expansion", 100);

        _advanceToPhase4(address(p1));
        _advanceToPhase4(address(p2));

        vm.prank(companyOwner);
        company.buyFromMarket{value: 10 ether}(address(market), 10);

        assertEq(company.carbonCredits(), 10);
        assertEq(token.balanceOf(address(company)), 10);
    }
}
