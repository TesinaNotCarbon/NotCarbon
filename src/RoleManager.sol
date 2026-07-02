// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";

contract RoleManager is Initializable, UUPSUpgradeable, IRoleManager {
    address public override admin;
    address public upgradeController;
    mapping(address => bool) public staff;

    event StaffAdded(address indexed staffMember);
    event StaffRemoved(address indexed staffMember);
    event UpgradeControllerUpdated(address indexed previousController, address indexed newController);

    modifier onlyUpgradeController() {
        require(msg.sender == upgradeController, "Only upgrade controller.");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can execute this action.");
        _;
    }

    modifier onlyStaffOrAdmin() {
        require(msg.sender == admin || staff[msg.sender], "Only staff or admin can execute this action.");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _upgradeController) public initializer {
        require(_admin != address(0), "Invalid admin.");
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        admin = _admin;
        upgradeController = _upgradeController;
    }

    function setUpgradeController(address _upgradeController) external onlyUpgradeController {
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        emit UpgradeControllerUpdated(upgradeController, _upgradeController);
        upgradeController = _upgradeController;
    }

    function addStaff(address _staff) public onlyAdmin {
        require(!staff[_staff], "User is already staff.");
        staff[_staff] = true;
        emit StaffAdded(_staff);
    }

    function removeStaff(address _staff) public onlyAdmin {
        staff[_staff] = false;
        emit StaffRemoved(_staff);
    }

    function isStaff(address _user) public view override returns (bool) {
        return staff[_user];
    }

    function isStaffOrAdmin(address _user) public view override returns (bool) {
        return (_user == admin || staff[_user]);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgradeController {}

    uint256[50] private __gap;
}
