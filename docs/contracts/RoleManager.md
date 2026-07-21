# RoleManager

## Summary

`RoleManager` is the protocol-wide role registry. It stores the primary `admin`, tracks staff addresses, and exposes read-only role checks used by the rest of the system. Other contracts use it to decide who can approve companies, mint carbon-credit tokens, update project states, and configure protocol parameters. The contract is UUPS-upgradeable and separates operational authority from upgrade authority by using an `upgradeController`.

## Interface

- `initialize(address _admin, address _upgradeController)`: initializes the admin and upgrade controller for the proxy instance.
- `setUpgradeController(address _upgradeController)`: changes the upgrade controller; callable only by the current upgrade controller.
- `addStaff(address _staff)`: adds a staff member; callable only by `admin`.
- `removeStaff(address _staff)`: removes a staff member; callable only by `admin`.
- `isStaff(address _user)`: returns whether an address is staff.
- `isStaffOrAdmin(address _user)`: returns whether an address is either the admin or staff.
- `admin()`: public state getter for the admin address.
- `upgradeController()`: public state getter for the upgrade controller.
- `staff(address)`: public mapping getter for staff membership.

## Implementation details

`RoleManager` inherits `Initializable` and `UUPSUpgradeable`, disables implementation initializers in the constructor, and stores a `uint256[50]` storage gap for future upgrade-safe additions. It uses dedicated modifiers for `onlyAdmin`, `onlyStaffOrAdmin`, and `onlyUpgradeController`, although only `onlyAdmin` and `onlyUpgradeController` are currently used internally. Upgrade authorization is implemented by overriding `_authorizeUpgrade` and applying `onlyUpgradeController`. Staff changes emit `StaffAdded` and `StaffRemoved`; upgrade-controller changes emit `UpgradeControllerUpdated`. The contract intentionally keeps role mutation small and centralized while exposing role-read methods to dependent contracts.