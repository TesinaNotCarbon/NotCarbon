# Smart Contract Architecture

This document describes the Solidity contracts in `src/`, how they interact, and the main technical decisions and patterns used by the system.

## System overview and interaction flow

The protocol models a carbon-credit marketplace with separately deployed managers, company wallets, project contracts, an ERC-20 credit token, and optional Chainlink CRE validation/scoring paths. `RoleManager` is the shared authorization source for admin/staff actions. `CompanyManager` deploys and approves `Company` contracts, while `ProjectManager` deploys `Project` contracts, controls their lifecycle, and stores project scoring history. `CarbonCreditToken` mints inventory into its own balance and only allows `ProjectManager` to distribute that inventory to newly created projects. `Project` contracts sell released token inventory according to milestone-based release rules. `CarbonCreditMarket` aggregates purchases across all registered projects, letting an approved company buy a target amount from any projects with available inventory. `CREValidationOracle` receives Chainlink CRE reports and forwards validation results back into `ProjectManager`, which can move projects from `Registered` to `Validated` before staff/admin approval advances them further. `CREScoringOracle` receives Chainlink CRE scoring reports and forwards them to `ProjectManager` as immutable historical records.

A typical flow is:

1. Deploy and initialize upgradeable manager contracts and the token contract.
2. Admin configures staff in `RoleManager` and, optionally, configures validation and scoring oracle adapters in `ProjectManager`.
3. Staff/admin mint CCT inventory into the `CarbonCreditToken` contract.
4. A user creates a `Company` via `CompanyManager`; staff/admin approve it.
5. A project creator registers a project through `ProjectManager` with metadata, supply, and a unique cell id.
6. `ProjectManager` deploys a `Project` and transfers the requested token inventory from `CarbonCreditToken` to it.
7. The project is validated by Chainlink CRE or by the admin-only mock path when no oracle is configured.
8. Staff/admin approve the validated project and later advance milestone states.
9. Token release caps increase as the project reaches `Approved` and milestone states.
10. An approved company buys directly from a project or indirectly through `CarbonCreditMarket`.
11. ETH accumulates on each project contract and can be withdrawn by that project's creator.
12. Buyers receive ERC-20 carbon-credit tokens; the `Company` contract also tracks an internal `carbonCredits` counter for purchases it initiates.
13. The frontend/backend can trigger a Chainlink CRE scoring workflow for a project; CRE calls the scoring API and writes `(measurementDate, scoring, fraudScoring)` back on-chain through `CREScoringOracle`.

## Core contracts

### `RoleManager.sol`

1. `RoleManager` is the central authorization registry for the protocol's operational roles.
2. It stores a single `admin` address and a `mapping(address => bool)` for staff members.
3. The admin can add and remove staff through `addStaff` and `removeStaff`.
4. Other contracts depend on `isStaffOrAdmin` to gate approval, minting, status update, and pricing actions.
5. The contract is upgradeable using OpenZeppelin's `Initializable` and `UUPSUpgradeable` pattern.
6. Its constructor disables initializers, which is the standard safety pattern for implementation contracts used behind proxies.
7. `initialize` replaces constructor initialization and requires non-zero admin and upgrade-controller addresses.
8. Upgrade authority is intentionally separated from operational admin authority through `upgradeController`.
9. `_authorizeUpgrade` only allows the upgrade controller to upgrade the implementation.
10. `setUpgradeController` can only be called by the existing upgrade controller and emits `UpgradeControllerUpdated`.
11. Events are emitted for staff changes, giving off-chain services a simple audit trail.
12. A storage gap is reserved to reduce storage-layout risk in future upgrades.

### `CarbonCreditToken.sol`

