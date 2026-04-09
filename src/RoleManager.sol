// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract RoleManager {
    address public admin;
    mapping(address => bool) public staff;

    event StaffAdded(address indexed staffMember);
    event StaffRemoved(address indexed staffMember);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Solo el administrador puede ejecutar esta accion");
        _;
    }

    modifier onlyStaffOrAdmin() {
        require(msg.sender == admin || staff[msg.sender], "No tenes permisos para realizar esa accion!");
        _;
    }

    constructor() {
        admin = msg.sender; 
    }

    function addStaff(address _staff) public onlyAdmin{
    require(!staff[_staff], "Este usuario ya es staff"); 
    staff[_staff] = true; 
    emit StaffAdded(_staff); 
    }

    function removeStaff(address _staff) public onlyAdmin {
        staff[_staff] = false;
        emit StaffRemoved(_staff);
    }

    function isStaff(address _user) public view returns (bool) {
        return staff[_user];
    }
    function isStaffOrAdmin(address _user) public view returns (bool) {
        return (_user == admin || staff[_user]);
    }
}