// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Project} from "./Project.sol";
import {CarbonCreditToken} from "./CarbonCreditToken.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";
import {ICompanyManager} from "./interfaces/ICompanyManager.sol";
import {IProjectManager} from "./interfaces/IProjectManager.sol";
import {IProject} from "./interfaces/IProject.sol";

contract ProjectManager is IProjectManager {
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

    event ProjectRegistered(address indexed projectAddress, string name, string description, address creator);
    event ProjectStateUpdated(address indexed projectAddress, IProject.ProjectState newState);
    event ApprovedCellIdRecorded(address indexed projectAddress, string cellId);

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
        project.updateState(_newState);

        if (_newState >= IProject.ProjectState.Phase1 && !projectApprovalRecorded[_projectAddress]) {
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

    function getAllProjects() public view override returns (address[] memory) {
        return projectList;
    }

    function isApprovedCellId(string memory _cellId) public view override returns (bool) {
        return approvedCellIds[keccak256(bytes(_cellId))];
    }

    function getApprovedCellIds() public view override returns (string[] memory) {
        return approvedCellIdList;
    }
}