1. `CarbonCreditToken` is the ERC-20 token representing carbon credits, initialized with name `CarbonCreditToken` and symbol `CCT`.
2. It uses OpenZeppelin upgradeable modules: `ERC20Upgradeable`, `PausableUpgradeable`, and `UUPSUpgradeable`.
3. Minting is restricted by `onlyApprover`, which delegates authorization to `RoleManager.isStaffOrAdmin`.
4. Minted tokens are minted to `address(this)`, not directly to users or projects.
5. This creates a central inventory pool controlled by the token contract itself.
6. `transferTokens` is restricted to the configured `projectManager`, making `ProjectManager` the only contract that can allocate inventory to projects.
7. Standard `transfer`, `transferFrom`, and `balanceOf` are explicitly overridden to satisfy both ERC-20 and `ICarbonCreditToken` interfaces.
8. `burn` lets any holder burn its own credits, which can be used for retirement/offset behavior.
9. Pause and unpause are controlled by the upgrade controller, not by staff/admin.
10. `whenNotPaused` protects minting and project inventory transfers, but normal ERC-20 transfers are not paused in this implementation.
11. Upgradeability is controlled by `_authorizeUpgrade` and the `onlyUpgradeController` modifier.
12. The design separates token supply creation, project allocation, and marketplace sale logic across different contracts.

### `CompanyManager.sol`

1. `CompanyManager` is the factory and registry for `Company` contracts.
2. Any caller can create a company by providing a name and monthly-emissions value.
3. `createCompany` deploys a new non-upgradeable `Company` contract and records it in `registeredCompanies` and `companyList`.
4. The creator becomes the owner stored inside the new `Company` contract.
5. Approval is not automatic; staff/admin must call `approveCompany` before the company can buy through approval-checked flows.
6. `approveCompany` verifies the address was created by this manager before calling `Company.approve`.
7. `isApproved` also requires registration and then delegates to the target `Company` contract.
8. `getAllCompanies` returns the registry array, supporting marketplace/indexer discovery.
9. Role checks are delegated to `RoleManager`, avoiding duplicated role state.
10. The manager itself is upgradeable with the UUPS pattern and a separate `upgradeController`.
11. Deployed `Company` children are simple contracts and are not upgradeable through this manager.
12. Events record company creation and approval for transparent off-chain tracking.

### `Company.sol`

1. `Company` is a per-company account contract deployed by `CompanyManager`.
2. It stores owner, name, monthly emissions, internally tracked carbon credits, and approval status inside a `CompanyInfo` struct.
3. Only the owner can initiate purchases via `buyFromProject` or `buyFromMarket`.
4. Only the `CompanyManager` that deployed the contract can call `approve`.
5. `buyFromProject` forwards ETH to a specific `Project.buyCarbonCredits` call.
6. `buyFromMarket` forwards ETH to `CarbonCreditMarket.buyFromAny`, passing the company contract address as the buyer.
7. After either purchase path returns successfully, the contract increments its internal `carbonCredits` counter by the requested amount.
8. The actual transferable credit balance is held in the ERC-20 token, while `carbonCredits` is a local accounting field.
9. The contract has a `receive()` function so it can accept ETH refunds from projects or the market.
10. `isApproved` exposes approval status to `CompanyManager`, `Project`, and `CarbonCreditMarket` checks.
11. The contract is intentionally simple and not upgradeable, because each instance is deployed as a lightweight company wallet/account.
12. It uses interface-based calls to `IProject` and `ICarbonCreditMarket`, which reduces compile-time coupling.

### `ProjectManager.sol`

1. `ProjectManager` is the central factory, registry, lifecycle controller, validation receiver, and scoring-history store for carbon projects.
2. It is upgradeable with `Initializable`, `PausableUpgradeable`, and `UUPSUpgradeable`.
3. It stores all project addresses in `projectList` and marks them in `registeredProjects`.
4. `registerProject` enforces unique `cellId` values using both `usedCellIds` and the newer `cellIdRecords` structure.
5. Registration deploys a new `Project` with metadata, supply, creator, price, company-manager reference, and cell id.
6. After deployment it calls `CarbonCreditToken.transferTokens` to move inventory from the token contract into the project contract.
7. `pricePerToken` is manager-level configuration used as the initial price for newly registered projects.
8. `updateProjectStatus` is staff/admin controlled and enforces monotonic lifecycle progression through `Project.updateState`.
9. Staff/admin cannot manually set the `Validated` state; validation must come through the oracle path or the admin mock path.
10. Approval is only allowed after validation, and milestone states are only allowed after approval.
11. When a project becomes approved or later, its cell id is recorded in approved-cell-id mappings and arrays for validation workflows.
12. The validation request flow stores request ids, pending flags, request timestamps, and project mappings.
13. `receiveValidationResult` is restricted to the configured validation oracle adapter.
14. `_applyValidationResult` marks a project validated only when the report has no overlap and is not inconclusive.
15. `mockValidationResult` supports local/testing operation but is disabled whenever a configured validation oracle is present.
16. `setScoringOracleAdapter` configures the CRE scoring adapter that is allowed to write scoring results.
17. `receiveProjectScoring` appends `(measurementDate, scoring, fraudScoring, storedAt)` to `projectScoringHistory` for a registered project.
18. `getProjectScoringHistory`, `getProjectScoringCount`, `getProjectScoringAt`, and `getProjectCellId` support frontend/API discovery and historic scoring reads.
19. Pause protects validation, scoring writes, and state transitions, while upgrade control is delegated to a dedicated upgrade controller.

