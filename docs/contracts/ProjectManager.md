# ProjectManager

## Summary

`ProjectManager` is the project factory, registry, lifecycle controller, validation receiver, and scoring-history store. It deploys `Project` contracts, transfers token inventory to them, enforces unique cell ids, controls project state transitions, integrates with external validation and scoring oracle adapters, and stores historical project scores received from Chainlink CRE. It is the central coordinator between roles, companies, projects, the token contract, and Chainlink CRE validation/scoring.

## Interface

- `initialize(address _roleManager, address _companyManager, address _admin, address _upgradeController)`: initializes dependencies and authorities.
- `setUpgradeController(address _upgradeController)`: updates upgrade authority.
- `setValidationOracleAdapter(address _adapter)`: admin-only configuration for the validation oracle adapter.
- `setScoringOracleAdapter(address _adapter)`: admin-only configuration for the scoring oracle adapter.
- `registerProject(string _name, string _description, address _carbonCreditTokenAddress, uint256 _totalTokens, string _cellId)`: deploys and registers a new project, then allocates tokens to it.
- `updateProjectStatus(address _projectAddress, IProject.ProjectState _newState)`: staff/admin lifecycle update, excluding direct transition to `Validated`.
- `isProjectRegistered(address _projectAddress)`: returns registry status.
- `setPricePerToken(uint256 _price)`: staff/admin setter for the default price used by newly created projects.
- `isValidationOracleConfigured()`: returns whether the validation oracle adapter is present and configured.
- `requestProjectValidation(address _projectAddress)`: starts oracle validation for a registered project.
- `receiveValidationResult(bytes32 _requestId, bool _overlap, bool _inconclusive)`: validation-oracle-adapter-only callback for validation results.
- `mockValidationResult(address _projectAddress, bool _overlap, bool _inconclusive)`: admin-only local/test validation path when no validation oracle is configured.
- `getAllProjects()`: returns all registered projects.
- `getValidationStatus(address _projectAddress)`: returns the latest validation status tuple.
- `receiveProjectScoring(address _projectAddress, uint256 _measurementDate, uint256 _scoring, uint256 _fraudScoring)`: scoring-oracle-adapter-only callback that appends a scoring record to the project's history.
- `getProjectScoringHistory(address _projectAddress)`: returns all stored scoring records for a project.
- `getProjectScoringCount(address _projectAddress)`: returns the number of stored scoring records for a project.
- `getProjectScoringAt(address _projectAddress, uint256 _index)`: returns one historical scoring record.
- `getProjectCellId(address _projectAddress)`: returns the registered project's cell id, useful for off-chain scoring API requests.
- `isApprovedCellId(string _cellId)`: returns whether a cell id has been approved.
- `getApprovedCellIds()`: returns approved cell ids.
- `pause()` / `unpause()`: upgrade-controller-only pause controls.

## Implementation details

`ProjectManager` uses UUPS upgradeability and pausable guards. It stores projects in both `registeredProjects` and `projectList`, and stores cell ids as `keccak256(bytes(cellId))` to enforce uniqueness. `registerProject` deploys a non-upgradeable `Project`, records the cell id as used, and calls `CarbonCreditToken.transferTokens` to move the project's supply into the new project contract. Lifecycle progression is delegated to each project, but the manager enforces business rules: validation must come from the oracle/mock path, approval requires validation, and milestones require prior approval.

Validation is asynchronous: the manager calls `IProjectValidationOracle.requestValidation`, records request metadata, and later receives the result through `receiveValidationResult`. A project becomes `Validated` only when the oracle reports no overlap and not inconclusive. Approved cell ids are recorded once and exposed for downstream validation workflows.

Scoring is also asynchronous, but it is initiated off-chain through the Chainlink CRE HTTP trigger rather than by a manager request function. The frontend or backend triggers the CRE scoring workflow with the project identifier, CRE calls the scoring API, and `CREScoringOracle` forwards the ABI-decoded result to `receiveProjectScoring`. Only the configured `scoringOracleAdapter` can write scores, and every score is appended to `projectScoringHistory` with `measurementDate`, `scoring`, `fraudScoring`, and `storedAt`. Pause protects validation, scoring writes, and state-update flows, while upgrade authority is isolated in `upgradeController`.
