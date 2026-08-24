# CREValidationOracle

## Summary

`CREValidationOracle` is the Chainlink CRE adapter for territorial/project validation. `ProjectManager` creates a request, the oracle emits `ValidationRequested`, the CRE validation workflow reacts to that EVM log, reads the canonical request back from this oracle, calls the Area Validation API, and writes a signed report back through the configured CRE forwarder.

The report format is intentionally stable:

```solidity
abi.encode(bytes32 requestId, bool overlap, bool inconclusive)
```

## Easy interface guide

### Who calls what

1. `ProjectManager` calls `requestValidation(projectAddress, cellId)`.
2. CRE calls inherited `onReport(metadata, report)` through the trusted forwarder.
3. The oracle calls `ProjectManager.receiveValidationResult(requestId, overlap, inconclusive)`.
4. Admins can update receiver/forwarder configuration.

### Constructor

```solidity
constructor(address _receiver, address _admin, address _forwarder)
```

- `_receiver`: contract that can create validation requests and receives results, normally `ProjectManager`.
- `_admin`: owner/admin for adapter configuration.
- `_forwarder`: Chainlink CRE Keystone forwarder, or the mock forwarder returned by `cre workflow supported-chains` for local simulation with broadcast.

### Request creation

```solidity
function requestValidation(address projectAddress, string calldata cellId) external returns (bytes32 requestId)
```

- Only callable by `receiver`.
- Requires configured forwarder, non-zero `projectAddress`, and non-empty `cellId`.
- Increments `requestNonce`.
- Stores:
  - `validationRequestExists[requestId] = true`
  - `validationRequestPending[requestId] = true`
  - `requestProject[requestId] = projectAddress`
  - `requestCellId[requestId] = cellId`
- Emits:

```solidity
event ValidationRequested(bytes32 indexed requestId, address indexed projectAddress, string cellId);
```

The CRE workflow must use this event as an EVM Log Trigger. It should not depend on externally supplied HTTP payload data.

### Canonical request read for CRE

```solidity
function getValidationRequest(bytes32 requestId)
    external
    view
    returns (address projectAddress, string memory cellId, bool exists, bool pending)
```

The workflow uses this getter after decoding the event. The workflow must trust this on-chain state over event/user-supplied data when deciding which project/cell id to validate.

### Report handling

CRE submits reports through inherited:

```solidity
function onReport(bytes calldata metadata, bytes calldata report) external
```

`ReceiverTemplate` verifies that `msg.sender` is the configured forwarder. `_processReport` then decodes:

```solidity
(bytes32 requestId, bool overlap, bool inconclusive)
```

It rejects unknown request ids and completed requests, marks the request as no longer pending, emits `ValidationReported`, and forwards the result to the receiver.

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
- `validationRequestExists(requestId)`: request was created.
- `validationRequestPending(requestId)`: request is still fulfillable.
- `requestProject(requestId)`: canonical project address.
- `requestCellId(requestId)`: canonical cell id.

## Events

```solidity
event ValidationRequested(bytes32 indexed requestId, address indexed projectAddress, string cellId);
event ValidationReported(bytes32 indexed requestId, bool overlap, bool inconclusive);
event ReceiverUpdated(address indexed receiver);
```

## Implementation details

Request ids are generated with:

```solidity
keccak256(abi.encodePacked(block.chainid, address(this), projectAddress, keccak256(bytes(cellId)), nonce))
```

This ties each request to the chain, oracle instance, project, cell id, and nonce. The oracle never validates projects directly; it only tracks request state and forwards the result to `ProjectManager`, which applies project lifecycle rules.
