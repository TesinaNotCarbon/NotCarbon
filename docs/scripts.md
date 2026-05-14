# Deploy and Setup Scripts

This document explains what the deploy and setup scripts do, their prerequisites, environment variables, and current flow.

## Deploy.s.sol

### What it does
- Deploys the core contracts in the correct order.
- Sets the token price in ProjectManager.
- Mints tokens in CarbonCreditToken to the token contract address.
- Prints deployed addresses and parameters to the console.

### Flow
1. Reads `PRIVATE_KEY`, `PRICE_PER_TOKEN`, and `MINT_AMOUNT`.
2. Deploys: RoleManager, CompanyManager, ProjectManager, CarbonCreditToken, CarbonCreditMarket.
3. Sets `pricePerToken` in ProjectManager.
4. Mints `MINT_AMOUNT` in CarbonCreditToken (to the contract address).
5. Logs addresses and parameters.

### Environment variables
- `PRIVATE_KEY` (required): deployer key.
- `PRICE_PER_TOKEN` (optional, default 10): initial token price.
- `MINT_AMOUNT` (optional, default 10000): number of tokens to mint.

### Preconditions and permissions
- The deployer becomes admin of RoleManager.
- `setPricePerToken` requires staff or admin; the deployer is admin.
- `mint` requires staff or admin; the deployer is admin.

### Expected output
- Addresses of all contracts and the values of `PricePerToken` and `MintAmount`.

