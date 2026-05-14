# Architecture and Design Patterns

## Purpose

This document summarizes the design patterns used in NotCarbon to balance upgradeability, safety, and maintainability while keeping gas costs reasonable.

## Upgradeability (UUPS)

Upgradeable core contracts:
- RoleManager
- CompanyManager
- ProjectManager
- CarbonCreditToken
- CarbonCreditMarket

Pattern elements used:
- UUPS proxies with `ERC1967Proxy`
- `Initializable` with `initialize()` replacing constructors
- `_disableInitializers()` in constructors
- `_authorizeUpgrade()` guarded by `upgradeController`
- Storage gaps for future extension

Non-upgradeable contracts:
- Project
- Company

These are deployed per entity with constructors and do not use proxies.

## Governance and Upgrade Controller

Each upgradeable contract stores an `upgradeController` address and uses `onlyUpgradeController` to authorize upgrades and emergency controls. This lets upgrades be routed through a timelock or multisig without tying upgrades to the admin or staff roles.

## Circuit Breakers (Pausable)

Critical state-changing logic is pausable:
- ProjectManager: validation and state transitions
- CarbonCreditToken: minting and project token transfers

Pause and unpause are restricted to the `upgradeController`.

## Data Optimization

- Cell IDs are tracked by hash (`keccak256(bytes(cellId))`) for efficient lookups.
- Strings are retained only when needed for display or external indexing.

## Struct Grouping

Related state is grouped into structs to improve clarity and reduce storage fragmentation:
- Project: metadata, accounts, economics
- Company: company info
- ProjectManager: validation status, request tracking, cell ID tracking

## Non-Upgradeable Instances

Project and Company are intentionally not upgradeable:
- Each instance is isolated and immutable once deployed
- Upgrades are handled at the manager level
- This keeps per-entity contracts minimal and reduces proxy overhead

## Deployment Notes

- Core contracts must be deployed behind `ERC1967Proxy` and initialized.
- Initialize in dependency order to wire addresses correctly.
- Project and Company are deployed directly by their managers.

## Tradeoffs

- UUPS reduces proxy overhead but requires strict upgrade authorization.
- Pausable adds safety at the cost of additional checks.
- Hash-based keys reduce gas but require mapping from string to hash.
- Struct grouping improves readability but requires explicit getters for ABI stability.
