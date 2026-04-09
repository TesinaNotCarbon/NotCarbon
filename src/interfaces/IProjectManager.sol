// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IProject} from "./IProject.sol";

interface IProjectManager {
    function registerProject(
        string memory _name,
        string memory _description,
        address _carbonCreditTokenAddress,
        uint256 _totalTokens
    ) external returns (address);

    function updateProjectStatus(address _projectAddress, IProject.ProjectState _newState) external;

    function isProjectRegistered(address _projectAddress) external view returns (bool);

    function setPricePerToken(uint256 _price) external;

    function getAllProjects() external view returns (address[] memory);
}
