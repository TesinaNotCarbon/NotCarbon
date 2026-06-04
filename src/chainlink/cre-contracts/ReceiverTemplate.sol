// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IReceiver} from "./IReceiver.sol";

abstract contract ReceiverTemplate is IReceiver, ERC165, Ownable {
    address private forwarderAddress;
    bytes32 private expectedWorkflowId;
    address private expectedAuthor;

    event ForwarderAddressUpdated(address indexed previousForwarder, address indexed newForwarder);
    event ExpectedWorkflowIdUpdated(bytes32 indexed previousWorkflowId, bytes32 indexed newWorkflowId);
    event ExpectedAuthorUpdated(address indexed previousAuthor, address indexed newAuthor);

    error InvalidForwarderAddress();
    error UnauthorizedForwarder(address caller, address expectedForwarder);
    error UnexpectedWorkflowId(bytes32 workflowId, bytes32 expectedWorkflowId);
    error UnexpectedAuthor(address author, address expectedAuthor);

    constructor(address _forwarderAddress) Ownable(msg.sender) {
        if (_forwarderAddress == address(0)) {
            revert InvalidForwarderAddress();
        }
        forwarderAddress = _forwarderAddress;
    }

    function getForwarderAddress() public view returns (address) {
        return forwarderAddress;
    }

    function getExpectedWorkflowId() external view returns (bytes32) {
        return expectedWorkflowId;
    }

    function getExpectedAuthor() external view returns (address) {
        return expectedAuthor;
    }

    function setForwarderAddress(address _forwarderAddress) external onlyOwner {
        address previousForwarder = forwarderAddress;
        forwarderAddress = _forwarderAddress;
        emit ForwarderAddressUpdated(previousForwarder, _forwarderAddress);
    }

    function setExpectedWorkflowId(bytes32 _workflowId) external onlyOwner {
        bytes32 previousWorkflowId = expectedWorkflowId;
        expectedWorkflowId = _workflowId;
        emit ExpectedWorkflowIdUpdated(previousWorkflowId, _workflowId);
    }

    function setExpectedAuthor(address _author) external onlyOwner {
        address previousAuthor = expectedAuthor;
        expectedAuthor = _author;
        emit ExpectedAuthorUpdated(previousAuthor, _author);
    }

    function onReport(bytes calldata metadata, bytes calldata report) external virtual override {
        address currentForwarder = forwarderAddress;
        if (msg.sender != currentForwarder) {
            revert UnauthorizedForwarder(msg.sender, currentForwarder);
        }

        if (metadata.length >= 62) {
            (bytes32 workflowId, address author) = _decodeMetadata(metadata);
            bytes32 configuredWorkflowId = expectedWorkflowId;
            address configuredAuthor = expectedAuthor;

            if (configuredWorkflowId != bytes32(0) && workflowId != configuredWorkflowId) {
                revert UnexpectedWorkflowId(workflowId, configuredWorkflowId);
            }
            if (configuredAuthor != address(0) && author != configuredAuthor) {
                revert UnexpectedAuthor(author, configuredAuthor);
            }
        }

        _processReport(report);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IReceiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function _decodeMetadata(bytes calldata metadata) internal pure returns (bytes32 workflowId, address author) {
        assembly {
            workflowId := calldataload(metadata.offset)
            author := shr(96, calldataload(add(metadata.offset, 42)))
        }
    }

    function _processReport(bytes calldata report) internal virtual;
}
