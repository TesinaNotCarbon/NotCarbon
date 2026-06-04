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

### CRE validation notes

- If a CRE validation adapter is configured, the smoke test will request validation, print the HTTP trigger payload, and then stop.
- Send that payload to the deployed CRE HTTP trigger. The workflow calls `POST /validate-polygon`, writes the report to `CREValidationOracle`, and `ProjectManager` applies the result.
- After the CRE report is written onchain, re-run the smoke test with `PROJECT_ADDRESS` to continue the state progression.

## Tips to avoid re-deploying

- Store addresses from the deploy logs in a JSON file and reuse them with `ROLE_MANAGER_ADDRESS`, `PROJECT_MANAGER_ADDRESS`, `TOKEN_ADDRESS`, `MARKET_ADDRESS` env vars in scripts.
- Use `PROJECT_ADDRESS` and `COMPANY_ADDRESS` to reuse existing entities and avoid cell-id collisions.

## Common errors

- "Cell ID already used.": set a new `PROJECT_CELL_ID` or reuse `PROJECT_ADDRESS`.
- "Project must be validated first.": wait for Chainlink fulfillment or run on Anvil with mock validation.
- "Insufficient token balance in contract": increase `MINT_AMOUNT` and re-run Setup.
