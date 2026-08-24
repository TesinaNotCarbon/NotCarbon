# CREScoringOracle

## Summary

`CREScoringOracle` is the Chainlink CRE adapter for project scoring. `ProjectManager` creates a scoring request, the oracle emits `ScoringRequested`, the CRE scoring workflow reacts to that EVM log, reads the canonical request from this oracle, reads the project cell id from `ProjectManager`, calls the Scoring API, and writes a signed report back through the configured CRE forwarder.

The report format is:

```solidity
abi.encode(bytes32 requestId, uint256 measurementDate, uint256 scoring, uint256 fraudScoring)
```

Scores are integer percentages in `0..100`. `measurementDate` must be non-zero.

## Easy interface guide

### Who calls what

1. `ProjectManager` calls `requestScoring(projectAddress)`.
2. CRE calls inherited `onReport(metadata, report)` through the trusted forwarder.
3. The oracle calls `ProjectManager.receiveProjectScoring(requestId, measurementDate, scoring, fraudScoring)`.
4. Admins can update receiver/forwarder configuration.

### Constructor

```solidity
constructor(address _receiver, address _admin, address _forwarder)
```

- `_receiver`: contract that can create scoring requests and receives results, normally `ProjectManager`.
- `_admin`: owner/admin for adapter configuration.
- `_forwarder`: Chainlink CRE Keystone forwarder, or the mock forwarder returned by `cre workflow supported-chains` for local simulation with broadcast.

### Request creation

```solidity
function requestScoring(address projectAddress) external returns (bytes32 requestId)
```

- Only callable by `receiver`.
- Requires configured forwarder and non-zero `projectAddress`.
- Increments `requestNonce`.
- Stores:
  - `scoringRequestExists[requestId] = true`
  - `scoringRequestPending[requestId] = true`
  - `requestProject[requestId] = projectAddress`
- Emits:

```solidity
event ScoringRequested(bytes32 indexed requestId, address indexed projectAddress);
```

The CRE workflow must use this event as an EVM Log Trigger. It should not depend on externally supplied HTTP payload data.

### Canonical request read for CRE

```solidity
function getScoringRequest(bytes32 requestId)
    external
    view
    returns (address projectAddress, bool exists, bool pending)
```

The workflow uses this getter after decoding the event. If `exists` is false or `pending` is false, the workflow must stop. The workflow then reads `ProjectManager.getProjectCellId(projectAddress)` to get the canonical cell id before calling the Scoring API.

### Report handling

CRE submits reports through inherited:

```solidity
function onReport(bytes calldata metadata, bytes calldata report) external
```

`ReceiverTemplate` verifies that `msg.sender` is the configured forwarder. `_processReport` then decodes:

```solidity
(bytes32 requestId, uint256 measurementDate, uint256 scoring, uint256 fraudScoring)
```

It rejects:

- unknown request ids,
- completed/replayed requests,
- `measurementDate == 0`,
- `scoring > 100`,
- `fraudScoring > 100`.

After validation, it marks the request as no longer pending, emits `ScoringReported`, and forwards the result to the receiver.

### Configuration/read helpers

- `setReceiver(address _receiver)`: admin-only receiver update.
- `isConfigured()`: true when the forwarder address is non-zero.
- Inherited from `ReceiverTemplate`:
  - `getForwarderAddress()`
  - `setForwarderAddress(address)`
  - `setExpectedWorkflowId(bytes32)`
  - `setExpectedAuthor(address)`
  - metadata getters.

For `cre workflow simulate --broadcast` with MockKeystoneForwarder, do **not** configure expected workflow id or expected author, because the mock forwarder does not provide that metadata.

## Public state

- `admin`: adapter admin.
- `receiver`: expected `ProjectManager`.
- `requestNonce`: monotonically increasing request sequence.
- `scoringRequestExists(requestId)`: request was created.
- `scoringRequestPending(requestId)`: request is still fulfillable.
- `requestProject(requestId)`: canonical project address.

## Events

```solidity
event ScoringRequested(bytes32 indexed requestId, address indexed projectAddress);
event ScoringReported(
    bytes32 indexed requestId,
    address indexed projectAddress,
    uint256 measurementDate,
    uint256 scoring,
    uint256 fraudScoring
);
event ReceiverUpdated(address indexed receiver);
```

## Implementation details

Request ids are generated with:

```solidity
keccak256(abi.encodePacked(block.chainid, address(this), projectAddress, nonce))
```

This ties each request to the chain, oracle instance, project, and nonce. The oracle only verifies request/report validity and forwards the result. `ProjectManager` is responsible for project eligibility, request correlation, duplicate/non-increasing measurement-date rejection, and history storage.
