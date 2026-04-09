// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProject {
    enum ProjectState {
        Phase0,
        Phase1,
        Phase2,
        Phase3,
        Phase4
    }

    function buyCarbonCredits(uint256 _amount) external payable;
    
    function buyFor(address buyer, uint256 amount) external payable;
    
    function getReleasedTokens() external view returns (uint256);
    
    function pricePerToken() external view returns (uint256);
    
    function currentState() external view returns (ProjectState);
    
    function projectName() external view returns (string memory);
    
    function projectDescription() external view returns (string memory);

    function getAvailableTokens() external view returns (uint256);
}
