// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Project} from "../src/Project.sol";
import {IProject} from "../src/interfaces/IProject.sol";
import {CREScoringOracle} from "../src/oracles/CREScoringOracle.sol";
import {ReceiverTemplate} from "../src/chainlink/cre-contracts/ReceiverTemplate.sol";
import {BaseTest} from "./Base.t.sol";

contract CREScoringOracleTest is BaseTest {
    CREScoringOracle internal scoringOracle;

    function setUp() public {
        _deployCore();
        scoringOracle = new CREScoringOracle(address(projectManager), address(this), address(this));
        projectManager.setScoringOracleAdapter(address(scoringOracle));
    }

    function test_requestScoring_revertsForNonReceiver() public {
        vm.expectRevert("Only the receiver can execute this function.");
        scoringOracle.requestScoring(address(0x1234));
    }

    function test_requestProjectScoring_requiresApprovedProject() public {
        Project project = _createRegisteredProject();

        vm.expectRevert("Project must be approved first.");
        projectManager.requestProjectScoring(address(project));
    }

    function test_requestProjectScoring_successStoresPendingState() public {
        Project project = _createApprovedProject();

        bytes32 requestId = projectManager.requestProjectScoring(address(project));

        assertTrue(requestId != bytes32(0));
        assertTrue(projectManager.scoringPending(address(project)));
        assertEq(projectManager.scoringRequests(requestId), address(project));
        assertEq(projectManager.lastScoringRequestId(address(project)), requestId);
        assertTrue(scoringOracle.scoringRequestExists(requestId));
        assertTrue(scoringOracle.scoringRequestPending(requestId));
        assertEq(scoringOracle.requestProject(requestId), address(project));
    }

    function test_requestProjectScoring_revertsWhenAlreadyPending() public {
        Project project = _createApprovedProject();
        projectManager.requestProjectScoring(address(project));

        vm.expectRevert("Scoring already pending.");
        projectManager.requestProjectScoring(address(project));
    }

    function test_onReport_successStoresHistory() public {
        Project project = _createApprovedProject();
        bytes32 requestId = projectManager.requestProjectScoring(address(project));

        scoringOracle.onReport("", abi.encode(requestId, uint256(1_800_000_000), uint256(82), uint256(7)));

        assertFalse(scoringOracle.scoringRequestPending(requestId));
        assertFalse(projectManager.scoringPending(address(project)));
        assertEq(projectManager.getProjectScoringCount(address(project)), 1);
        (uint256 measurementDate, uint256 scoring, uint256 fraudScoring, uint256 storedAt) =
            projectManager.getProjectScoringAt(address(project), 0);
        assertEq(measurementDate, 1_800_000_000);
        assertEq(scoring, 82);
        assertEq(fraudScoring, 7);
        assertGt(storedAt, 0);
    }

    function test_onReport_revertsForUnknownRequestId() public {
        vm.expectRevert("Unknown request id.");
        scoringOracle.onReport("", abi.encode(bytes32("missing"), uint256(1), uint256(50), uint256(50)));
    }

    function test_onReport_revertsForReplay() public {
        Project project = _createApprovedProject();
        bytes32 requestId = projectManager.requestProjectScoring(address(project));
        scoringOracle.onReport("", abi.encode(requestId, uint256(1_800_000_000), uint256(82), uint256(7)));

        vm.expectRevert("Scoring request already completed.");
        scoringOracle.onReport("", abi.encode(requestId, uint256(1_800_086_400), uint256(83), uint256(6)));
    }

    function test_onReport_revertsForInvalidRangesAndZeroDate() public {
        Project project = _createApprovedProject();
        bytes32 requestId = projectManager.requestProjectScoring(address(project));

        vm.expectRevert("Invalid measurement date.");
        scoringOracle.onReport("", abi.encode(requestId, uint256(0), uint256(50), uint256(50)));

        vm.expectRevert("Invalid scoring.");
        scoringOracle.onReport("", abi.encode(requestId, uint256(1), uint256(101), uint256(50)));

        vm.expectRevert("Invalid fraud scoring.");
        scoringOracle.onReport("", abi.encode(requestId, uint256(1), uint256(50), uint256(101)));
    }

    function test_receiveProjectScoring_rejectsDuplicateOrNonIncreasingDates() public {
        Project project = _createApprovedProject();
        bytes32 firstRequestId = projectManager.requestProjectScoring(address(project));
        scoringOracle.onReport("", abi.encode(firstRequestId, uint256(1_800_000_000), uint256(82), uint256(7)));

        bytes32 secondRequestId = projectManager.requestProjectScoring(address(project));
        vm.expectRevert("Measurement date must increase.");
        scoringOracle.onReport("", abi.encode(secondRequestId, uint256(1_800_000_000), uint256(83), uint256(6)));
    }

    function test_onReport_revertsForUnauthorizedForwarder() public {
        Project project = _createApprovedProject();
        bytes32 requestId = projectManager.requestProjectScoring(address(project));
        address forwarder = scoringOracle.getForwarderAddress();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(ReceiverTemplate.UnauthorizedForwarder.selector, outsider, forwarder));
        scoringOracle.onReport("", abi.encode(requestId, uint256(1_800_000_000), uint256(82), uint256(7)));
    }

    function _createRegisteredProject() internal returns (Project) {
        _bootstrapPriceAndMint(1 ether, 1000);
        return _registerProject(creator, "Solar", "Solar farm", 200);
    }

    function _createApprovedProject() internal returns (Project) {
        Project project = _createRegisteredProject();
        projectManager.mockValidationResult(address(project), false, false);
        projectManager.updateProjectStatus(address(project), IProject.ProjectState.Approved);
        return project;
    }
}
