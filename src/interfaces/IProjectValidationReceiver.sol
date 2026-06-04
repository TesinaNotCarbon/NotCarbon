// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectValidationReceiver {
    function receiveValidationResult(bytes32 requestId, bool overlap, bool inconclusive) external;
}
