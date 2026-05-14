// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";
import {ICarbonCreditToken} from "./interfaces/ICarbonCreditToken.sol";

contract CarbonCreditToken is ERC20, ICarbonCreditToken {
    address public admin;
    address public projectManager;
    IRoleManager public roleManager;
    // Event to record minting new tokens.
    event TokensMinted(address indexed to, uint256 amount);

    modifier onlyProjectManager() {
        require(msg.sender == projectManager, "Only the project manager can execute this function.");
        _;
    }

    modifier onlyApprover() {
        require(roleManager.isStaffOrAdmin(msg.sender), "Only staff or admin can execute this function.");
        _;
    }

    constructor(address _projectManager, address _roleManager) ERC20("CarbonCreditToken", "CCT") {
        admin = msg.sender;
        projectManager = _projectManager;
        roleManager = IRoleManager(_roleManager);
    }

    function transfer(address recipient, uint256 amount) public override(ERC20, ICarbonCreditToken) returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override(ERC20, ICarbonCreditToken)
        returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }

    function balanceOf(address account) public view override(ERC20, ICarbonCreditToken) returns (uint256) {
        return super.balanceOf(account);
    }

    // Mint new tokens and assign them to the contract.
    function mint(uint256 amount) public override onlyApprover {
        _mint(address(this), amount);
        emit TokensMinted(address(this), amount);
    }

    // Transfer tokens from the contract to another address.
    function transferTokens(address recipient, uint256 amount) public override onlyProjectManager {
        require(balanceOf(address(this)) >= amount, "Insufficient token balance in contract");
        _transfer(address(this), recipient, amount);
    }

    // Burn tokens.
    function burn(uint256 amount) public override {
        _burn(msg.sender, amount); // Burn tokens from the caller.
    }
}
