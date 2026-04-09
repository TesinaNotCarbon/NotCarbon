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

## Project Structure

1. src/: core contracts.
2. src/interfaces/: shared interfaces.
3. script/Deploy.s.sol: main Foundry deployment script.
4. test/: Foundry unit tests.
5. script/deploy.py and script/project.py: legacy Brownie scripts (kept for reference).

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

1. setPricePerToken(10)
2. mint(10000)

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
