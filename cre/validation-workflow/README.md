# NotCarbon CRE validation workflow

This workflow is triggered through CRE HTTP, calls the external polygon validation API, and writes a signed report to `CREValidationOracle`.

Expected trigger payload:

```json
{
  "request_id": "0x...",
  "project_address": "0x...",
  "cell_id": "bafy..."
}
```

External API call:

```http
POST /validate-polygon
Content-Type: application/json

{ "cell_id": "bafy..." }
```

Report payload written onchain:

```solidity
abi.encode(bytes32 requestId, bool overlap, bool inconclusive)
```

Before deployment, update `config.json` with:

- `httpPublicKey`: EVM address authorized to trigger the workflow.
- `validationApiBaseUrl`: API origin without trailing slash.
- `receiverAddress`: deployed `CREValidationOracle`.
- `chainSelector`: Ethereum Sepolia defaults to `16015286601757825753`.
- `gasLimit`: report submission gas limit.

Run simulation after installing the CRE CLI:

```bash
npm install
npm run simulate
```
