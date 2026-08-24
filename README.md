# Carbon Credit Platform (Foundry)

Smart-contract platform for carbon-credit lifecycle management:

1. Role and permissions management.
2. Company onboarding and approval.
3. Project registration and staged token release.
4. Carbon credit token issuance and transfers.
5. Market purchases across multiple projects.

This repository is configured to use Foundry for build, test, scripting, and deployment.

## Team

1. Matias Duran
2. Lucio Bianchi Pradas

## Tech Stack

1. Solidity 0.8.x
2. Foundry (forge, cast, anvil)
3. OpenZeppelin Contracts
4. Chainlink CRE SDK and CRE receiver pattern

## Project Structure

1. src/: core contracts.
2. src/interfaces/: shared interfaces.
3. script/Deploy.s.sol: main Foundry deployment script.
4. script/DeployCREValidation.s.sol: CRE validation adapter deployment script.
5. cre/validation-workflow/: Chainlink CRE HTTP workflow for polygon validation.
6. test/: Foundry unit tests.
7. script/deploy.py and script/project.py: legacy Brownie scripts (kept for reference).

## Prerequisites

1. Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Confirm installation:

```bash
forge --version
cast --version
anvil --version
```

## Environment Variables

Create a .env file in the project root:

```bash
PRIVATE_KEY=0xyour_private_key
RPC_URL=https://your_rpc_endpoint
ETHERSCAN_API_KEY=your_etherscan_api_key
```

Load variables in your shell:

```bash
source .env
```

If your shell does not export variables automatically from source, use:

```bash
set -a
source .env
set +a
```

## Install Dependencies

```bash
forge install
```

This project uses:

1. forge-std
2. OpenZeppelin/openzeppelin-contracts

## Basic Commands

Build contracts:

```bash
forge build
```

Run tests:

```bash
forge test
```

Run verbose tests:

```bash
forge test -vvv
```

Format Solidity files:

```bash
forge fmt
```

## Testing and Deployment Guide

See [docs/testing.md](docs/testing.md) for local (Anvil) and Sepolia flows, plus the new setup and smoke-test scripts.

## Local Deployment (Anvil)

1. Start local node:

```bash
anvil
```

2. Copy one private key from an Anvil account and export it:

```bash
export PRIVATE_KEY=0xyour_anvil_private_key
```

3. Deploy contracts locally:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

Expected behavior:

1. Contracts are deployed in dependency order.
2. Initial configuration is executed (price per token and initial mint).
3. Contract addresses are printed to the console.

## Testnet Deployment (Sepolia)

1. Set your network variables:

```bash
export PRIVATE_KEY=0xyour_private_key
export RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
export ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
```

2. Deploy to Sepolia:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --broadcast
```

3. Deploy and verify (optional):

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY"
```

## Deployment Script Details

The script in script/Deploy.s.sol deploys in this order:

1. RoleManager
2. CompanyManager (uses RoleManager)
3. ProjectManager (uses RoleManager and CompanyManager)
4. CarbonCreditToken (uses ProjectManager and RoleManager)
5. CarbonCreditMarket (uses ProjectManager and CompanyManager)

Then it runs bootstrap actions:

1. setPricePerToken(PRICE_PER_TOKEN) (default 10)
2. mint(MINT_AMOUNT) (default 10000)

## Useful Cast Commands

Read contract state:

```bash
cast call <CONTRACT_ADDRESS> "admin()(address)" --rpc-url "$RPC_URL"
```

Send transaction:

```bash
cast send <CONTRACT_ADDRESS> "addStaff(address)" <STAFF_ADDRESS> \
  --private-key "$PRIVATE_KEY" \
  --rpc-url "$RPC_URL"
```

## Current Sepolia References

1. PROJECT_MANAGER_CONTRACT_ADDRESS=0x5f160a757743184F1A665179B55408f0107b8aD5
	https://sepolia.etherscan.io/address/0x5f160a757743184F1A665179B55408f0107b8aD5
2. CARBON_CREDIT_CONTRACT_ADDRESS=0x7C11396245828083b0c8A2633130Dd99583d2d4B
	https://sepolia.etherscan.io/address/0x7C11396245828083b0c8A2633130Dd99583d2d4B
3. ROLE_MANAGER_CONTRACT_ADDRESS=0xAb5F933a259d9cC2f4Db249Ee8E5512637083c68
	https://sepolia.etherscan.io/address/0xAb5F933a259d9cC2f4Db249Ee8E5512637083c68
4. COMPANY_MANAGER_CONTRACT_ADDRESS=0x7506354d8ba8674E637C44c35692B4f9F8748A8C
	https://sepolia.etherscan.io/address/0x7506354d8ba8674E637C44c35692B4f9F8748A8C
