// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IRoleManager.sol";

contract CarbonCreditToken is ERC20 {
    address public admin;
    address public projectManager;
    IRoleManager public roleManager;
    // Evento para registrar la creación de nuevos tokens
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

    // Función para minar (crear) nuevos tokens y asignarlos al contrato
    function mint(uint256 amount) public onlyApprover {
        _mint(address(this), amount); 
        emit TokensMinted(address(this), amount);
    }

    // Función para transferir tokens desde el contrato a otra dirección
    function transferTokens(address recipient, uint256 amount) public onlyProjectManager {
        require(balanceOf(address(this)) >= amount, "Insufficient token balance in contract");
        _transfer(address(this), recipient, amount);
    }

    // Función para quemar (destruir) tokens
    function burn(uint256 amount) public {
        _burn(msg.sender, amount); // Quema tokens de la dirección que llama la función
    }
}