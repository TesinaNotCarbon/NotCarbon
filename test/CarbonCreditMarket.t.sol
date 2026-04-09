// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {CarbonCreditMarket} from "../src/CarbonCreditMarket.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {IProjectManager} from "../src/interfaces/IProjectManager.sol";
import {ICompanyManager} from "../src/interfaces/ICompanyManager.sol";

contract MockMarketProject is IProject {
    uint256 public available;
    uint256 public override pricePerToken;
    uint256 public purchased;

    constructor(uint256 _available, uint256 _pricePerToken) {
        available = _available;
        pricePerToken = _pricePerToken;
    }

    function buyCarbonCredits(uint256) external payable override {}

    function buyFor(address, uint256 amount) external payable override {
        require(available >= amount, "mock: not enough available");
        require(msg.value >= amount * pricePerToken, "mock: insufficient eth");
        available -= amount;
        purchased += amount;
    }

    function getReleasedTokens() external view override returns (uint256) {
        return available + purchased;
    }

    function currentState() external pure override returns (ProjectState) {
        return ProjectState.Phase4;
    }

    function projectName() external pure override returns (string memory) {
        return "mock";
    }

    function projectDescription() external pure override returns (string memory) {
        return "mock";
    }

    function getAvailableTokens() external view override returns (uint256) {
        return available;
    }
}

contract MockMarketProjectManager is IProjectManager {
    address[] internal projects;

    function setProjects(address[] memory _projects) external {
        projects = _projects;
    }

    function registerProject(string memory, string memory, address, uint256) external pure override returns (address) {
        return address(0);
    }

    function updateProjectStatus(address, IProject.ProjectState) external pure override {}

    function isProjectRegistered(address) external pure override returns (bool) {
        return true;
    }

    function setPricePerToken(uint256) external pure override {}

    function getAllProjects() external view override returns (address[] memory) {
        return projects;
    }
}

contract MockMarketCompanyManager is ICompanyManager {
    mapping(address => bool) internal approvals;

    function setApproved(address company, bool approved) external {
        approvals[company] = approved;
    }

    function createCompany(string memory, uint256) external pure override returns (address) {
        return address(0);
    }

    function approveCompany(address payable) external pure override {}

    function isApproved(address payable company) external view override returns (bool) {
        return approvals[company];
    }

    function getAllCompanies() external pure override returns (address[] memory) {
        address[] memory c = new address[](0);
        return c;
    }
}

contract CarbonCreditMarketTest is Test {
    MockMarketProjectManager internal projectManager;
    MockMarketCompanyManager internal companyManager;
    CarbonCreditMarket internal market;

    address internal payer = address(0xCAFE);
    address payable internal buyer = payable(address(0xB0B));

    receive() external payable {}

    function setUp() public {
        projectManager = new MockMarketProjectManager();
        companyManager = new MockMarketCompanyManager();
        market = new CarbonCreditMarket(address(projectManager), address(companyManager));

        vm.deal(payer, 100 ether);
        vm.deal(buyer, 10 ether);
    }

    function test_buyFromAny_revertsForUnapprovedCompany() public {
        companyManager.setApproved(buyer, false);

        vm.prank(payer);
        vm.expectRevert("Company not approved");
        market.buyFromAny{value: 1 ether}(1, buyer);
    }

    function test_buyFromAny_revertsForInsufficientEth() public {
        MockMarketProject p1 = new MockMarketProject(2, 1 ether);

        address[] memory projects = new address[](1);
        projects[0] = address(p1);
        projectManager.setProjects(projects);
        companyManager.setApproved(buyer, true);

        vm.prank(payer);
        vm.expectRevert("Insufficient ETH");
        market.buyFromAny{value: 1 ether}(2, buyer);
    }

    function test_buyFromAny_revertsIfCannotFillAmount() public {
        MockMarketProject p1 = new MockMarketProject(1, 1 ether);

        address[] memory projects = new address[](1);
        projects[0] = address(p1);
        projectManager.setProjects(projects);
        companyManager.setApproved(buyer, true);

        vm.prank(payer);
        vm.expectRevert("Could not complete purchase with available projects");
        market.buyFromAny{value: 5 ether}(2, buyer);
    }

    function test_buyFromAny_purchasesAcrossMultipleProjects() public {
        MockMarketProject p1 = new MockMarketProject(2, 1 ether);
        MockMarketProject p2 = new MockMarketProject(5, 1 ether);

        address[] memory projects = new address[](2);
        projects[0] = address(p1);
        projects[1] = address(p2);
        projectManager.setProjects(projects);
        companyManager.setApproved(buyer, true);

        vm.prank(payer);
        market.buyFromAny{value: 4 ether}(4, buyer);

        assertEq(p1.purchased(), 2);
        assertEq(p2.purchased(), 2);
    }

    function test_buyFromAny_refundsBuyer() public {
        MockMarketProject p1 = new MockMarketProject(10, 1 ether);

        address[] memory projects = new address[](1);
        projects[0] = address(p1);
        projectManager.setProjects(projects);
        companyManager.setApproved(buyer, true);

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(payer);
        market.buyFromAny{value: 7 ether}(3, buyer);

        assertEq(buyer.balance, buyerBalanceBefore + 4 ether);
    }
}
