// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";
import {ICarbonCreditToken} from "./interfaces/ICarbonCreditToken.sol";

contract CarbonCreditToken is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ICarbonCreditToken
{
    address public admin;
    address public projectManager;
    IRoleManager public roleManager;
    address public upgradeController;
    // Event to record minting new tokens.
    event TokensMinted(address indexed to, uint256 amount);

    modifier onlyUpgradeController() {
        require(msg.sender == upgradeController, "Only upgrade controller.");
        _;
    }

    modifier onlyProjectManager() {
        require(msg.sender == projectManager, "Only the project manager can execute this function.");
        _;
    }

    modifier onlyApprover() {
        require(roleManager.isStaffOrAdmin(msg.sender), "Only staff or admin can execute this function.");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _projectManager, address _roleManager, address _admin, address _upgradeController)
        public
        initializer
    {
        require(_projectManager != address(0), "Invalid project manager.");
        require(_roleManager != address(0), "Invalid role manager.");
        require(_admin != address(0), "Invalid admin.");
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        __ERC20_init("CarbonCreditToken", "CCT");
        __Pausable_init();
        admin = _admin;
        projectManager = _projectManager;
        roleManager = IRoleManager(_roleManager);
        upgradeController = _upgradeController;
    }

    function setUpgradeController(address _upgradeController) external onlyUpgradeController {
        require(_upgradeController != address(0), "Invalid upgrade controller.");
        upgradeController = _upgradeController;
    }

    function transfer(address recipient, uint256 amount)
        public
        override(ERC20Upgradeable, ICarbonCreditToken)
        returns (bool)
    {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override(ERC20Upgradeable, ICarbonCreditToken)
        returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }

    function balanceOf(address account) public view override(ERC20Upgradeable, ICarbonCreditToken) returns (uint256) {
        return super.balanceOf(account);
    }

    // Mint new tokens and assign them to the contract.
    function mint(uint256 amount) public override onlyApprover whenNotPaused {
        _mint(address(this), amount);
        emit TokensMinted(address(this), amount);
    }

    // Transfer tokens from the contract to another address.
    function transferTokens(address recipient, uint256 amount) public override onlyProjectManager whenNotPaused {
        require(balanceOf(address(this)) >= amount, "Insufficient token balance in contract");
        _transfer(address(this), recipient, amount);
    }

    // Burn tokens.
    function burn(uint256 amount) public override {
        _burn(msg.sender, amount); // Burn tokens from the caller.
    }

    function pause() external onlyUpgradeController {
        _pause();
    }

    function unpause() external onlyUpgradeController {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgradeController {}

    uint256[50] private __gap;
}
