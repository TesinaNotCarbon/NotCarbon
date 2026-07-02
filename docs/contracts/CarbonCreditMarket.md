# CarbonCreditMarket

## Summary

`CarbonCreditMarket` is an aggregate buying router for carbon credits. Instead of forcing a company to choose a specific project, it scans all registered projects and buys from any projects with available released inventory until the requested amount is filled. The buyer must be an approved company. The route is atomic: if the requested amount cannot be fully bought, the transaction reverts.

## Interface

- `initialize(address _projectManager, address _companyManager, address _upgradeController)`: initializes manager references and upgrade authority.
- `setUpgradeController(address _upgradeController)`: changes upgrade authority; callable only by current upgrade controller.
- `buyFromAny(uint256 totalAmount, address payable buyer)`: payable aggregate purchase function that buys `totalAmount` credits for `buyer`.
- `projectManager()`: public getter for the project manager interface.
- `companyManager()`: public getter for the company manager interface.
- `upgradeController()`: public getter for upgrade authority.

## Implementation details

The market is UUPS-upgradeable and uses an `upgradeController` for `_authorizeUpgrade`. `buyFromAny` begins by checking `companyManager.isApproved(buyer)`. It then retrieves all projects from `ProjectManager` and loops through them in registration order. For each project, it reads `getAvailableTokens()` and `pricePerToken()`, then buys the smaller of the remaining requested amount and the project's available amount. Purchases are performed through `Project.buyFor{value: cost}(buyer, toBuy)`, so ERC-20 tokens are delivered directly to the company contract. The function tracks `totalSpent`, verifies `msg.value` is sufficient as it progresses, and refunds unused ETH to the buyer after completion. If inventory is insufficient across all projects, `remaining` stays non-zero and the entire transaction reverts. The router is simple first-available routing and does not optimize by price.