// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICompany {
    function buyFromProject(address payable projectAddress, uint256 amount) external payable;

    function buyFromMarket(address market, uint256 amount) external payable;

    function approve() external;

    function isApproved() external view returns (bool);
}
