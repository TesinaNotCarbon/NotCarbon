// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/ICompanyManager.sol";
interface ICarbonCreditToken {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Project {
    address public projectManager;
    address public creator;
    string public projectName;
    string public projectDescription;

    enum ProjectState {
        Phase0,
        Phase1,
        Phase2,
        Phase3,
        Phase4
    }
    ProjectState public currentState;

    address public carbonCreditTokenAddress;
    uint256 public totalTokens;
    uint256 public purchasedTokens;
    uint256 public pricePerToken;
    ICompanyManager public companyManager;
    ICarbonCreditToken public token;

    event Deposit(address indexed from, uint256 amount);
    event StateChanged(ProjectState newState);
    event TokensPurchased(address indexed buyer, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);

    modifier onlyProjectManager() {
        require(
            msg.sender == projectManager,
            "Only the project manager can execute this function."
        );
        _;
    }

    modifier onlyCreator() {
        require(
            msg.sender == creator,
            "Only the project creator can execute this function."
        );
        _;
    }

    constructor(
        string memory _name,
        string memory _description,
        address _carbonCreditTokenAddress,
        uint256 _totalTokens,
        address _creator,
        uint256 _pricePerToken,
        ICompanyManager _companyManager
    ) {
        projectManager = msg.sender;
        projectName = _name;
        projectDescription = _description;
        currentState = ProjectState.Phase0;
        carbonCreditTokenAddress = _carbonCreditTokenAddress;
        token = ICarbonCreditToken(_carbonCreditTokenAddress);
        totalTokens = _totalTokens;
        purchasedTokens = 0;
        creator = _creator;
        pricePerToken = _pricePerToken;
        companyManager = _companyManager;
    }

    // Función para actualizar el precio por token (solo el project manager puede llamarla)
    function setPricePerToken(uint256 _price) public onlyProjectManager {
        pricePerToken = _price;
    }

    // Función para actualizar el estado del proyecto
    function updateState(ProjectState _newState) external onlyProjectManager {
        require(
            uint(_newState) > uint(currentState),
            "New state must be a higher phase."
        );
        currentState = _newState;
        emit StateChanged(_newState);
    }

    function getCreator() public view returns (address) {
        return creator;
    }

    function deposit() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getReleasedTokens() public view returns (uint256) {
        if (currentState == ProjectState.Phase0) {
            return 0;
        } else if (currentState == ProjectState.Phase1) {
            return (totalTokens * 10) / 100;
        } else if (currentState == ProjectState.Phase2) {
            return (totalTokens * 40) / 100;
        } else if (currentState == ProjectState.Phase3) {
            return (totalTokens * 60) / 100;
        } else if (currentState == ProjectState.Phase4) {
            return totalTokens;
        }
        return 0;
    }

    // Función para comprar tokens con ETH
    function buyCarbonCredits(uint256 _amount) external payable {

        // Verificar que el usuario haya enviado suficiente ETH
        uint256 totalCost = _amount * pricePerToken;
        require(msg.value >= totalCost, "Insufficient ETH sent");

        // Verificar que hay suficientes tokens liberados
        require(
            _amount <= getAvailableTokens(),
            "Amount exceeds available tokens for this phase"
        );

        // Verificar que el contrato tiene suficientes tokens
        require(
            token.balanceOf(address(this)) >= _amount,
            "Insufficient token balance"
        );

        // Transferir tokens al usuario
        require(token.transfer(msg.sender, _amount), "Token transfer failed");

        // Actualizar la cantidad de tokens comprados
        purchasedTokens += _amount;

        emit TokensPurchased(msg.sender, _amount);
    }

    // Función para que el creator retire el ETH acumulado
    function withdrawETH(uint256 _amount) public onlyCreator {
        require(address(this).balance >= _amount, "Insufficient ETH balance");
        payable(creator).transfer(_amount);
        emit ETHWithdrawn(creator, _amount);
    }

    function buyFor(address buyer, uint256 amount) external payable {
        require(companyManager.isApproved(buyer), "Company not approved");
        uint256 totalCost = amount * pricePerToken;
        require(msg.value >= totalCost, "Insufficient ETH");

        require(
            getReleasedTokens() - purchasedTokens >= amount,
            "Not enough tokens released"
        );
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");

        require(token.transfer(buyer, amount), "Transfer failed");
        purchasedTokens += amount;
        emit TokensPurchased(buyer, amount);
    }

    function getAvailableTokens() public view returns (uint256) {
        return getReleasedTokens() - purchasedTokens;
    }
}