5. CARBON_CREDIT_MARKET_CONTRACT_ADDRESS=0xEFF6794f19f64d276916c4B7e3Ac07c171b5908A
	https://sepolia.etherscan.io/address/0xEFF6794f19f64d276916c4B7e3Ac07c171b5908A
6. PROJECT_EXAMPLE=0x0B006416CBDB9b0CDc1f72A9ffD14d07fA3f9aE2
	https://sepolia.etherscan.io/address/0x0B006416CBDB9b0CDc1f72A9ffD14d07fA3f9aE2
7. COMPANY_EXAMPLE=0xE3526F7FB453C1201Fc3a256bE0ee5B27AdBa97A
	https://sepolia.etherscan.io/address/0xE3526F7FB453C1201Fc3a256bE0ee5B27AdBa97A

## CRE Sepolia end-to-end simulation (no DON deployment)

This demo uses two local CRE simulations with real Sepolia RPC/HTTP calls and on-chain writes through the tenant MockKeystoneForwarder. Do **not** deploy workflows to a DON and do **not** configure `expectedWorkflowId`, `expectedAuthor`, or metadata validation on the oracle receivers; the mock forwarder used by `cre workflow simulate --broadcast` does not provide that metadata.

### 1. Authenticate and get the mock forwarder

```bash
cre login
cre whoami

export CRE_FORWARDER=$(cre workflow supported-chains --output json \
  | jq -r '.[] | select(.chainName=="ethereum-testnet-sepolia") | .address')
echo "$CRE_FORWARDER"
```

### 2. Deploy and configure contracts on Sepolia

```bash
export PRIVATE_KEY=0x...
export RPC_URL=https://ethereum-sepolia-rpc.publicnode.com

forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast

export PROJECT_MANAGER_ADDRESS=<ProjectManager proxy from Deploy output>
export CARBON_CREDIT_TOKEN_ADDRESS=<CarbonCreditToken proxy from Deploy output>

forge script script/DeployCREOracles.s.sol:DeployCREOracles \
  --rpc-url "$RPC_URL" --broadcast

export VALIDATION_ORACLE_ADDRESS=<CREValidationOracle from output>
export SCORING_ORACLE_ADDRESS=<CREScoringOracle from output>
```

Configure the workflow JSON files. The log triggers use Base64-encoded addresses/topics.

```bash
addr_b64() { python3 - <<'PY' "$1"
import base64, sys
print(base64.b64encode(bytes.fromhex(sys.argv[1][2:])).decode())
PY
}

export VALIDATION_API_BASE_URL=http://127.0.0.1:8000
export SCORING_API_BASE_URL=http://127.0.0.1:3000

jq --arg a "$VALIDATION_ORACLE_ADDRESS" \
   --arg b "$(addr_b64 "$VALIDATION_ORACLE_ADDRESS")" \
   --arg api "$VALIDATION_API_BASE_URL" \
   '.validationOracleAddress=$a | .validationOracleAddressBase64=$b | .validationApiBaseUrl=$api' \
   cre/validation-workflow/config.staging.json > /tmp/validation-config.json \
   && mv /tmp/validation-config.json cre/validation-workflow/config.staging.json

jq --arg a "$SCORING_ORACLE_ADDRESS" \
   --arg b "$(addr_b64 "$SCORING_ORACLE_ADDRESS")" \
   --arg pm "$PROJECT_MANAGER_ADDRESS" \
   --arg api "$SCORING_API_BASE_URL" \
   '.scoringOracleAddress=$a | .scoringOracleAddressBase64=$b | .projectManagerAddress=$pm | .scoringApiBaseUrl=$api' \
   cre/scoring-workflow/config.staging.json > /tmp/scoring-config.json \
   && mv /tmp/scoring-config.json cre/scoring-workflow/config.staging.json
```

Topic constants already in config:

- `ValidationRequested(bytes32,address,string)`: `g31K1ZS6d9kiBKrjz/L7nP7uga6Vdv+z7sU4ovyeKg8=`
- `ScoringRequested(bytes32,address)`: `mWK3WCIMwt781nif8gCFzRJwONL4H1fANSz3aMb2Rio=`

### 3. Start the APIs

```bash
# terminal 1
cd ../AreaValidationAPI
uvicorn app.main:app --host 127.0.0.1 --port 8000

# terminal 2
cd ../ScoringAPI
export AI_PROVIDER=deterministic
export BLOCKCHAIN_ADAPTER=web3
export RPC_URL=$RPC_URL
export PROJECT_MANAGER_ADDRESS=$PROJECT_MANAGER_ADDRESS
export PROJECT_MANAGER_ABI_PATH=../NotCarbon/out/ProjectManager.sol/ProjectManager.json
uvicorn main:app --host 127.0.0.1 --port 3000
```

### 4. Create a project and request validation on-chain

