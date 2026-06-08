# Agent Instructions

## Project Context
- Foundry Solidity project for a carbon-credit lifecycle platform: roles, company onboarding, project registration/validation, token issuance, and market purchases.
- Core upgradeable UUPS contracts: `RoleManager`, `CompanyManager`, `ProjectManager`, `CarbonCreditToken`, `CarbonCreditMarket`.
- Per-entity contracts `Project` and `Company` are intentionally non-upgradeable and deployed directly by managers.
- Chainlink CRE validation lives in `src/oracles/CREValidationOracle.sol` and `cre/validation-workflow/`.

## Development Rules
- Keep existing pragma/style per file and run `forge fmt` after Solidity changes.
- For upgradeable contracts keep UUPS patterns: `Initializable`, `UUPSUpgradeable`, `initialize()`, `_disableInitializers()`, `_authorizeUpgrade()` guarded by `upgradeController`, and storage gaps.
- Preserve storage layout: only append state; never reorder, rename, or remove existing storage in upgradeable contracts.
- Gate admin/staff actions through `RoleManager`; gate upgrades and emergency pause/unpause through `upgradeController`.
- Use and update interfaces in `src/interfaces/` whenever cross-contract public APIs change.
- Preserve the project validation flow: registered → oracle/mock validation → approved → milestones. Cell IDs are keyed with `keccak256(bytes(cellId))` and must remain unique.
- Do not edit vendored dependencies in `lib/` unless explicitly requested.

## Current Contract Areas to Continue
- When adding business logic, update deployment/setup/smoke scripts and docs if required.

## Testing and Commands
- Add or update tests in `test/` for every behavior change; reuse helpers in `test/Base.t.sol`.
- Before finishing, run: `forge fmt`, `forge build`, and `forge test`.
- Deployment order must remain: `RoleManager` → `CompanyManager` → `ProjectManager` → `CarbonCreditToken` → `CarbonCreditMarket`, all behind `ERC1967Proxy` and initialized.
- Never hardcode secrets or private keys; use environment variables documented in `docs/scripts.md` and `docs/testing.md`.