### `Project.sol`

1. `Project` represents one carbon-credit project and holds that project's allocated CCT inventory and sale proceeds.
2. It is deployed by `ProjectManager`, and its `projectManager` address is fixed to the deployer in the constructor.
3. Project metadata is grouped into `ProjectMeta`, accounts into `ProjectAccounts`, and supply/pricing into `ProjectEconomics`.
4. The project starts in `ProjectState.Registered`.
5. Only the manager can call `updateState`, and each new state must be numerically higher than the current state.
6. Release logic is milestone-based: 0% for `Registered`/`Validated`, 10% for `Approved`, 25%, 50%, 75%, and 100% through `Milestone4`.
7. `getAvailableTokens` returns released tokens minus already purchased tokens.
8. `buyCarbonCredits` sells tokens directly to `msg.sender` after checking ETH amount, release cap, and token balance.
9. `buyFor` sells tokens to a supplied buyer address and is used by `CarbonCreditMarket` for aggregated purchases.
10. `buyFor` checks the supplied buyer is an approved company through `CompanyManager.isApproved`.
11. Both purchase methods update `purchasedTokens`, transfer ERC-20 tokens, and refund excess ETH.
12. ETH paid for credits remains in the project contract until the project creator calls `withdrawETH`.
13. `setPricePerToken` can only be called by `ProjectManager`, but the current manager implementation only sets the default for new projects.
14. The contract emits events for deposits, state changes, token purchases, and ETH withdrawals.
15. It is not upgradeable, making each project an immutable child contract governed by the upgradeable manager.

### `CarbonCreditMarket.sol`

1. `CarbonCreditMarket` is an aggregate purchase router for approved companies.
2. It stores references to `ProjectManager` and `CompanyManager` interfaces.
3. `buyFromAny` takes a target token amount and a payable buyer address.
4. Before buying, it checks `CompanyManager.isApproved(buyer)` so only approved companies can use the market route.
5. The market queries all projects from `ProjectManager.getAllProjects`.
6. It loops through projects in registration order and checks each project's available tokens and price.
7. For every project with availability, it buys the smaller of remaining demand and available supply.
8. The function calls `Project.buyFor{value: cost}(buyer, toBuy)`, so tokens are delivered directly to the company contract.
9. It tracks `totalSpent` and requires `msg.value` to be enough as it progresses through the project list.
10. If all requested tokens cannot be sourced, the whole transaction reverts, preserving atomicity.
11. Any excess ETH is refunded to the buyer address after purchases complete.
12. Events are emitted at start, per project checked, per project purchase, and completion.
13. The contract is upgradeable through UUPS and controlled by an `upgradeController`.
14. The buying algorithm is simple first-available routing; it does not optimize for lowest price.

### `CREValidationOracle.sol`