```bash
cast send "$PROJECT_MANAGER_ADDRESS" "setPricePerToken(uint256)" 10000000000000000 \
  --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL"
cast send "$CARBON_CREDIT_TOKEN_ADDRESS" "mint(uint256)" 1000 \
  --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL"

export PROJECT_ADDRESS=$(cast send "$PROJECT_MANAGER_ADDRESS" \
  "registerProject(string,string,address,uint256,string)(address)" \
  "CRE demo" "Sepolia CRE validation/scoring demo" "$CARBON_CREDIT_TOKEN_ADDRESS" 100 "healthy-forest-cell" \
  --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --json | jq -r '.logs[-1].topics[1]' | cast parse-bytes32-address)

export VALIDATION_TX=$(cast send "$PROJECT_MANAGER_ADDRESS" "requestProjectValidation(address)(bytes32)" "$PROJECT_ADDRESS" \
  --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --json | jq -r '.transactionHash')

export VALIDATION_EVENT_INDEX=$(cast receipt "$VALIDATION_TX" --rpc-url "$RPC_URL" --json \
  | jq -r --arg a "${VALIDATION_ORACLE_ADDRESS,,}" --arg t "0x837d4ad594ba77d92204aae3cff2fb9cfeee81ae9576ffb3eec538a2fc9e2a0f" \
    '.logs | to_entries[] | select((.value.address|ascii_downcase)==$a and .value.topics[0]==$t) | .key')
echo "$VALIDATION_TX $VALIDATION_EVENT_INDEX"
```

### 5. Simulate validation: dry-run, then broadcast

```bash
cd cre
npm --prefix validation-workflow install
npm --prefix validation-workflow run typecheck

cre workflow simulate validation-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$VALIDATION_TX" --evm-event-index "$VALIDATION_EVENT_INDEX" \
  --limits none

cre workflow simulate validation-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$VALIDATION_TX" --evm-event-index "$VALIDATION_EVENT_INDEX" \
  --broadcast --limits default
cd ..
```

Verify validation state:

```bash
cast call "$PROJECT_MANAGER_ADDRESS" \
  "getValidationStatus(address)(bool,bool,bool,uint256)" "$PROJECT_ADDRESS" --rpc-url "$RPC_URL"
```

Approve the validated project before scoring:

```bash
cast send "$PROJECT_MANAGER_ADDRESS" "updateProjectStatus(address,uint8)" "$PROJECT_ADDRESS" 2 \
  --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL"
```

### 6. Request scoring and simulate scoring

```bash
export SCORING_TX=$(cast send "$PROJECT_MANAGER_ADDRESS" "requestProjectScoring(address)(bytes32)" "$PROJECT_ADDRESS" \
  --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --json | jq -r '.transactionHash')

export SCORING_EVENT_INDEX=$(cast receipt "$SCORING_TX" --rpc-url "$RPC_URL" --json \
  | jq -r --arg a "${SCORING_ORACLE_ADDRESS,,}" --arg t "0x9962b758220cc2defcd6789ff20085cd127038d2f81f57c0352cf768c6f6462a" \
    '.logs | to_entries[] | select((.value.address|ascii_downcase)==$a and .value.topics[0]==$t) | .key')
echo "$SCORING_TX $SCORING_EVENT_INDEX"

cd cre
npm --prefix scoring-workflow install
npm --prefix scoring-workflow run typecheck

cre workflow simulate scoring-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$SCORING_TX" --evm-event-index "$SCORING_EVENT_INDEX" \
  --limits none

cre workflow simulate scoring-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$SCORING_TX" --evm-event-index "$SCORING_EVENT_INDEX" \
  --broadcast --limits default
cd ..
```

Verify scoring history:

```bash
cast call "$PROJECT_MANAGER_ADDRESS" "getProjectScoringCount(address)(uint256)" "$PROJECT_ADDRESS" --rpc-url "$RPC_URL"
cast call "$PROJECT_MANAGER_ADDRESS" "getProjectScoringAt(address,uint256)(uint256,uint256,uint256,uint256)" \
  "$PROJECT_ADDRESS" 0 --rpc-url "$RPC_URL"
```

### 7. Replay rejection demo

Run the same broadcast simulation again with the same tx hash and event index:

```bash
cd cre
cre workflow simulate validation-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$VALIDATION_TX" --evm-event-index "$VALIDATION_EVENT_INDEX" \
  --broadcast --limits default

cre workflow simulate scoring-workflow --target staging-settings --non-interactive \
  --trigger-index 0 --evm-tx-hash "$SCORING_TX" --evm-event-index "$SCORING_EVENT_INDEX" \
  --broadcast --limits default
```

Expected result: validation fails before writing because the canonical request is no longer pending, and scoring fails because `CREScoringOracle` rejects the completed request replay.
