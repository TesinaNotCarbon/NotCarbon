// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectScoringOracle {
    function requestScoring(address projectAddress) external returns (bytes32);

    function isConfigured() external view returns (bool);
}
