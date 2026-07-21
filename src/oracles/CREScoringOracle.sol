// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReceiverTemplate} from "@chainlink/cre-contracts/ReceiverTemplate.sol";
import {IProjectManager} from "../interfaces/IProjectManager.sol";
import {IProjectScoringReceiver} from "../interfaces/IProjectScoringReceiver.sol";

contract CREScoringOracle is ReceiverTemplate {
    address public admin;
    address public receiver;

    event ScoringReported(
        address indexed projectAddress, uint256 measurementDate, uint256 scoring, uint256 fraudScoring
    );
    event ReceiverUpdated(address indexed receiver);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can execute this function.");
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

    function isConfigured() public view returns (bool) {
        return getForwarderAddress() != address(0);
    }

    function _processReport(bytes calldata report) internal override {
        (address projectAddress, uint256 measurementDate, uint256 scoring, uint256 fraudScoring) =
            abi.decode(report, (address, uint256, uint256, uint256));
        require(projectAddress != address(0), "Invalid project address.");
        require(IProjectManager(receiver).isProjectRegistered(projectAddress), "Project is not registered.");

        emit ScoringReported(projectAddress, measurementDate, scoring, fraudScoring);
        IProjectScoringReceiver(receiver).receiveProjectScoring(projectAddress, measurementDate, scoring, fraudScoring);
    }
}
