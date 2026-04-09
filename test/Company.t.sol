// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Company} from "../src/Company.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {ICarbonCreditMarket} from "../src/interfaces/ICarbonCreditMarket.sol";
import {IProjectManager} from "../src/interfaces/IProjectManager.sol";
import {ICompanyManager} from "../src/interfaces/ICompanyManager.sol";

contract MockCompanyProject is IProject {
    uint256 public lastAmount;
    uint256 public lastValue;

    function buyCarbonCredits(uint256 _amount) external payable override {
        lastAmount = _amount;
        lastValue = msg.value;
    }

    function buyFor(address, uint256) external payable override {}
    function getReleasedTokens() external pure override returns (uint256) { return 0; }
    function pricePerToken() external pure override returns (uint256) { return 0; }
    function currentState() external pure override returns (ProjectState) { return ProjectState.Phase0; }
    function projectName() external pure override returns (string memory) { return ""; }
    function projectDescription() external pure override returns (string memory) { return ""; }
    function getAvailableTokens() external pure override returns (uint256) { return 0; }
}

contract MockProjectManagerForCompany is IProjectManager {
    function registerProject(string memory, string memory, address, uint256) external pure override returns (address) {
        return address(0);
    }

    function updateProjectStatus(address, IProject.ProjectState) external pure override {}
    function isProjectRegistered(address) external pure override returns (bool) { return false; }
    function setPricePerToken(uint256) external pure override {}
    function getAllProjects() external pure override returns (address[] memory) {
        address[] memory p = new address[](0);
        return p;
    }
}

contract MockCompanyManagerForCompany is ICompanyManager {
    function createCompany(string memory, uint256) external pure override returns (address) {
        return address(0);
    }

    function approveCompany(address payable) external pure override {}
    function isApproved(address payable) external pure override returns (bool) { return true; }
    function getAllCompanies() external pure override returns (address[] memory) {
        address[] memory c = new address[](0);
        return c;
    }
}

contract MockCompanyMarket is ICarbonCreditMarket {
    uint256 public lastAmount;
    address public lastBuyer;
    uint256 public lastValue;

    IProjectManager internal pm;
    ICompanyManager internal cm;

    constructor() {
        pm = new MockProjectManagerForCompany();
        cm = new MockCompanyManagerForCompany();
    }

    function buyFromAny(uint256 totalAmount, address payable buyer) external payable override {
        lastAmount = totalAmount;
        lastBuyer = buyer;
        lastValue = msg.value;
    }

    function projectManager() external view override returns (IProjectManager) {
        return pm;
    }

    function companyManager() external view override returns (ICompanyManager) {
        return cm;
    }
}

contract CompanyTest is Test {
    Company internal company;
    MockCompanyProject internal project;
    MockCompanyMarket internal market;

    address internal owner = address(0xA11CE);
    address internal manager = address(this);
    address internal outsider = address(0xBEEF);
    address internal payer = address(0xCAFE);

    event CarbonCreditsPurchased(address indexed market, uint256 amount);

    receive() external payable {}

    function setUp() public {
        company = new Company(owner, "Green Corp", 100, manager);
        project = new MockCompanyProject();
        market = new MockCompanyMarket();

        vm.deal(owner, 100 ether);
        vm.deal(payer, 100 ether);
    }

    function test_constructor_initializesValues() public view {
        assertEq(company.owner(), owner);
        assertEq(company.companyManager(), manager);
        assertEq(company.name(), "Green Corp");
        assertEq(company.monthlyEmissions(), 100);
        assertEq(company.carbonCredits(), 0);
        assertFalse(company.approved());
    }

    function test_buyFromProject_revertsForNonOwner() public {
        vm.prank(outsider);
        vm.expectRevert("Not the owner");
        company.buyFromProject(payable(address(project)), 10);
    }

    function test_buyFromProject_success() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit CarbonCreditsPurchased(address(project), 10);
        company.buyFromProject{value: 2 ether}(payable(address(project)), 10);

        assertEq(project.lastAmount(), 10);
        assertEq(project.lastValue(), 2 ether);
        assertEq(company.carbonCredits(), 10);
    }

    function test_buyFromMarket_revertsForNonOwner() public {
        vm.prank(outsider);
        vm.expectRevert("Not the owner");
        company.buyFromMarket(address(market), 10);
    }

    function test_buyFromMarket_success() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit CarbonCreditsPurchased(address(market), 7);
        company.buyFromMarket{value: 3 ether}(address(market), 7);

        assertEq(market.lastAmount(), 7);
        assertEq(market.lastBuyer(), address(company));
        assertEq(market.lastValue(), 3 ether);
        assertEq(company.carbonCredits(), 7);
    }

    function test_approve_revertsForNonManager() public {
        vm.prank(outsider);
        vm.expectRevert("Not the company manager");
        company.approve();
    }

    function test_approve_successByManager() public {
        company.approve();
        assertTrue(company.isApproved());
    }

    function test_receive_acceptsEth() public {
        vm.prank(payer);
        (bool ok, ) = address(company).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(company).balance, 1 ether);
    }
}
