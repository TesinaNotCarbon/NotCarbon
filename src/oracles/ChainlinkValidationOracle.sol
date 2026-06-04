// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IReceiver} from "chainlink-brownie-contracts/contracts/src/v0.8/keystone/interfaces/IReceiver.sol";
import {IProjectValidationOracle} from "../interfaces/IProjectValidationOracle.sol";
import {IProjectValidationReceiver} from "../interfaces/IProjectValidationReceiver.sol";

contract ChainlinkValidationOracle is IProjectValidationOracle, IReceiver, IERC165 {
    struct Permission {
        address forwarder;
        bytes10 workflowName;
        bytes2 reportName;
        address workflowOwner;
        bool isAllowed;
    }

    address public admin;
    address public receiver;
    uint256 public requestNonce;
    bool private configured;

    mapping(bytes32 => bool) private allowedReports;

    event ValidationRequested(bytes32 indexed requestId, address indexed projectAddress, string cellId);
    event ReceiverUpdated(address indexed receiver);
    event ReportPermissionSet(bytes32 indexed reportId, Permission permission);

    error ReportForwarderUnauthorized(address forwarder, address workflowOwner, bytes10 workflowName, bytes2 reportName);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can execute this function.");
        _;
    }

    modifier onlyReceiver() {
        require(msg.sender == receiver, "Only the receiver can execute this function.");
        _;
    }

    constructor(address _receiver, address _admin) {
        require(_receiver != address(0), "Invalid receiver.");
        require(_admin != address(0), "Invalid admin.");
        receiver = _receiver;
        admin = _admin;
    }

    function setReceiver(address _receiver) external onlyAdmin {
        require(_receiver != address(0), "Invalid receiver.");
        receiver = _receiver;
        emit ReceiverUpdated(_receiver);
    }

    function setReportPermissions(Permission[] memory permissions) external onlyAdmin {
        for (uint256 i = 0; i < permissions.length; ++i) {
            bytes32 reportId = _createReportId(
                permissions[i].forwarder,
                permissions[i].workflowOwner,
                permissions[i].workflowName,
                permissions[i].reportName
            );
            allowedReports[reportId] = permissions[i].isAllowed;
            emit ReportPermissionSet(reportId, permissions[i]);
            if (permissions[i].isAllowed) {
                configured = true;
            }
        }
    }

    function isConfigured() public view override returns (bool) {
        return configured;
    }

    function requestValidation(address projectAddress, string calldata cellId)
        external
        override
        onlyReceiver
        returns (bytes32)
    {
        bytes32 requestId = keccak256(
            abi.encodePacked(address(this), projectAddress, cellId, block.chainid, requestNonce)
        );
        requestNonce += 1;
        emit ValidationRequested(requestId, projectAddress, cellId);
        return requestId;
    }

    function onReport(bytes calldata metadata, bytes calldata report) external override {
        (bytes10 workflowName, address workflowOwner, bytes2 reportName) = _getInfo(metadata);
        bytes32 reportId = _createReportId(msg.sender, workflowOwner, workflowName, reportName);
        if (!allowedReports[reportId]) {
            revert ReportForwarderUnauthorized(msg.sender, workflowOwner, workflowName, reportName);
        }

        (bytes32 requestId, bool overlap, bool inconclusive) = abi.decode(report, (bytes32, bool, bool));
        IProjectValidationReceiver(receiver).receiveValidationResult(requestId, overlap, inconclusive);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function _getInfo(bytes memory metadata)
        internal
        pure
        returns (bytes10 workflowName, address workflowOwner, bytes2 reportName)
    {
        assembly {
            workflowName := mload(add(metadata, 64))
            workflowOwner := shr(mul(12, 8), mload(add(metadata, 74)))
            reportName := mload(add(metadata, 94))
        }
    }

    function _createReportId(
        address forwarder,
        address workflowOwner,
        bytes10 workflowName,
        bytes2 reportName
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(forwarder, workflowOwner, workflowName, reportName));
    }
}
