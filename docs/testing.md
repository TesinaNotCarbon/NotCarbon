# Testing and deployment guide

This document describes the recommended flow to test and deploy the contracts locally (Anvil) and on Sepolia using Foundry scripts.

## Prerequisites

- Foundry installed (`forge`, `cast`, `anvil`).
- A funded account for Sepolia.
- Environment variables set in your shell or a `.env` file.

## Environment variables

Required for deploy:

```
PRIVATE_KEY=0xyour_private_key
RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
```

Required for setup:

```
ROLE_MANAGER_ADDRESS=0xrole_manager
PROJECT_MANAGER_ADDRESS=0xproject_manager
TOKEN_ADDRESS=0xtoken
```

Required for smoke test:

```
PROJECT_MANAGER_ADDRESS=0xproject_manager
COMPANY_MANAGER_ADDRESS=0xcompany_manager
TOKEN_ADDRESS=0xtoken
MARKET_ADDRESS=0xmarket
```

Optional (deploy/setup):

```
PRICE_PER_TOKEN=10
MINT_AMOUNT=10000
STAFF_ADDRESS=0xstaff_address
```

Optional (CRE validation setup on Sepolia):

```
SET_CRE=1
VALIDATION_ORACLE_ADAPTER=0xcre_validation_oracle
CRE_FORWARDER=0xkeystone_forwarder
```

Optional (smoke test overrides):

```
PROJECT_ADDRESS=0xexisting_project
PROJECT_NAME=SmokeProject
PROJECT_DESCRIPTION=Smoke test project
PROJECT_TOTAL_TOKENS=1000
PROJECT_CELL_ID=CELL-SMOKE-001
COMPANY_ADDRESS=0xexisting_company
COMPANY_NAME=SmokeCompany
COMPANY_MONTHLY_EMISSIONS=100
BUY_AMOUNT=10
```

## Local flow (Anvil)

1. Start Anvil:

```
anvil
```

2. Export a private key from Anvil and set RPC URL:

```
export PRIVATE_KEY=0xyour_anvil_private_key
export RPC_URL=http://127.0.0.1:8545
```

3. Deploy contracts:

```
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --broadcast
```

4. Run post-deploy setup (price + mint, optional staff/chainlink):

```
forge script script/Setup.s.sol:Setup \
  --rpc-url "$RPC_URL" \
  --broadcast
```

5. Run smoke test:

```
forge script script/SmokeTest.s.sol:SmokeTest \
  --rpc-url "$RPC_URL" \
  --broadcast
```

## Sepolia flow

1. Export your Sepolia settings:

```
export PRIVATE_KEY=0xyour_private_key
export RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
```

2. Deploy contracts:

```
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --broadcast
```

3. Run setup (same variables as local):

```
forge script script/Setup.s.sol:Setup \
  --rpc-url "$RPC_URL" \
  --broadcast
```

4. Run smoke test:

```
forge script script/SmokeTest.s.sol:SmokeTest \
  --rpc-url "$RPC_URL" \
  --broadcast
```

### CRE validation and scoring notes

- If a CRE validation adapter is configured, the smoke test will request validation, print the HTTP trigger payload, and then stop.
- Send that payload to the deployed CRE HTTP trigger. The workflow calls `POST /validate-polygon`, writes the report to `CREValidationOracle`, and `ProjectManager` applies the result.
- After the CRE validation report is written onchain, re-run the smoke test with `PROJECT_ADDRESS` to continue the state progression.
- Project scoring uses a separate `CREScoringOracle` adapter. The scoring workflow is intended to be triggered from the frontend/backend with a project identifier; CRE calls the scoring API and writes `(projectAddress, measurementDate, scoring, fraudScoring)` to `CREScoringOracle`.
- Historic scoring data can be verified with `ProjectManager.getProjectScoringHistory`, or paged with `getProjectScoringCount` and `getProjectScoringAt`.

### Deploying the Chainlink CRE workflow

Use the official Chainlink CRE documentation for the current CLI install, environment setup, network support, forwarder addresses, workflow deployment command, and HTTP trigger invocation. The repository workflow code lives in `cre/validation-workflow/` and is designed to be deployed with that process.