1. `CREValidationOracle` adapts Chainlink CRE reports to the project's validation interface.
2. It implements `IProjectValidationOracle` and extends `ReceiverTemplate`.
3. The constructor requires a receiver, admin, and Chainlink forwarder address.
4. The receiver is expected to be `ProjectManager`, because the oracle reports results through `receiveValidationResult`.
5. `requestValidation` can only be called by the configured receiver, preventing arbitrary request creation.
6. Each validation request id is derived from chain id, oracle address, project address, cell id hash, and an incrementing nonce.
7. The contract records whether requests exist, whether they are pending, the project address, and the cell id.
8. `isConfigured` returns true when the underlying receiver template has a non-zero forwarder address.
9. Chainlink reports enter through `ReceiverTemplate.onReport`, which then calls `_processReport`.
10. `_processReport` decodes `(bytes32 requestId, bool overlap, bool inconclusive)` from the report payload.
11. It rejects unknown or already completed request ids, then marks the request no longer pending.
12. Finally it calls `IProjectValidationReceiver(receiver).receiveValidationResult` to update `ProjectManager`.
13. The admin can change the receiver with `setReceiver`, allowing migration to a new manager if required.
14. Ownership of the receiver-template controls is transferred to admin in the constructor.

### `CREScoringOracle.sol`

1. `CREScoringOracle` adapts Chainlink CRE reports to the project scoring interface.
2. It extends `ReceiverTemplate`, so reports can only be delivered by the trusted Chainlink forwarder.
3. The constructor requires a receiver, admin, and Chainlink forwarder address.
4. The receiver is expected to be `ProjectManager`, because the oracle stores results through `receiveProjectScoring`.
5. `_processReport` decodes `(address projectAddress, uint256 measurementDate, uint256 scoring, uint256 fraudScoring)` from the report payload.
6. It rejects the zero project address and verifies the project is registered through `ProjectManager.isProjectRegistered`.
7. It emits `ScoringReported` and forwards the result to `IProjectScoringReceiver(receiver).receiveProjectScoring`.
8. The admin can change the receiver with `setReceiver`, allowing migration to a new manager if required.
9. `isConfigured` returns true when the underlying receiver template has a non-zero forwarder address.
10. Ownership of the receiver-template controls is transferred to admin in the constructor.

### `ReceiverTemplate.sol`

1. `ReceiverTemplate` is an abstract Chainlink CRE receiver base contract.
2. It implements `IReceiver`, OpenZeppelin `ERC165`, and `Ownable`.
3. It stores a trusted Chainlink forwarder address that is allowed to call `onReport`.
4. `setForwarderAddress` is owner-only and rejects the zero address.
5. The template optionally stores an expected workflow id and expected author.
6. If these optional expectations are set, incoming report metadata must be present and match them.
7. `onReport` rejects calls from any address other than the configured forwarder.
8. Metadata decoding is implemented with inline assembly for efficient extraction of workflow id and author.
9. After authorization and optional metadata checks, `onReport` delegates report-specific logic to `_processReport`.
10. `_processReport` is abstract, forcing child contracts like `CREValidationOracle` and `CREScoringOracle` to define the report payload format.
11. The contract exposes ERC-165 support for `IReceiver`, making interface discovery possible.
12. Custom errors are used for revert conditions, saving gas compared with long revert strings.

## Interface contracts

### `IReceiver.sol`

1. `IReceiver` defines the minimal Chainlink CRE receiver interface.
2. It extends OpenZeppelin `IERC165` for interface detection.
3. Its single operational function is `onReport(bytes metadata, bytes report)`.
4. The `metadata` parameter carries CRE metadata such as workflow id and author.
5. The `report` parameter carries application-specific encoded data.
6. `ReceiverTemplate` implements this interface and adds authorization checks.
7. `CREValidationOracle` and `CREScoringOracle` indirectly implement this interface through `ReceiverTemplate`.
8. Keeping this interface small makes it easy for Chainlink forwarders to call compatible receivers.
9. It separates generic report transport from domain-specific decoding.
10. The interface is intentionally independent of carbon-credit project types.

### `IRoleManager.sol`

1. `IRoleManager` abstracts the role registry used by other contracts.
2. It exposes the admin address through `admin()`.
3. It exposes staff membership through `isStaff`.
4. It exposes combined authorization through `isStaffOrAdmin`.
5. `ProjectManager`, `CompanyManager`, and `CarbonCreditToken` depend on this interface.
6. The interface lets those contracts use any compatible role-manager implementation.
7. It avoids importing the full concrete `RoleManager` into every contract.
8. It supports the dependency-injection pattern used by upgradeable initializers.
9. The interface contains only read methods, so role mutation remains isolated to the concrete manager.
10. This small surface area reduces coupling and simplifies tests.