```
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

## Setup.s.sol

### What it does
- Configures roles (adds staff if provided).
- Sets `pricePerToken`.
- Mints tokens ensuring it covers the total tokens for the projects to be created.
- Configures Chainlink (optional).
- Creates two projects with different states: one stays unapproved and the other advances to `Milestone1` if mock is enabled.

### Flow
1. Reads existing contract addresses (`ROLE_MANAGER_ADDRESS`, `PROJECT_MANAGER_ADDRESS`, `CARBON_CREDIT_TOKEN_ADDRESS`).
2. Adds staff if `STAFF_ADDRESS` is defined and not already staff.
3. Sets `pricePerToken`.
4. If `SETUP_PROJECTS=1`, computes the minimum mint required by the sum of tokens for both projects.
5. Mints tokens if `MINT_AMOUNT > 0`.
6. If `SET_CHAINLINK=1`, configures the oracle and disables the mock.
7. If `SETUP_PROJECTS=1`, registers two projects.
8. If `ADVANCE_PROJECT2=1` and `MOCK_VALIDATION=1`, validates via mock and advances the second project to `Approved` and `Milestone1`.

### Basic environment variables
- `PRIVATE_KEY` (required)
- `ROLE_MANAGER_ADDRESS` (required)
- `PROJECT_MANAGER_ADDRESS` (required)
- `CARBON_CREDIT_TOKEN_ADDRESS` (required)
- `STAFF_ADDRESS` (optional)
- `PRICE_PER_TOKEN` (optional, default 10)
- `MINT_AMOUNT` (optional, default 10000; adjusted to project total if lower)

### Project environment variables
- `SETUP_PROJECTS` (optional, default 1)
- `PROJECT1_NAME` (default "Reforestacion A")
- `PROJECT1_DESCRIPTION` (default "Proyecto inicial")
- `PROJECT1_TOKENS` (default 1000)
- `PROJECT1_CELL_ID` (default "cell-1")
- `PROJECT2_NAME` (default "Eolico B")
- `PROJECT2_DESCRIPTION` (default "Proyecto en fase 1")
- `PROJECT2_TOKENS` (default 2000)
- `PROJECT2_CELL_ID` (default "cell-2")
- `ADVANCE_PROJECT2` (optional, default 1)
- `MOCK_VALIDATION` (optional, default 1)

### Chainlink environment variables
- `SET_CHAINLINK` (optional, default 0)
- `CHAINLINK_LINK_TOKEN`
- `CHAINLINK_ORACLE`
- `CHAINLINK_JOB_ID`
- `CHAINLINK_FEE`

### Preconditions and permissions
- `setPricePerToken` requires staff or admin.
- `mint` requires staff or admin.
- `mockValidationResult` requires admin and only works if no oracle is configured.
- To advance to `Approved`, the project must be `Validated`.

### Expected output
- Addresses of RoleManager, ProjectManager, Token.
- Staff confirmation (if applicable).
- `PricePerToken`, `MintAmount`.
- Addresses of Project1 and Project2.
- Project2 state if it advanced to `Milestone1`.

## SmokeTest.s.sol

### What it does
- Runs an end-to-end flow to validate the happy path.
- Registers a project if it does not exist and validates it (mock if no oracle).
- Advances the project to `Milestone4`.
- Creates and approves a company.
- Buys tokens from the market.

### Flow
1. Reads base addresses (`PROJECT_MANAGER_ADDRESS`, `COMPANY_MANAGER_ADDRESS`, `TOKEN_ADDRESS`, `MARKET_ADDRESS`).
2. Registers a project if `PROJECT_ADDRESS` is not defined.
3. Validates via mock if no oracle; if an oracle exists, sends the request and stops the script.
4. Advances the project to `Approved` and milestones up to `Milestone4`.
5. Creates a company if `COMPANY_ADDRESS` is not defined and approves it.
6. Buys tokens from the market for the requested amount.

### Basic environment variables
- `PRIVATE_KEY` (required)
- `PROJECT_MANAGER_ADDRESS` (required)
- `COMPANY_MANAGER_ADDRESS` (required)
- `TOKEN_ADDRESS` (required)
- `MARKET_ADDRESS` (required)
- `BUY_AMOUNT` (optional, default 10)

### Project and company environment variables
- `PROJECT_ADDRESS` (optional)
- `PROJECT_NAME` (default "SmokeProject")
- `PROJECT_DESCRIPTION` (default "Smoke test project")
- `PROJECT_TOTAL_TOKENS` (default 1000)
- `PROJECT_CELL_ID` (default "CELL-SMOKE-001")
- `COMPANY_ADDRESS` (optional)
- `COMPANY_NAME` (default "SmokeCompany")
- `COMPANY_MONTHLY_EMISSIONS` (default 100)

### Expected output
- Project and Company addresses.
- `BuyAmount` and `TotalCost`.

## Quick example (anvil/local)

## Recommended sequence (anvil -> deploy -> setup)

1) Start anvil in a terminal:

```bash
anvil
```

2) Deploy contracts on the same network:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

3) Export the addresses printed by deploy:

```bash
export ROLE_MANAGER_ADDRESS=0x...
export PROJECT_MANAGER_ADDRESS=0x...
export CARBON_CREDIT_TOKEN_ADDRESS=0x...
```

4) Run setup on the same network:

```bash
forge script script/Setup.s.sol:Setup --rpc-url http://127.0.0.1:8545 --broadcast
```

## Recommended sequence (Sepolia)

1) Define the RPC and a funded key on Sepolia:

```bash
export SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/<project-id>
export PRIVATE_KEY=0x...
```

2) Deploy on Sepolia:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --broadcast --priority-gas-price 10000
```

3) Export the addresses printed by deploy:

```bash
export ROLE_MANAGER_ADDRESS=0x...
export PROJECT_MANAGER_ADDRESS=0x...
export CARBON_CREDIT_TOKEN_ADDRESS=0x...
export COMPANY_MANAGER_ADDRESS=0x...
export MARKET_ADDRESS=0x...
```

4) Setup on Sepolia (no Chainlink):

```bash
export SET_CHAINLINK=0
export MOCK_VALIDATION=1

forge script script/Setup.s.sol:Setup --rpc-url $SEPOLIA_RPC_URL --broadcast --slow --priority-gas-price 10000
```

Notes:
- To use Chainlink, set `SET_CHAINLINK=1` and fill `CHAINLINK_*`; `MOCK_VALIDATION` is automatically disabled.
- Save deploy addresses, since Sepolia does not reset like anvil.

```bash
export PRIVATE_KEY=0x...
export ROLE_MANAGER_ADDRESS=0x...
export PROJECT_MANAGER_ADDRESS=0x...
export CARBON_CREDIT_TOKEN_ADDRESS=0x...
export PRICE_PER_TOKEN=10
export SETUP_PROJECTS=1
export MOCK_VALIDATION=1
export ADVANCE_PROJECT2=1

forge script script/Setup.s.sol:Setup --rpc-url http://127.0.0.1:8545 --broadcast
```

