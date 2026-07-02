# Company

## Summary

`Company` is a per-company account contract deployed by `CompanyManager`. It stores company metadata, the owner address, approval status, and an internal count of purchased carbon credits. The company owner can buy credits either directly from a project or through the aggregate market. The contract can receive ETH refunds from project or market purchases.

## Interface

- `constructor(address _owner, string _name, uint256 _monthlyEmissions, address _companyManager)`: creates the company account and records its manager.
- `owner()`: returns the company owner's address.
- `companyManager()`: returns the manager that deployed and controls approval for the company.
- `name()`: returns the company name.
- `monthlyEmissions()`: returns the declared monthly emissions value.
- `carbonCredits()`: returns the internal purchased-credit counter.
- `approved()`: returns the stored approval flag.
- `buyFromProject(address payable projectAddress, uint256 amount)`: owner-only direct purchase from a specific project.
- `buyFromMarket(address market, uint256 amount)`: owner-only purchase through `CarbonCreditMarket`.
- `approve()`: marks the company approved; callable only by `CompanyManager`.
- `isApproved()`: returns whether the company is approved.
- `receive() external payable`: allows the company to receive ETH refunds.

## Implementation details

The contract is deliberately simple and non-upgradeable. Its state is grouped into a private `CompanyInfo` struct, while the deploying manager address is stored separately. The `onlyOwner` modifier protects purchase functions so only the company owner can spend ETH through the company account. The `onlyCompanyManager` modifier protects `approve`, ensuring users cannot self-approve. Purchase functions use interfaces: direct purchases call `IProject.buyCarbonCredits`, and market purchases call `ICarbonCreditMarket.buyFromAny` with the company contract as the buyer. After successful calls, `carbonCredits` is incremented by the requested amount; actual transferable ownership is still represented by the ERC-20 token balance. The `receive` function is important because purchase paths can refund excess ETH to the company contract.