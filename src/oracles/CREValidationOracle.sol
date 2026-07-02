// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReceiverTemplate} from "@chainlink/cre-contracts/ReceiverTemplate.sol";
import {IProjectValidationOracle} from "../interfaces/IProjectValidationOracle.sol";
import {IProjectValidationReceiver} from "../interfaces/IProjectValidationReceiver.sol";

contract CREValidationOracle is IProjectValidationOracle, ReceiverTemplate {
    address public admin;
    address public receiver;
    uint256 public requestNonce;

    mapping(bytes32 => bool) public validationRequestExists;
    mapping(bytes32 => bool) public validationRequestPending;
    mapping(bytes32 => address) public requestProject;
    mapping(bytes32 => string) public requestCellId;

    event ValidationRequested(bytes32 indexed requestId, address indexed projectAddress, string cellId);
    event ValidationReported(bytes32 indexed requestId, bool overlap, bool inconclusive);
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

    function requestValidation(address projectAddress, string calldata cellId)
        external
        override
        onlyReceiver
        returns (bytes32)
    {
        require(isConfigured(), "CRE forwarder not set.");
        require(projectAddress != address(0), "Invalid project address.");

        uint256 nonce = ++requestNonce;
        bytes32 requestId =
            keccak256(abi.encodePacked(block.chainid, address(this), projectAddress, keccak256(bytes(cellId)), nonce));

        validationRequestExists[requestId] = true;
        validationRequestPending[requestId] = true;
        requestProject[requestId] = projectAddress;
        requestCellId[requestId] = cellId;

        emit ValidationRequested(requestId, projectAddress, cellId);
        return requestId;
    }

    function _processReport(bytes calldata report) internal override {
        (bytes32 requestId, bool overlap, bool inconclusive) = abi.decode(report, (bytes32, bool, bool));
        require(validationRequestExists[requestId], "Unknown request id.");
        require(validationRequestPending[requestId], "Validation request already completed.");

        validationRequestPending[requestId] = false;
        emit ValidationReported(requestId, overlap, inconclusive);

        IProjectValidationReceiver(receiver).receiveValidationResult(requestId, overlap, inconclusive);
    }
}
