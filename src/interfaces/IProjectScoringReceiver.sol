// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectScoringReceiver {
    function receiveProjectScoring(bytes32 requestId, uint256 measurementDate, uint256 scoring, uint256 fraudScoring)
        external;
}
