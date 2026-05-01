// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Project} from "./Project.sol";
import {CarbonCreditToken} from "./CarbonCreditToken.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";
import {ICompanyManager} from "./interfaces/ICompanyManager.sol";
import {IProjectManager} from "./interfaces/IProjectManager.sol";
import {IProject} from "./interfaces/IProject.sol";
import {ChainlinkClient} from "chainlink-brownie-contracts/contracts/src/v0.8/ChainlinkClient.sol";
import {Chainlink} from "chainlink-brownie-contracts/contracts/src/v0.8/Chainlink.sol";
import {
    LinkTokenInterface
} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract ProjectManager is IProjectManager, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    address public admin;
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

    mapping(address => ValidationStatus) private validationStatus;
    mapping(bytes32 => address) public validationRequests;
    mapping(address => bool) public validationPending;
    mapping(address => bytes32) public lastValidationRequestId;

    address public validationOracle;
    bytes32 public validationJobId;
    uint256 public validationFee;

    event ProjectRegistered(address indexed projectAddress, string name, string description, address creator);
    event ProjectStateUpdated(address indexed projectAddress, IProject.ProjectState newState);
    event ApprovedCellIdRecorded(address indexed projectAddress, string cellId);
    event ProjectValidationRequested(address indexed projectAddress, bytes32 requestId, string cellId);
    event ProjectValidationCompleted(
        address indexed projectAddress, bytes32 requestId, bool validated, bool overlap, bool inconclusive
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can execute this function.");
        _;
    }

    modifier onlyApprover() {
        require(roleManager.isStaffOrAdmin(msg.sender), "Only staff or admin can execute this function.");
        _;
    }

    constructor(address _roleManager, address _companyManager) {
        admin = msg.sender;
        roleManager = IRoleManager(_roleManager);
        companyManager = ICompanyManager(_companyManager);
    }

    function registerProject(
        string memory _name,
        string memory _description,
        address _carbonCreditTokenAddress,
        uint256 _totalTokens,
        string memory _cellId
    ) public override returns (address) {
        bytes32 cellIdHash = keccak256(bytes(_cellId));
        require(!usedCellIds[cellIdHash], "Cell ID already used.");

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

        if (_newState >= IProject.ProjectState.Approved && !projectApprovalRecorded[_projectAddress]) {
            string memory projectCellId = project.cellId();
            bytes32 cellIdHash = keccak256(bytes(projectCellId));
            approvedCellIds[cellIdHash] = true;
            projectApprovalRecorded[_projectAddress] = true;
            approvedCellIdList.push(projectCellId);
            emit ApprovedCellIdRecorded(_projectAddress, projectCellId);
        }

        emit ProjectStateUpdated(_projectAddress, _newState);
    }

    function isProjectRegistered(address _projectAddress) public view override returns (bool) {
        return registeredProjects[_projectAddress];
    }

    function setPricePerToken(uint256 _price) public override onlyApprover {
        pricePerToken = _price;
    }

    function setChainlinkConfig(address _linkToken, address _oracle, bytes32 _jobId, uint256 _fee)
        public
        override
        onlyAdmin
    {
        require(_linkToken != address(0), "Invalid LINK token.");
        require(_oracle != address(0), "Invalid oracle.");
        require(_jobId != bytes32(0), "Invalid job id.");
        _setChainlinkToken(_linkToken);
        _setChainlinkOracle(_oracle);
        validationOracle = _oracle;
        validationJobId = _jobId;
        validationFee = _fee;
    }

    function requestProjectValidation(address _projectAddress) public override returns (bytes32) {
        require(registeredProjects[_projectAddress], "Project is not registered.");
        IProject project = IProject(_projectAddress);
        require(project.currentState() == IProject.ProjectState.Registered, "Project must be registered.");
        require(!validationPending[_projectAddress], "Validation already pending.");
        require(validationOracle != address(0), "Chainlink config not set.");

        Chainlink.Request memory req = _buildOperatorRequest(validationJobId, this.fulfillValidation.selector);
        req.add("cell_id", project.cellId());

        bytes32 requestId = _sendOperatorRequest(req, validationFee);
        validationRequests[requestId] = _projectAddress;
        lastValidationRequestId[_projectAddress] = requestId;
        validationPending[_projectAddress] = true;

        emit ProjectValidationRequested(_projectAddress, requestId, project.cellId());
        return requestId;
    }

    function fulfillValidation(bytes32 _requestId, bool _overlap, bool _inconclusive)
        public
        recordChainlinkFulfillment(_requestId)
    {
        address projectAddress = validationRequests[_requestId];
        require(projectAddress != address(0), "Unknown request id.");
        _applyValidationResult(projectAddress, _requestId, _overlap, _inconclusive);
    }

    function mockValidationResult(address _projectAddress, bool _overlap, bool _inconclusive) public onlyAdmin {
        require(validationOracle == address(0), "Mock disabled when oracle set.");
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
        return approvedCellIds[keccak256(bytes(_cellId))];
    }

    function getApprovedCellIds() public view override returns (string[] memory) {
        return approvedCellIdList;
    }

    function withdrawLink(address _to, uint256 _amount) public onlyAdmin {
        require(_to != address(0), "Invalid recipient.");
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(link.transfer(_to, _amount), "LINK transfer failed.");
    }

    function _applyValidationResult(address _projectAddress, bytes32 _requestId, bool _overlap, bool _inconclusive)
        internal
    {
        bool isValidated = !_overlap && !_inconclusive;
        validationStatus[_projectAddress] = ValidationStatus({
            validated: isValidated, overlap: _overlap, inconclusive: _inconclusive, updatedAt: block.timestamp
        });
        validationPending[_projectAddress] = false;

        if (isValidated) {
            IProject project = IProject(_projectAddress);
            if (project.currentState() == IProject.ProjectState.Registered) {
                project.updateState(IProject.ProjectState.Validated);
            }
        }

        emit ProjectValidationCompleted(_projectAddress, _requestId, isValidated, _overlap, _inconclusive);
    }
}
