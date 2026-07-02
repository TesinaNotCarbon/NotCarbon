// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Project} from "./Project.sol";
import {CarbonCreditToken} from "./CarbonCreditToken.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";
import {ICompanyManager} from "./interfaces/ICompanyManager.sol";
import {IProjectManager} from "./interfaces/IProjectManager.sol";
import {IProject} from "./interfaces/IProject.sol";
import {IProjectValidationOracle} from "./interfaces/IProjectValidationOracle.sol";
import {IProjectValidationReceiver} from "./interfaces/IProjectValidationReceiver.sol";

contract ProjectManager is
    Initializable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IProjectManager,
    IProjectValidationReceiver
{
    address public admin;
    address public upgradeController;
    mapping(address => bool) public registeredProjects;
    mapping(bytes32 => bool) public usedCellIds;
    mapping(bytes32 => bool) public approvedCellIds;
    mapping(address => bool) public projectApprovalRecorded;
    address[] public projectList;
    string[] public approvedCellIdList;
    uint256 pricePerToken;
    IRoleManager public roleManager;
    ICompanyManager public companyManager;

    struct ValidationStatus {
        bool validated;
        bool overlap;
        bool inconclusive;
        uint256 updatedAt;
    }

    struct ValidationRequestInfo {
        bytes32 requestId;
        bool pending;
        uint256 requestedAt;
    }

    struct CellIdRecord {
        bool used;
        bool approved;
        bool projectApprovalRecorded;
    }

    mapping(address => ValidationStatus) private validationStatus;
    mapping(bytes32 => address) public validationRequests;
    mapping(address => bool) public validationPending;
    mapping(address => bytes32) public lastValidationRequestId;
    mapping(address => ValidationRequestInfo) private validationByProject;
    mapping(bytes32 => CellIdRecord) private cellIdRecords;

    address public validationOracleAdapter;

    event ProjectRegistered(address indexed projectAddress, string name, string description, address creator);
    event ProjectStateUpdated(address indexed projectAddress, IProject.ProjectState newState);
    event ApprovedCellIdRecorded(address indexed projectAddress, string cellId);
    event ProjectValidationRequested(address indexed projectAddress, bytes32 requestId, string cellId);
    event ProjectValidationCompleted(
        address indexed projectAddress, bytes32 requestId, bool validated, bool overlap, bool inconclusive
    );
    event ValidationOracleAdapterUpdated(address indexed adapter);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can execute this function.");
        _;
    }

    modifier onlyApprover() {
        require(roleManager.isStaffOrAdmin(msg.sender), "Only staff or admin can execute this function.");
        _;
    }

    modifier onlyUpgradeController() {
        require(msg.sender == upgradeController, "Only upgrade controller.");
        _;
    }

    modifier onlyValidationOracleAdapter() {
        require(msg.sender == validationOracleAdapter, "Only validation oracle adapter.");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _roleManager, address _companyManager, address _admin, address _upgradeController)
        public
        initializer
    {
        require(_roleManager != address(0), "Invalid role manager.");
        require(_companyManager != address(0), "Invalid company manager.");
        require(_admin != address(0), "Invalid admin.");
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        __Pausable_init();
        admin = _admin;
        roleManager = IRoleManager(_roleManager);
        companyManager = ICompanyManager(_companyManager);
        upgradeController = _upgradeController;
    }

    function setUpgradeController(address _upgradeController) external onlyUpgradeController {
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        upgradeController = _upgradeController;
    }

    function setValidationOracleAdapter(address _adapter) external override onlyAdmin {
        require(_adapter != address(0), "Invalid validation oracle adapter.");
        validationOracleAdapter = _adapter;
        emit ValidationOracleAdapterUpdated(_adapter);
    }

    function registerProject(
        string memory _name,
        string memory _description,
        address _carbonCreditTokenAddress,
        uint256 _totalTokens,
        string memory _cellId
    ) public override returns (address) {
        bytes32 cellIdHash = keccak256(bytes(_cellId));
        require(!usedCellIds[cellIdHash] && !cellIdRecords[cellIdHash].used, "Cell ID already used.");

        // Create the project contract, with ProjectState.Registered
        Project newProject = new Project(
            _name,
            _description,
            _carbonCreditTokenAddress,
            _totalTokens,
            msg.sender,
            pricePerToken,
            companyManager,
            _cellId
        );

        address projectAddress = address(newProject);
        registeredProjects[projectAddress] = true;
        usedCellIds[cellIdHash] = true;
        cellIdRecords[cellIdHash].used = true;
        projectList.push(projectAddress);

        // Transfer the tokens from the CarbonCreditToken contract to the new project contract
        CarbonCreditToken token = CarbonCreditToken(_carbonCreditTokenAddress);
        token.transferTokens(projectAddress, _totalTokens);

        emit ProjectRegistered(projectAddress, _name, _description, msg.sender);
        return projectAddress;
    }

    function updateProjectStatus(address _projectAddress, IProject.ProjectState _newState)
        public
        override
        onlyApprover
        whenNotPaused
    {
        require(registeredProjects[_projectAddress], "Project is not registered.");
        IProject project = IProject(_projectAddress);

        if (_newState == IProject.ProjectState.Validated) {
            revert("Validation must come from the oracle.");
        }
        if (_newState == IProject.ProjectState.Approved) {
            require(project.currentState() == IProject.ProjectState.Validated, "Project must be validated first.");
        }
        if (_newState > IProject.ProjectState.Approved) {
            require(project.currentState() >= IProject.ProjectState.Approved, "Project must be approved first.");
        }

        project.updateState(_newState);

        if (_newState >= IProject.ProjectState.Approved) {
            string memory projectCellId = project.cellId();
            bytes32 cellIdHash = keccak256(bytes(projectCellId));
            bool alreadyRecorded =
                projectApprovalRecorded[_projectAddress] || cellIdRecords[cellIdHash].projectApprovalRecorded;
            if (!alreadyRecorded) {
                approvedCellIds[cellIdHash] = true;
                projectApprovalRecorded[_projectAddress] = true;
                cellIdRecords[cellIdHash].approved = true;
                cellIdRecords[cellIdHash].projectApprovalRecorded = true;
                approvedCellIdList.push(projectCellId);
                emit ApprovedCellIdRecorded(_projectAddress, projectCellId);
            }
        }

        emit ProjectStateUpdated(_projectAddress, _newState);
    }

    function isProjectRegistered(address _projectAddress) public view override returns (bool) {
        return registeredProjects[_projectAddress];
    }

    function setPricePerToken(uint256 _price) public override onlyApprover {
        pricePerToken = _price;
    }

    function isValidationOracleConfigured() public view override returns (bool) {
        if (validationOracleAdapter == address(0)) {
            return false;
        }
        return IProjectValidationOracle(validationOracleAdapter).isConfigured();
    }

    function requestProjectValidation(address _projectAddress) public override whenNotPaused returns (bytes32) {
        require(registeredProjects[_projectAddress], "Project is not registered.");
        IProject project = IProject(_projectAddress);
        require(project.currentState() == IProject.ProjectState.Registered, "Project must be registered.");
        ValidationRequestInfo storage requestInfo = validationByProject[_projectAddress];
        require(!validationPending[_projectAddress] && !requestInfo.pending, "Validation already pending.");
        require(validationOracleAdapter != address(0), "Validation oracle not set.");
        require(IProjectValidationOracle(validationOracleAdapter).isConfigured(), "Validation oracle not configured.");

        bytes32 requestId =
            IProjectValidationOracle(validationOracleAdapter).requestValidation(_projectAddress, project.cellId());
        validationRequests[requestId] = _projectAddress;
        lastValidationRequestId[_projectAddress] = requestId;
        validationPending[_projectAddress] = true;
        requestInfo.requestId = requestId;
        requestInfo.pending = true;
        requestInfo.requestedAt = block.timestamp;

        emit ProjectValidationRequested(_projectAddress, requestId, project.cellId());
        return requestId;
    }

    function receiveValidationResult(bytes32 _requestId, bool _overlap, bool _inconclusive)
        external
        override
        onlyValidationOracleAdapter
        whenNotPaused
    {
        address projectAddress = validationRequests[_requestId];
        require(projectAddress != address(0), "Unknown request id.");
        _applyValidationResult(projectAddress, _requestId, _overlap, _inconclusive);
    }

    function mockValidationResult(address _projectAddress, bool _overlap, bool _inconclusive)
        public
        onlyAdmin
        whenNotPaused
    {
        require(!isValidationOracleConfigured(), "Mock disabled when oracle set.");
        require(registeredProjects[_projectAddress], "Project is not registered.");
        _applyValidationResult(_projectAddress, bytes32(0), _overlap, _inconclusive);
    }

    function getAllProjects() public view override returns (address[] memory) {
        return projectList;
    }

    function getValidationStatus(address _projectAddress)
        public
        view
        override
        returns (bool validated, bool overlap, bool inconclusive, uint256 updatedAt)
    {
        ValidationStatus memory status = validationStatus[_projectAddress];
        return (status.validated, status.overlap, status.inconclusive, status.updatedAt);
    }

    function isApprovedCellId(string memory _cellId) public view override returns (bool) {
        bytes32 cellIdHash = keccak256(bytes(_cellId));
        return approvedCellIds[cellIdHash] || cellIdRecords[cellIdHash].approved;
    }

    function getApprovedCellIds() public view override returns (string[] memory) {
        return approvedCellIdList;
    }

    function _applyValidationResult(address _projectAddress, bytes32 _requestId, bool _overlap, bool _inconclusive)
        internal
    {
        bool isValidated = !_overlap && !_inconclusive;
        validationStatus[_projectAddress] = ValidationStatus({
            validated: isValidated, overlap: _overlap, inconclusive: _inconclusive, updatedAt: block.timestamp
        });
        validationPending[_projectAddress] = false;
        validationByProject[_projectAddress].pending = false;

        if (isValidated) {
            IProject project = IProject(_projectAddress);
            if (project.currentState() == IProject.ProjectState.Registered) {
                project.updateState(IProject.ProjectState.Validated);
            }
        }

        emit ProjectValidationCompleted(_projectAddress, _requestId, isValidated, _overlap, _inconclusive);
    }

    function pause() external onlyUpgradeController {
        _pause();
    }

    function unpause() external onlyUpgradeController {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgradeController {}

    uint256[52] private __gap;
}
