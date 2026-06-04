// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectValidationOracle {
    function requestValidation(address projectAddress, string calldata cellId) external returns (bytes32);

    function isConfigured() external view returns (bool);
}
