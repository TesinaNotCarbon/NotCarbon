# CREScoringOracle

## Summary

`CREScoringOracle` is the Chainlink CRE adapter for project scoring. It receives reports through `ReceiverTemplate`, decodes the score payload, verifies that the referenced project is registered in `ProjectManager`, and forwards the result to `ProjectManager.receiveProjectScoring` for storage in the project's on-chain scoring history.

## Interface

- `constructor(address _receiver, address _admin, address _forwarder)`: initializes the scoring receiver, admin, and trusted Chainlink forwarder.
- `setReceiver(address _receiver)`: admin-only receiver update.
- `isConfigured()`: returns whether the inherited receiver template has a non-zero forwarder address.
- Inherited receiver/admin methods from `ReceiverTemplate`: `onReport`, `getForwarderAddress`, `setForwarderAddress`, `setExpectedWorkflowId`, `setExpectedAuthor`, and related getters.

## Report format

CRE reports must ABI-encode the following tuple:

```solidity
(address projectAddress, uint256 measurementDate, uint256 scoring, uint256 fraudScoring)
```

`projectAddress` is the on-chain project identifier. `ProjectManager.getProjectCellId(projectAddress)` can be used by off-chain services to resolve the cell id associated with the project when the scoring API needs geospatial context.

## Implementation details

The contract extends `ReceiverTemplate`, so only the configured Chainlink forwarder can deliver reports through `onReport`. `_processReport` decodes the scoring tuple, rejects the zero project address, checks `ProjectManager.isProjectRegistered(projectAddress)`, emits `ScoringReported`, and calls `IProjectScoringReceiver(receiver).receiveProjectScoring`. The receiver is expected to be `ProjectManager`, and the manager restricts `receiveProjectScoring` to the configured `scoringOracleAdapter`, keeping frontend users and arbitrary callers from writing scores directly.