### `ICarbonCreditToken.sol`

1. `ICarbonCreditToken` defines the token operations needed by projects and managers.
2. It includes ERC-20-like `transfer`, `transferFrom`, and `balanceOf` functions.
3. It includes `mint` for staff/admin-driven inventory creation.
4. It includes `transferTokens`, the project-allocation function used by `ProjectManager`.
5. It includes `burn` for holder-driven credit retirement.
6. `Project` uses the interface for balance checks and token transfers.
7. `ProjectManager` uses the concrete token for allocation, but the interface captures the intended API.
8. The interface avoids requiring consumers to know all ERC-20 implementation details.
9. It represents the protocol-specific extension of a normal ERC-20 token.
10. Separating the interface supports testing with mocks or future compatible token implementations.

### `ICompanyManager.sol`

1. `ICompanyManager` defines the external API for the company registry.
2. `createCompany` deploys or registers a company-like account.
3. `approveCompany` lets authorized implementations approve registered company contracts.
4. `isApproved` is the key read function used by markets and projects before sales.
5. `getAllCompanies` exposes the registry for discovery and indexing.
6. `Project` relies on this interface to verify buyers in `buyFor`.
7. `CarbonCreditMarket` relies on it before routing any aggregate purchase.
8. `ProjectManager` stores the interface address and passes it into new `Project` contracts.
9. The payable address parameter reflects that company contracts can receive ETH refunds.
10. The interface decouples sale logic from the concrete `CompanyManager` implementation.

### `ICompany.sol`

1. `ICompany` defines the behavior expected from company account contracts.
2. `buyFromProject` is the direct purchase entry point for company owners.
3. `buyFromMarket` is the aggregate purchase entry point for company owners.
4. `approve` is called by `CompanyManager` to mark a company approved.
5. `isApproved` exposes the approval flag.
6. The interface does not expose metadata fields such as name or emissions.
7. It focuses on the operations other protocol components need to call.
8. `CompanyManager` uses the concrete contract for deployment but the interface documents the boundary.
9. The buying functions are payable because they forward ETH to projects or the market.
10. This contract-level account pattern lets companies receive tokens and refunds directly.

### `IProject.sol`

1. `IProject` defines the per-project API and lifecycle enum.
2. `ProjectState` encodes the ordered states: `Registered`, `Validated`, `Approved`, and four milestones.
3. The enum order is used by `Project.updateState` to enforce forward-only transitions.
4. `buyCarbonCredits` supports direct purchases by the message sender.
5. `buyFor` supports delegated purchases, especially from `CarbonCreditMarket`.
6. `getReleasedTokens` exposes the milestone-based release amount.
7. `getAvailableTokens` exposes the currently buyable amount after subtracting purchases.
8. `pricePerToken`, `currentState`, metadata getters, and `cellId` support discovery and validation.
9. `updateState` is included so `ProjectManager` can control lifecycle transitions through the interface.
10. Multiple contracts use this interface instead of importing concrete `Project` logic.

### `IProjectManager.sol`

1. `IProjectManager` defines the public API for project registration, lifecycle, validation, and discovery.
2. `registerProject` creates a new project with metadata, token address, supply, and cell id.
3. `updateProjectStatus` advances lifecycle state under role-controlled implementations.
4. `requestProjectValidation` starts asynchronous validation through a configured oracle adapter.
5. `getValidationStatus` exposes the last validation result for a project.
6. `isProjectRegistered` lets callers confirm that an address belongs to the registry.
7. `setPricePerToken` configures the default price used for newly deployed projects.
8. `setValidationOracleAdapter` and `validationOracleAdapter` manage the external validation integration.
9. `isValidationOracleConfigured` allows UI/test code to know whether real validation is available.
10. `getAllProjects`, `isApprovedCellId`, and `getApprovedCellIds` support market routing and validation workflows.
11. Scoring-specific methods are implemented directly on `ProjectManager` to configure `scoringOracleAdapter`, receive scoring callbacks, expose project cell ids, and read per-project scoring history.

### `IProjectScoringReceiver.sol`

