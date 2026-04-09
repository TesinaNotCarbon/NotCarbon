// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRoleManager {
    function admin() external view returns (address);
    function isStaff(address _user) external view returns (bool);
    function isStaffOrAdmin(address _user) external view returns (bool);
}
