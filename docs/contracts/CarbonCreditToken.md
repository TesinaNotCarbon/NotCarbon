# CarbonCreditToken

## Summary

`CarbonCreditToken` is the ERC-20 token used to represent carbon credits. It mints tokens into its own contract balance, then allows only the configured `ProjectManager` to allocate those tokens to project contracts. Minting is controlled by staff/admin roles through `RoleManager`, while pause and upgrade authority are controlled by a separate upgrade controller. Holders can transfer tokens normally and can burn their own credits.

## Interface

- `initialize(address _projectManager, address _roleManager, address _admin, address _upgradeController)`: initializes the ERC-20 token, manager references, admin, and upgrade controller.
- `setUpgradeController(address _upgradeController)`: updates upgrade authority; callable only by the current upgrade controller.
- `mint(uint256 amount)`: mints new CCT into `address(this)`; callable only by staff/admin and only when not paused.
- `transferTokens(address recipient, uint256 amount)`: transfers inventory from the token contract to a recipient; callable only by `projectManager` and only when not paused.
- `burn(uint256 amount)`: burns tokens from `msg.sender`.
- `pause()`: pauses minting and project allocation; callable only by upgrade controller.
- `unpause()`: unpauses minting and project allocation; callable only by upgrade controller.
- Standard ERC-20 methods such as `transfer`, `transferFrom`, and `balanceOf` are exposed through inherited and overridden functions.

## Implementation details

The contract inherits `ERC20Upgradeable`, `PausableUpgradeable`, `UUPSUpgradeable`, and the token interface. It initializes the token as `CarbonCreditToken` with symbol `CCT`. The design uses a central inventory-pool pattern: tokens are minted to the token contract itself, not directly to projects or users. This lets `ProjectManager` become the only distribution channel through `transferTokens`. `onlyApprover` delegates authorization to `RoleManager.isStaffOrAdmin`, while `onlyProjectManager` protects project allocation. Normal ERC-20 transfers are not guarded by `whenNotPaused`; only `mint` and `transferTokens` are paused. `_authorizeUpgrade` restricts upgrades to `upgradeController`, and a storage gap is reserved for future versions.