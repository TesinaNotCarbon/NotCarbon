// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Project} from "../src/Project.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {CREValidationOracle} from "../src/oracles/CREValidationOracle.sol";
import {ReceiverTemplate} from "../src/chainlink/cre-contracts/ReceiverTemplate.sol";
import {BaseTest} from "./Base.t.sol";

contract CREValidationOracleTest is BaseTest {
    CREValidationOracle internal validationOracle;

    function setUp() public {
        _deployCore();
        validationOracle = new CREValidationOracle(address(projectManager), address(this), address(this));
        projectManager.setValidationOracleAdapter(address(validationOracle));
    }

    function test_requestValidation_revertsForNonReceiver() public {
        vm.expectRevert("Only the receiver can execute this function.");
        validationOracle.requestValidation(address(0x1234), "CELL-001");
    }

    function test_requestValidation_revertsForEmptyCellId() public {
        vm.expectRevert("Invalid cell id.");
        vm.prank(address(projectManager));
        validationOracle.requestValidation(address(0x1234), "");
    }

    function test_requestProjectValidation_returnsUniqueRequestIds() public {
        _bootstrapPriceAndMint(1 ether, 1000);
        Project project1 = _registerProject(creator, "Solar", "Solar farm", 200, "CELL-001");
        Project project2 = _registerProject(creator, "Wind", "Wind farm", 200, "CELL-002");

        bytes32 requestId1 = projectManager.requestProjectValidation(address(project1));
        bytes32 requestId2 = projectManager.requestProjectValidation(address(project2));

        assertTrue(requestId1 != bytes32(0));
        assertTrue(requestId2 != bytes32(0));
        assertTrue(requestId1 != requestId2);
        assertTrue(validationOracle.validationRequestPending(requestId1));
        assertTrue(validationOracle.validationRequestPending(requestId2));

        (address projectAddress, string memory cellId, bool exists, bool pending) =
            validationOracle.getValidationRequest(requestId1);
        assertEq(projectAddress, address(project1));
        assertEq(cellId, "CELL-001");
        assertTrue(exists);
        assertTrue(pending);
    }

    function test_onReport_validResultValidatesProject() public {
        _bootstrapPriceAndMint(1 ether, 1000);
        Project project = _registerProject(creator, "Solar", "Solar farm", 200);

        bytes32 requestId = projectManager.requestProjectValidation(address(project));
        validationOracle.onReport("", abi.encode(requestId, false, false));

        assertEq(uint256(project.currentState()), uint256(IProject.ProjectState.Validated));
        assertFalse(validationOracle.validationRequestPending(requestId));

        (bool validated, bool overlap, bool inconclusive,) = projectManager.getValidationStatus(address(project));
        assertTrue(validated);
        assertFalse(overlap);
        assertFalse(inconclusive);
    }

    function test_onReport_overlapLeavesProjectRegistered() public {
        _bootstrapPriceAndMint(1 ether, 1000);
        Project project = _registerProject(creator, "Solar", "Solar farm", 200);

        bytes32 requestId = projectManager.requestProjectValidation(address(project));
        validationOracle.onReport("", abi.encode(requestId, true, false));

        assertEq(uint256(project.currentState()), uint256(IProject.ProjectState.Registered));
        assertFalse(validationOracle.validationRequestPending(requestId));

        (bool validated, bool overlap, bool inconclusive,) = projectManager.getValidationStatus(address(project));
        assertFalse(validated);
        assertTrue(overlap);
        assertFalse(inconclusive);
    }

    function test_onReport_inconclusiveLeavesProjectRegistered() public {
        _bootstrapPriceAndMint(1 ether, 1000);
        Project project = _registerProject(creator, "Solar", "Solar farm", 200);

        bytes32 requestId = projectManager.requestProjectValidation(address(project));
        validationOracle.onReport("", abi.encode(requestId, false, true));

        assertEq(uint256(project.currentState()), uint256(IProject.ProjectState.Registered));
        assertFalse(validationOracle.validationRequestPending(requestId));

        (bool validated, bool overlap, bool inconclusive,) = projectManager.getValidationStatus(address(project));
        assertFalse(validated);
        assertFalse(overlap);
        assertTrue(inconclusive);
    }

    function test_onReport_revertsForUnknownRequestId() public {
        vm.expectRevert("Unknown request id.");
        validationOracle.onReport("", abi.encode(bytes32("missing"), false, false));
    }

    function test_onReport_revertsForUnauthorizedForwarder() public {
        _bootstrapPriceAndMint(1 ether, 1000);
        Project project = _registerProject(creator, "Solar", "Solar farm", 200);
        bytes32 requestId = projectManager.requestProjectValidation(address(project));

        address forwarder = validationOracle.getForwarderAddress();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(ReceiverTemplate.UnauthorizedForwarder.selector, outsider, forwarder));
        validationOracle.onReport("", abi.encode(requestId, false, false));
    }

    function test_onReport_revertsWhenExpectedWorkflowConfiguredAndMetadataMissing() public {
        _bootstrapPriceAndMint(1 ether, 1000);
        Project project = _registerProject(creator, "Solar", "Solar farm", 200);
        bytes32 requestId = projectManager.requestProjectValidation(address(project));

        validationOracle.setExpectedWorkflowId(bytes32("workflow"));

        vm.expectRevert(ReceiverTemplate.MissingReportMetadata.selector);
        validationOracle.onReport("", abi.encode(requestId, false, false));
    }

    function test_setForwarderAddress_revertsForZeroAddress() public {
        vm.expectRevert(ReceiverTemplate.InvalidForwarderAddress.selector);
        validationOracle.setForwarderAddress(address(0));
    }

    function test_mockValidationStillWorksWithoutConfiguredAdapter() public {
        _deployCore();
        _bootstrapPriceAndMint(1 ether, 1000);
        Project project = _registerProject(creator, "Solar", "Solar farm", 200);

        projectManager.mockValidationResult(address(project), false, false);

        assertEq(uint256(project.currentState()), uint256(IProject.ProjectState.Validated));
    }
}
