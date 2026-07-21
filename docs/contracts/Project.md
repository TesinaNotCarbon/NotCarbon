# Project

## Summary

`Project` represents one carbon-credit project. It stores project metadata, creator, token address, assigned supply, sale price, purchased amount, and lifecycle state. It holds the ERC-20 token inventory allocated by `ProjectManager` and sells only the portion released by the current project milestone. ETH paid by buyers stays in the project contract until withdrawn by the project creator.

## Interface

- `constructor(...)`: initializes metadata, creator, token address, company manager, cell id, supply, and price.
- Metadata/account getters: `projectManager()`, `creator()`, `carbonCreditTokenAddress()`, `companyManager()`, `token()`, `projectName()`, `projectDescription()`, `cellId()`, `getCreator()`.
- Economics getters: `totalTokens()`, `purchasedTokens()`, `pricePerToken()`, `getReleasedTokens()`, `getAvailableTokens()`, `getBalance()`.
- State getter: `currentState()`.
- `setPricePerToken(uint256 _price)`: manager-only price update.
- `updateState(IProject.ProjectState _newState)`: manager-only forward state transition.
- `deposit()`: accepts ETH and emits a deposit event.
- `buyCarbonCredits(uint256 _amount)`: direct payable purchase by `msg.sender`.
- `buyFor(address buyer, uint256 amount)`: delegated payable purchase for an approved company, used by the market.
- `withdrawETH(uint256 _amount)`: creator-only withdrawal of accumulated ETH.

## Implementation details

The contract is a non-upgradeable child deployed by `ProjectManager`. It groups data into `ProjectMeta`, `ProjectAccounts`, and `ProjectEconomics` structs to keep the storage model readable. State transitions are monotonic: `updateState` requires the new enum value to be greater than the current value. Token release is milestone-based: `Registered` and `Validated` release 0%, `Approved` releases 10%, then milestones release 25%, 50%, 75%, and finally 100%. `getAvailableTokens` subtracts `purchasedTokens` from the released amount. Both purchase functions check payment, release availability, and token balance before transferring ERC-20 credits. `buyCarbonCredits` sends tokens to `msg.sender`, while `buyFor` sends tokens to a specified buyer and verifies that buyer is an approved company. Excess ETH is refunded with a low-level `call`. Sale proceeds remain in the project and can only be withdrawn by the creator.