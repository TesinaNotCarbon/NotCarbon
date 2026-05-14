// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProject {
    enum ProjectState {
        Registered,
        Validated,
        Approved,
        Milestone1,
        Milestone2,
        Milestone3,
        Milestone4
    }

    function buyCarbonCredits(uint256 _amount) external payable;

    function buyFor(address buyer, uint256 amount) external payable;

    function getReleasedTokens() external view returns (uint256);

    function pricePerToken() external view returns (uint256);

    function currentState() external view returns (ProjectState);

    function updateState(ProjectState _newState) external;

    function projectName() external view returns (string memory);

    function projectDescription() external view returns (string memory);

    function cellId() external view returns (string memory);

    function getAvailableTokens() external view returns (uint256);
}
