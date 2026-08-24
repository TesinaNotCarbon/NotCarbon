// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectValidationOracle {
    function requestValidation(address projectAddress, string calldata cellId) external returns (bytes32);

    function getValidationRequest(bytes32 requestId)
        external
        view
        returns (address projectAddress, string memory cellId, bool exists, bool pending);

    function isConfigured() external view returns (bool);
}
