# CompanyManager

## Summary

`CompanyManager` is the factory and registry for company account contracts. Any user can create a `Company`, but only staff/admin can approve it. Approved companies are allowed to buy carbon credits through approval-checked flows in `Project` and `CarbonCreditMarket`. The manager stores all deployed company addresses and provides discovery and approval checks for other contracts.

## Interface

- `initialize(address _roleManagerAddress, address _upgradeController)`: initializes the role manager and upgrade controller.
- `setUpgradeController(address _upgradeController)`: updates upgrade authority; callable only by the current upgrade controller.
- `createCompany(string _name, uint256 _monthlyEmissions)`: deploys a new `Company` owned by `msg.sender`, registers it, and returns its address.
- `approveCompany(address payable _companyAddress)`: approves a registered company; callable only by staff/admin.
- `isApproved(address payable _companyAddress)`: verifies registration and returns the company's approval status.
- `getAllCompanies()`: returns the array of all registered company contract addresses.
- `registeredCompanies(address)`: public mapping getter for registry membership.
- `companyList(uint256)`: public array getter for company addresses.

## Implementation details

`CompanyManager` is UUPS-upgradeable and disables implementation initializers in the constructor. It depends on `RoleManager` through the `IRoleManager` interface and uses `roleManager.isStaffOrAdmin` for approval authorization. `createCompany` uses the factory pattern by deploying a fresh non-upgradeable `Company` contract with constructor parameters: owner, name, monthly emissions, and this manager address. The manager records the new child address in both a mapping and an array, allowing O(1) membership checks and full-list enumeration. Approval is delegated to the child contract's `approve` function, but only after verifying that the address was produced/registered by this manager. Upgrades are authorized solely by `upgradeController`, and a storage gap is reserved.