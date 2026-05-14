// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {CompanyManager} from "../src/CompanyManager.sol";
import {ProjectManager} from "../src/ProjectManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";
import {CarbonCreditMarket} from "../src/CarbonCreditMarket.sol";
import {Company} from "../src/Company.sol";
import {Project} from "../src/Project.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract BaseTest is Test {
    address internal staff = address(0xA11CE);
    address internal outsider = address(0xBEEF);
    address internal companyOwner = address(0xC0FFEE);
    address internal buyer = address(0xB0B);
    address internal creator = address(0xCAFE);

    RoleManager internal roleManager;
    CompanyManager internal companyManager;
    ProjectManager internal projectManager;
    CarbonCreditToken internal token;
    CarbonCreditMarket internal market;

    function _deployCore() internal {
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

        ProjectManager projectManagerImpl = new ProjectManager();
        projectManager = ProjectManager(
            address(
                new ERC1967Proxy(
                    address(projectManagerImpl),
                    abi.encodeCall(
                        ProjectManager.initialize,
                        (address(roleManager), address(companyManager), address(this), address(this))
                    )
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
                        (address(projectManager), address(roleManager), address(this), address(this))
                    )
                )
            )
        );

        CarbonCreditMarket marketImpl = new CarbonCreditMarket();
        market = CarbonCreditMarket(
            address(
                new ERC1967Proxy(
                    address(marketImpl),
                    abi.encodeCall(
                        CarbonCreditMarket.initialize, (address(projectManager), address(companyManager), address(this))
                    )
                )
            )
        );

        vm.deal(staff, 100 ether);
        vm.deal(outsider, 100 ether);
        vm.deal(companyOwner, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(creator, 100 ether);
    }

    function _grantStaff(address _staff) internal {
        roleManager.addStaff(_staff);
    }

    function _bootstrapPriceAndMint(uint256 price, uint256 amount) internal {
        projectManager.setPricePerToken(price);
        token.mint(amount);
    }

    function _createCompany(address owner, string memory name, uint256 emissions) internal returns (Company) {
        vm.prank(owner);
        address companyAddress = companyManager.createCompany(name, emissions);
        return Company(payable(companyAddress));
    }

    function _approveCompany(address companyAddress, address approver) internal {
        vm.prank(approver);
        companyManager.approveCompany(payable(companyAddress));
    }

    function _registerProject(
        address projectCreator,
        string memory name,
        string memory description,
        uint256 totalTokens
    ) internal returns (Project) {
        return _registerProject(projectCreator, name, description, totalTokens, "CELL-001");
    }

    function _registerProject(
        address projectCreator,
        string memory name,
        string memory description,
        uint256 totalTokens,
        string memory cellId
    ) internal returns (Project) {
        vm.prank(projectCreator);
        address projectAddress = projectManager.registerProject(name, description, address(token), totalTokens, cellId);
        return Project(payable(projectAddress));
    }

    function _advanceToMilestone4(address projectAddress) internal {
        projectManager.mockValidationResult(projectAddress, false, false);
        projectManager.updateProjectStatus(projectAddress, IProject.ProjectState.Approved);
        projectManager.updateProjectStatus(projectAddress, IProject.ProjectState.Milestone1);
        projectManager.updateProjectStatus(projectAddress, IProject.ProjectState.Milestone2);
        projectManager.updateProjectStatus(projectAddress, IProject.ProjectState.Milestone3);
        projectManager.updateProjectStatus(projectAddress, IProject.ProjectState.Milestone4);
    }
}