1. `IProjectScoringReceiver` defines the callback endpoint for scoring results.
2. It contains `receiveProjectScoring(address projectAddress, uint256 measurementDate, uint256 scoring, uint256 fraudScoring)`.
3. `ProjectManager` implements this interface.
4. `CREScoringOracle` calls this function after processing a Chainlink report.
5. The project address identifies the on-chain project whose history should receive the score.
6. `measurementDate` is the off-chain measurement timestamp/date returned by the scoring API.
7. `scoring` and `fraudScoring` are stored as unsigned integers; callers should agree on the scale off-chain.
8. The manager adds `storedAt` using the block timestamp when the score is written.
9. Separating the receiver interface keeps scoring result delivery independent of validation request initiation.
10. The callback is restricted in `ProjectManager` to the configured scoring oracle adapter.

### `IProjectValidationOracle.sol`

1. `IProjectValidationOracle` abstracts a validation oracle adapter.
2. `requestValidation` starts validation for a project address and its cell id.
3. The function returns a `bytes32` request id for later correlation.
4. `ProjectManager` depends on this interface rather than the concrete CRE oracle.
5. `isConfigured` lets `ProjectManager` reject requests when the oracle cannot receive reports.
6. The interface supports asynchronous validation because results are returned separately to the receiver.
7. It is small enough to allow alternate oracle implementations in the future.
8. `CREValidationOracle` is the current implementation.
9. The cell id parameter links on-chain projects to off-chain geospatial validation inputs.
10. The interface is part of the adapter pattern between protocol contracts and Chainlink CRE.

### `IProjectValidationReceiver.sol`

1. `IProjectValidationReceiver` defines the callback endpoint for validation results.
2. It contains `receiveValidationResult(bytes32 requestId, bool overlap, bool inconclusive)`.
3. `ProjectManager` implements this interface.
4. `CREValidationOracle` calls this function after processing a Chainlink report.
5. The request id correlates the report with a pending project validation request.
6. The `overlap` flag indicates a conflicting or already-used area was found.
7. The `inconclusive` flag indicates the workflow could not reach a definitive result.
8. A valid project result is inferred when both flags are false.
9. Separating receiver and oracle interfaces keeps request initiation and result delivery independent.
10. This pattern is appropriate for asynchronous oracle systems where the caller cannot receive the result in the same transaction.

## Technical decisions and patterns

1. **UUPS upgradeability:** Manager-like contracts and the token use OpenZeppelin UUPS proxies with initializer functions and storage gaps.
2. **Separate upgrade controller:** Upgrade permission is separated from business admin/staff roles, reducing the blast radius of operational role compromise.
3. **Factory/registry pattern:** `CompanyManager` and `ProjectManager` deploy child contracts and keep arrays/mappings for discovery.
4. **Non-upgradeable children:** `Company` and `Project` are simple immutable child contracts, while governance and orchestration live in upgradeable managers.
5. **Interface-driven dependencies:** Contracts call each other through interfaces to reduce coupling and support replacement/mocking.
6. **Role delegation:** Staff/admin checks are centralized in `RoleManager`, avoiding duplicated role mappings across the system.
7. **Milestone-based vesting/release:** `Project` does not sell all allocated tokens immediately; release caps depend on lifecycle state.
8. **Asynchronous oracle adapters:** `ProjectManager` requests validation through `IProjectValidationOracle`, receives validation results through `IProjectValidationReceiver`, and receives scoring results through `IProjectScoringReceiver`.
9. **Chainlink CRE receiver hardening:** `ReceiverTemplate` restricts report delivery to a trusted forwarder and can pin workflow id/author metadata.
10. **Atomic aggregate buying:** `CarbonCreditMarket.buyFromAny` reverts unless the full requested amount can be filled.
11. **ETH refund pattern:** Purchase functions calculate exact cost and refund overpayment using low-level `call` with success checks.
12. **Event-heavy observability:** Lifecycle changes, purchases, approvals, validation requests, and reports emit events for off-chain indexers.
13. **Cell-id uniqueness:** `ProjectManager` hashes cell ids to prevent duplicate project registrations for the same cell.
14. **Approved cell-id registry:** Approved project cells are recorded for downstream validation and overlap checks.
15. **Forward-only states:** Project state transitions are monotonic, preventing accidental rollback of validation or milestone status.
