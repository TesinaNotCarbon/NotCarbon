// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IProject} from "./IProject.sol";

interface IProjectManager {
    function registerProject(
        string memory _name,
        string memory _description,
        address _carbonCreditTokenAddress,
        uint256 _totalTokens,
        string memory _cellId
    ) external returns (address);

    function updateProjectStatus(address _projectAddress, IProject.ProjectState _newState) external;

    function requestProjectValidation(address _projectAddress) external returns (bytes32);

    function getValidationStatus(address _projectAddress)
        external
        view
        returns (bool validated, bool overlap, bool inconclusive, uint256 updatedAt);

    function isProjectRegistered(address _projectAddress) external view returns (bool);

    function setPricePerToken(uint256 _price) external;

    function setValidationOracleAdapter(address _adapter) external;

    function validationOracleAdapter() external view returns (address);

    function isValidationOracleConfigured() external view returns (bool);

    function getAllProjects() external view returns (address[] memory);

    function isApprovedCellId(string memory _cellId) external view returns (bool);

    function getApprovedCellIds() external view returns (string[] memory);
}
