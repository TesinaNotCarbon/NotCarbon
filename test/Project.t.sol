// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {CompanyManager} from "../src/CompanyManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";
import {Project} from "../src/Project.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProjectTest is Test {
    RoleManager internal roleManager;
    CompanyManager internal companyManager;
    CarbonCreditToken internal token;
    Project internal project;

    address internal creator = address(0xCAFE);
    address internal outsider = address(0xBEEF);
    address internal buyer = address(0xB0B);
    address internal companyOwner = address(0xC0FFEE);

    event StateChanged(IProject.ProjectState newState);
    event TokensPurchased(address indexed buyer, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);

    function setUp() public {
        RoleManager roleManagerImpl = new RoleManager();
        roleManager = RoleManager(
            address(
                new ERC1967Proxy(
                    address(roleManagerImpl), abi.encodeCall(RoleManager.initialize, (address(this), address(this)))
                )
            )
        );

        CompanyManager companyManagerImpl = new CompanyManager();
        companyManager = CompanyManager(
            address(
                new ERC1967Proxy(
                    address(companyManagerImpl),
                    abi.encodeCall(CompanyManager.initialize, (address(roleManager), address(this)))
                )
            )
        );

        CarbonCreditToken tokenImpl = new CarbonCreditToken();
        token = CarbonCreditToken(
            address(
                new ERC1967Proxy(
                    address(tokenImpl),
                    abi.encodeCall(
                        CarbonCreditToken.initialize,
                        (address(this), address(roleManager), address(this), address(this))
                    )
                )
            )
        );
        project = new Project(
            "Forest", "Restore native forest", address(token), 1000, creator, 1 ether, companyManager, "CELL-001"
        );

        token.mint(1000);
        token.transferTokens(address(project), 1000);

        vm.deal(buyer, 100 ether);
        vm.deal(outsider, 100 ether);
        vm.deal(companyOwner, 100 ether);
        vm.deal(creator, 10 ether);
    }

    function test_constructor_initializesState() public view {
        assertEq(project.projectManager(), address(this));
        assertEq(project.projectName(), "Forest");
        assertEq(project.projectDescription(), "Restore native forest");
        assertEq(uint256(project.currentState()), uint256(IProject.ProjectState.Registered));
        assertEq(project.totalTokens(), 1000);
        assertEq(project.purchasedTokens(), 0);
        assertEq(project.pricePerToken(), 1 ether);
    }

    function test_setPricePerToken_revertsForNonProjectManager() public {
        vm.prank(outsider);
        vm.expectRevert("Only the project manager can execute this function.");
        project.setPricePerToken(2 ether);
    }

    function test_updateState_mustIncrease() public {
        project.updateState(IProject.ProjectState.Approved);

        vm.expectRevert("New state must be a higher phase.");
        project.updateState(IProject.ProjectState.Approved);
    }

    function test_getReleasedTokens_perPhase() public {
        assertEq(project.getReleasedTokens(), 0);

        project.updateState(IProject.ProjectState.Validated);
        assertEq(project.getReleasedTokens(), 0);

        project.updateState(IProject.ProjectState.Approved);
        assertEq(project.getReleasedTokens(), 100);

        project.updateState(IProject.ProjectState.Milestone1);
        assertEq(project.getReleasedTokens(), 250);

        project.updateState(IProject.ProjectState.Milestone2);
        assertEq(project.getReleasedTokens(), 500);

        project.updateState(IProject.ProjectState.Milestone3);
        assertEq(project.getReleasedTokens(), 750);

        project.updateState(IProject.ProjectState.Milestone4);
        assertEq(project.getReleasedTokens(), 1000);
    }

    function test_buyCarbonCredits_revertsForInsufficientEth() public {
        project.updateState(IProject.ProjectState.Milestone4);

        vm.prank(buyer);
        vm.expectRevert("Insufficient ETH sent");
        project.buyCarbonCredits{value: 1 ether}(2);
    }

    function test_buyCarbonCredits_revertsWhenAmountExceedsReleased() public {
        vm.prank(buyer);
        vm.expectRevert("Amount exceeds available tokens for this phase");
        project.buyCarbonCredits{value: 1 ether}(1);
    }

    function test_buyCarbonCredits_success() public {
        project.updateState(IProject.ProjectState.Milestone4);

        vm.prank(buyer);
        vm.expectEmit(true, false, false, true);
        emit TokensPurchased(buyer, 5);
        project.buyCarbonCredits{value: 5 ether}(5);

        assertEq(token.balanceOf(buyer), 5);
        assertEq(project.purchasedTokens(), 5);
    }

    function test_buyCarbonCredits_refundsExcessEth() public {
        project.updateState(IProject.ProjectState.Milestone4);
        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(buyer);
        project.buyCarbonCredits{value: 5 ether}(3);

        assertEq(buyer.balance, buyerBalanceBefore - 3 ether);
    }

    function test_buyFor_revertsWhenCompanyNotApproved() public {
        project.updateState(IProject.ProjectState.Milestone4);

        vm.prank(companyOwner);
        address companyAddress = companyManager.createCompany("Green Corp", 120);

        vm.expectRevert("Company not approved");
        project.buyFor{value: 2 ether}(companyAddress, 2);
    }

    function test_buyFor_revertsForInsufficientEth() public {
        project.updateState(IProject.ProjectState.Milestone4);
        vm.prank(companyOwner);
        address companyAddress = companyManager.createCompany("Green Corp", 120);
        companyManager.approveCompany(payable(companyAddress));

        vm.expectRevert("Insufficient ETH");
        project.buyFor{value: 1 ether}(companyAddress, 2);
    }

    function test_buyFor_successForApprovedCompany() public {
        project.updateState(IProject.ProjectState.Milestone4);
        vm.prank(companyOwner);
        address companyAddress = companyManager.createCompany("Green Corp", 120);
        companyManager.approveCompany(payable(companyAddress));

        project.buyFor{value: 3 ether}(companyAddress, 3);

        assertEq(token.balanceOf(companyAddress), 3);
        assertEq(project.purchasedTokens(), 3);
    }

    function test_buyFor_refundsExcessEthToCaller() public {
        project.updateState(IProject.ProjectState.Milestone4);
        vm.prank(companyOwner);
        address companyAddress = companyManager.createCompany("Green Corp", 120);
        companyManager.approveCompany(payable(companyAddress));

        uint256 callerBalanceBefore = outsider.balance;

        vm.prank(outsider);
        project.buyFor{value: 4 ether}(companyAddress, 2);

        assertEq(outsider.balance, callerBalanceBefore - 2 ether);
    }

    function test_withdrawEth_revertsForNonCreator() public {
        project.deposit{value: 5 ether}();

        vm.prank(outsider);
        vm.expectRevert("Only the project creator can execute this function.");
        project.withdrawETH(1 ether);
    }

    function test_withdrawEth_revertsForInsufficientBalance() public {
        vm.prank(creator);
        vm.expectRevert("Insufficient ETH balance");
        project.withdrawETH(1 ether);
    }

    function test_withdrawEth_success() public {
        project.deposit{value: 5 ether}();
        uint256 creatorBalanceBefore = creator.balance;

        vm.prank(creator);
        vm.expectEmit(true, false, false, true);
        emit ETHWithdrawn(creator, 2 ether);
        project.withdrawETH(2 ether);

        assertEq(address(project).balance, 3 ether);
        assertEq(creator.balance, creatorBalanceBefore + 2 ether);
    }
}