Recommended flow:

1. Deploy the core contracts and `CREValidationOracle` first. `CREValidationOracle` must be deployed with the official CRE forwarder for the target network:

```
export PROJECT_MANAGER_ADDRESS=0xproject_manager
export CRE_FORWARDER=0xofficial_cre_forwarder

forge script script/DeployCREValidation.s.sol:DeployCREValidation \
  --rpc-url "$RPC_URL" \
  --broadcast
```

2. Edit `cre/validation-workflow/config.json` using the values from your deployment:

```
{
  "httpPublicKey": "0xauthorized_trigger_address",
  "validationApiBaseUrl": "https://your-validation-api.example.com",
  "receiverAddress": "0xCREValidationOracle",
  "chainSelector": "16015286601757825753",
  "gasLimit": "500000"
}
```

For Sepolia, `chainSelector` is `16015286601757825753`. Confirm this and the forwarder address against the Chainlink docs before deploying.

3. Install and check the workflow locally:

```
cd cre/validation-workflow
npm install
npm run typecheck
npm run simulate
```

4. Deploy the workflow using the Chainlink CRE docs/CLI. After deployment, save the workflow id and, if provided by the CLI, the workflow author address.

5. Lock the onchain receiver to the deployed workflow before real testing:

```
cast send "$VALIDATION_ORACLE_ADAPTER" \
  "setExpectedWorkflowId(bytes32)" "$CRE_WORKFLOW_ID" \
  --private-key "$PRIVATE_KEY" \
  --rpc-url "$RPC_URL"

cast send "$VALIDATION_ORACLE_ADAPTER" \
  "setExpectedAuthor(address)" "$CRE_AUTHOR" \
  --private-key "$PRIVATE_KEY" \
  --rpc-url "$RPC_URL"
```

6. Trigger validation by calling `ProjectManager.requestProjectValidation(project)`, then send the emitted request data to the deployed CRE HTTP trigger:

```
{
  "request_id": "0x...",
  "project_address": "0x...",
  "cell_id": "CELL-001"
}
```

7. Verify the validation result onchain:

```
cast call "$PROJECT_MANAGER_ADDRESS" \
  "getValidationStatus(address)(bool,bool,bool,uint256)" "$PROJECT_ADDRESS" \
  --rpc-url "$RPC_URL"
```

8. For scoring, deploy `CREScoringOracle` with the same official CRE forwarder, configure it through `ProjectManager.setScoringOracleAdapter`, and lock it to the scoring workflow id/author if desired. The scoring report payload must ABI-encode:

```
(address projectAddress, uint256 measurementDate, uint256 scoring, uint256 fraudScoring)
```

The workflow can resolve a project's cell id before calling the scoring API with:

```
cast call "$PROJECT_MANAGER_ADDRESS" \
  "getProjectCellId(address)(string)" "$PROJECT_ADDRESS" \
  --rpc-url "$RPC_URL"
```

Verify stored scoring data with:

```
cast call "$PROJECT_MANAGER_ADDRESS" \
  "getProjectScoringAt(address,uint256)(uint256,uint256,uint256,uint256)" "$PROJECT_ADDRESS" 0 \
  --rpc-url "$RPC_URL"
```

## Tips to avoid re-deploying

- Store addresses from the deploy logs in a JSON file and reuse them with `ROLE_MANAGER_ADDRESS`, `PROJECT_MANAGER_ADDRESS`, `TOKEN_ADDRESS`, `MARKET_ADDRESS` env vars in scripts.
- Use `PROJECT_ADDRESS` and `COMPANY_ADDRESS` to reuse existing entities and avoid cell-id collisions.

## Common errors

- "Cell ID already used.": set a new `PROJECT_CELL_ID` or reuse `PROJECT_ADDRESS`.
- "Project must be validated first.": wait for Chainlink fulfillment or run on Anvil with mock validation.
- "Insufficient token balance in contract": increase `MINT_AMOUNT` and re-run Setup.
