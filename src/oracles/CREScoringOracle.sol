// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReceiverTemplate} from "@chainlink/cre-contracts/ReceiverTemplate.sol";
import {IProjectScoringOracle} from "../interfaces/IProjectScoringOracle.sol";
import {IProjectScoringReceiver} from "../interfaces/IProjectScoringReceiver.sol";

contract CREScoringOracle is IProjectScoringOracle, ReceiverTemplate {
    address public admin;
    address public receiver;
    uint256 public requestNonce;

    mapping(bytes32 => bool) public scoringRequestExists;
    mapping(bytes32 => bool) public scoringRequestPending;
    mapping(bytes32 => address) public requestProject;

    event ScoringRequested(bytes32 indexed requestId, address indexed projectAddress);
    event ScoringReported(
        bytes32 indexed requestId,
        address indexed projectAddress,
        uint256 measurementDate,
        uint256 scoring,
        uint256 fraudScoring
    );
    event ReceiverUpdated(address indexed receiver);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can execute this function.");
        _;
    }

    modifier onlyReceiver() {
        require(msg.sender == receiver, "Only the receiver can execute this function.");
        _;
    }

    constructor(address _receiver, address _admin, address _forwarder) ReceiverTemplate(_forwarder) {
        require(_receiver != address(0), "Invalid receiver.");
        require(_admin != address(0), "Invalid admin.");
        receiver = _receiver;
        admin = _admin;
        _transferOwnership(_admin);
    }

    function setReceiver(address _receiver) external onlyAdmin {
        require(_receiver != address(0), "Invalid receiver.");
        receiver = _receiver;
        emit ReceiverUpdated(_receiver);
    }

    function isConfigured() public view override returns (bool) {
        return getForwarderAddress() != address(0);
    }

    function requestScoring(address projectAddress) external override onlyReceiver returns (bytes32) {
        require(isConfigured(), "CRE forwarder not set.");
        require(projectAddress != address(0), "Invalid project address.");

        uint256 nonce = ++requestNonce;
        bytes32 requestId = keccak256(abi.encodePacked(block.chainid, address(this), projectAddress, nonce));

        scoringRequestExists[requestId] = true;
        scoringRequestPending[requestId] = true;
        requestProject[requestId] = projectAddress;

        emit ScoringRequested(requestId, projectAddress);
        return requestId;
    }

    function getScoringRequest(bytes32 requestId)
        external
        view
        returns (address projectAddress, bool exists, bool pending)
    {
        return (requestProject[requestId], scoringRequestExists[requestId], scoringRequestPending[requestId]);
    }

    function _processReport(bytes calldata report) internal override {
        (bytes32 requestId, uint256 measurementDate, uint256 scoring, uint256 fraudScoring) =
            abi.decode(report, (bytes32, uint256, uint256, uint256));
        require(scoringRequestExists[requestId], "Unknown request id.");
        require(scoringRequestPending[requestId], "Scoring request already completed.");
        require(measurementDate != 0, "Invalid measurement date.");
        require(scoring <= 100, "Invalid scoring.");
        require(fraudScoring <= 100, "Invalid fraud scoring.");

        scoringRequestPending[requestId] = false;
        address projectAddress = requestProject[requestId];

        emit ScoringReported(requestId, projectAddress, measurementDate, scoring, fraudScoring);
        IProjectScoringReceiver(receiver).receiveProjectScoring(requestId, measurementDate, scoring, fraudScoring);
    }
}
