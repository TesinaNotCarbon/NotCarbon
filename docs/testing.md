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

Optional (CRE oracle setup on Sepolia):

```
SET_CRE=1
VALIDATION_ORACLE_ADAPTER=0xcre_validation_oracle
SET_SCORING_CRE=1
SCORING_ORACLE_ADAPTER=0xcre_scoring_oracle
CRE_FORWARDER=0xmock_or_real_keystone_forwarder
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

- Validation and scoring are two separate CRE workflows.
- Both workflows use EVM Log Triggers, not external HTTP trigger payloads.
- Validation reacts to `CREValidationOracle.ValidationRequested` and writes `abi.encode(bytes32 requestId, bool overlap, bool inconclusive)`.
- Scoring reacts to `CREScoringOracle.ScoringRequested` and writes `abi.encode(bytes32 requestId, uint256 measurementDate, uint256 scoring, uint256 fraudScoring)`.
- Both workflows decode the event and then read canonical on-chain request state before calling APIs.
- For local `cre workflow simulate --broadcast`, use the MockKeystoneForwarder returned by `cre workflow supported-chains --output json` and do **not** configure `expectedWorkflowId` or `expectedAuthor` on the receivers.
- Historic scoring data can be verified with `ProjectManager.getProjectScoringHistory`, or paged with `getProjectScoringCount` and `getProjectScoringAt`.

### CRE simulation flow

1. Authenticate with CRE and get the Sepolia mock forwarder:

```
cre login
export CRE_FORWARDER=$(cre workflow supported-chains --output json \
  | jq -r '.[] | select(.chainName=="ethereum-testnet-sepolia") | .address')
```

2. Deploy the core contracts and both CRE oracles:

```
export PROJECT_MANAGER_ADDRESS=0xproject_manager

forge script script/DeployCREOracles.s.sol:DeployCREOracles \
  --rpc-url "$RPC_URL" \
  --broadcast
```

3. Configure `cre/validation-workflow/config.staging.json` and `cre/scoring-workflow/config.staging.json` with deployed oracle addresses, Base64-encoded oracle addresses, API URLs, and `chainSelectorName: ethereum-testnet-sepolia`.

4. Install and typecheck both workflows:

```
npm --prefix cre/validation-workflow install
npm --prefix cre/validation-workflow run typecheck
npm --prefix cre/scoring-workflow install
npm --prefix cre/scoring-workflow run typecheck
```

5. Request validation on-chain and capture the transaction hash/log index for `ValidationRequested`:

```
cast send "$PROJECT_MANAGER_ADDRESS" "requestProjectValidation(address)(bytes32)" "$PROJECT_ADDRESS" \
  --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL"
```

6. Simulate validation first as dry-run, then broadcast:

```
cre workflow simulate cre/validation-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$VALIDATION_TX" --evm-event-index "$VALIDATION_EVENT_INDEX" \
  --limits none

cre workflow simulate cre/validation-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$VALIDATION_TX" --evm-event-index "$VALIDATION_EVENT_INDEX" \
  --broadcast --limits default
```

7. Verify validation result:

```
cast call "$PROJECT_MANAGER_ADDRESS" \
  "getValidationStatus(address)(bool,bool,bool,uint256)" "$PROJECT_ADDRESS" \
  --rpc-url "$RPC_URL"
```

8. After approval, request scoring and capture the `ScoringRequested` tx hash/log index:

```
cast send "$PROJECT_MANAGER_ADDRESS" "updateProjectStatus(address,uint8)" "$PROJECT_ADDRESS" 2 \
  --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL"

cast send "$PROJECT_MANAGER_ADDRESS" "requestProjectScoring(address)(bytes32)" "$PROJECT_ADDRESS" \
  --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL"
```

9. Simulate scoring first as dry-run, then broadcast:

```
cre workflow simulate cre/scoring-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$SCORING_TX" --evm-event-index "$SCORING_EVENT_INDEX" \
  --limits none

cre workflow simulate cre/scoring-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$SCORING_TX" --evm-event-index "$SCORING_EVENT_INDEX" \
  --broadcast --limits default
```

10. Verify stored scoring data:

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
