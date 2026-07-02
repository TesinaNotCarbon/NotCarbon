# ReceiverTemplate

## Summary

`ReceiverTemplate` is an abstract base contract for receiving Chainlink CRE reports. It verifies that reports come from a trusted forwarder, optionally checks workflow metadata, and delegates application-specific report decoding to an internal abstract function. `CREValidationOracle` extends this template to process validation results.

## Interface

- `constructor(address _forwarderAddress)`: sets the trusted Chainlink forwarder.
- `getForwarderAddress()`: returns the trusted forwarder.
- `getExpectedWorkflowId()`: returns the optional expected workflow id.
- `getExpectedAuthor()`: returns the optional expected report author.
- `setForwarderAddress(address _forwarderAddress)`: owner-only forwarder update.
- `setExpectedWorkflowId(bytes32 _workflowId)`: owner-only expected workflow id update.
- `setExpectedAuthor(address _author)`: owner-only expected author update.
- `onReport(bytes calldata metadata, bytes calldata report)`: Chainlink receiver entry point.
- `supportsInterface(bytes4 interfaceId)`: ERC-165 support for the receiver interface.
- `_processReport(bytes calldata report)`: internal virtual hook implemented by child contracts.

## Implementation details

The template inherits `IReceiver`, `ERC165`, and `Ownable`. It stores `forwarderAddress`, `expectedWorkflowId`, and `expectedAuthor`. `onReport` first checks `msg.sender` against the configured forwarder and reverts with custom errors for unauthorized callers. If either expected workflow id or expected author is configured, metadata must be present and must match. Metadata decoding uses inline assembly to extract a `bytes32` workflow id and an address author efficiently from calldata. After these generic security checks, the template calls `_processReport(report)`, leaving payload interpretation to the child contract. This separates CRE transport/security concerns from application-specific report logic. The contract uses custom errors such as `InvalidForwarderAddress`, `UnauthorizedForwarder`, `UnexpectedWorkflowId`, `UnexpectedAuthor`, and `MissingReportMetadata`, which are cheaper than long revert strings.