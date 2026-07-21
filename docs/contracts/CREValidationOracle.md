# CREValidationOracle

## Summary

`CREValidationOracle` is the Chainlink CRE adapter for project validation. It creates validation request ids for project/cell-id pairs, receives CRE reports through `ReceiverTemplate`, decodes validation results, and forwards those results to `ProjectManager`. Its purpose is to bridge asynchronous off-chain geospatial validation into the on-chain project lifecycle.

## Interface

- `constructor(address _receiver, address _admin, address _forwarder)`: initializes the result receiver, admin, and trusted Chainlink forwarder.
- `setReceiver(address _receiver)`: admin-only receiver update.
- `isConfigured()`: returns whether the inherited receiver template has a non-zero forwarder address.
- `requestValidation(address projectAddress, string calldata cellId)`: receiver-only request creation that returns a unique request id.
- Inherited receiver/admin methods from `ReceiverTemplate`: `onReport`, `getForwarderAddress`, `setForwarderAddress`, `setExpectedWorkflowId`, `setExpectedAuthor`, and related getters.
- Public request tracking getters: `requestNonce`, `validationRequestExists`, `validationRequestPending`, `requestProject`, and `requestCellId`.

## Implementation details

The contract implements the validation-oracle interface and extends `ReceiverTemplate`. `receiver` is expected to be `ProjectManager`, and only that receiver can call `requestValidation`, preventing arbitrary users from creating validation requests. Request ids are generated with `keccak256(abi.encodePacked(block.chainid, address(this), projectAddress, keccak256(bytes(cellId)), nonce))`, which ties ids to the chain, oracle, project, cell id, and sequence number. Requests are stored as existing and pending, with the original project and cell id retained. CRE reports arrive through `ReceiverTemplate.onReport`, which first validates the trusted forwarder and optional metadata. `_processReport` then decodes `(bytes32 requestId, bool overlap, bool inconclusive)`, rejects unknown or completed requests, marks the request complete, emits `ValidationReported`, and calls `receiveValidationResult` on the receiver. Ownership of receiver-template configuration is transferred to the admin in the constructor.