// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {ICompanyManager} from "./interfaces/ICompanyManager.sol";
import {IProject} from "./interfaces/IProject.sol";
import {ICarbonCreditToken} from "./interfaces/ICarbonCreditToken.sol";

contract Project is IProject {
    address public projectManager;
    address public creator;
    string public override projectName;
    string public override projectDescription;

    IProject.ProjectState public override currentState;

    address public carbonCreditTokenAddress;
    uint256 public totalTokens;
    uint256 public purchasedTokens;
    uint256 public override pricePerToken;
    ICompanyManager public companyManager;
    ICarbonCreditToken public token;
    string public override cellId;

    event Deposit(address indexed from, uint256 amount);
    event StateChanged(ProjectState newState);
    event TokensPurchased(address indexed buyer, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);

    function _refund(address payable to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Refund failed");
    }

    modifier onlyProjectManager() {
        require(msg.sender == projectManager, "Only the project manager can execute this function.");
        _;
    }

    modifier onlyCreator() {
        require(msg.sender == creator, "Only the project creator can execute this function.");
        _;
    }

    constructor(
        string memory _name,
        string memory _description,
        address _carbonCreditTokenAddress,
        uint256 _totalTokens,
        address _creator,
        uint256 _pricePerToken,
        ICompanyManager _companyManager,
        string memory _cellId
    ) {
        projectManager = msg.sender;
        projectName = _name;
        projectDescription = _description;
        currentState = IProject.ProjectState.Registered;
        carbonCreditTokenAddress = _carbonCreditTokenAddress;
        token = ICarbonCreditToken(_carbonCreditTokenAddress);
        totalTokens = _totalTokens;
        purchasedTokens = 0;
        creator = _creator;
        pricePerToken = _pricePerToken;
        companyManager = _companyManager;
        cellId = _cellId;
    }

    // Update token price (only the project manager can call).
    function setPricePerToken(uint256 _price) public onlyProjectManager {
        pricePerToken = _price;
    }

    // Update the project state.
    function updateState(IProject.ProjectState _newState) external onlyProjectManager {
        require(uint256(_newState) > uint256(currentState), "New state must be a higher phase.");
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

    function getReleasedTokens() public view override returns (uint256) {
        if (currentState == IProject.ProjectState.Registered) {
            return 0;
        } else if (currentState == IProject.ProjectState.Validated) {
            return 0;
        } else if (currentState == IProject.ProjectState.Approved) {
            return (totalTokens * 10) / 100;
        } else if (currentState == IProject.ProjectState.Milestone1) {
            return (totalTokens * 25) / 100;
        } else if (currentState == IProject.ProjectState.Milestone2) {
            return (totalTokens * 50) / 100;
        } else if (currentState == IProject.ProjectState.Milestone3) {
            return (totalTokens * 75) / 100;
        } else if (currentState == IProject.ProjectState.Milestone4) {
            return totalTokens;
        }
        return 0;
    }

    // Buy tokens with ETH.
    function buyCarbonCredits(uint256 _amount) external payable override {
        // Ensure the caller sent enough ETH.
        uint256 totalCost = _amount * pricePerToken;
        require(msg.value >= totalCost, "Insufficient ETH sent");

        // Ensure enough tokens are released for this phase.
        require(_amount <= getAvailableTokens(), "Amount exceeds available tokens for this phase");

        // Ensure the contract has enough tokens.
        require(token.balanceOf(address(this)) >= _amount, "Insufficient token balance");

        // Transfer tokens to the buyer.
        require(token.transfer(msg.sender, _amount), "Token transfer failed");

        // Update purchased token count.
        purchasedTokens += _amount;

        _refund(payable(msg.sender), msg.value - totalCost);

        emit TokensPurchased(msg.sender, _amount);
    }

    // Allow the creator to withdraw accumulated ETH.
    function withdrawETH(uint256 _amount) public onlyCreator {
        require(address(this).balance >= _amount, "Insufficient ETH balance");
        (bool ok,) = payable(creator).call{value: _amount}("");
        require(ok, "ETH transfer failed");
        emit ETHWithdrawn(creator, _amount);
    }

    function buyFor(address buyer, uint256 amount) external payable override {
        require(companyManager.isApproved(payable(buyer)), "Company not approved");
        uint256 totalCost = amount * pricePerToken;
        require(msg.value >= totalCost, "Insufficient ETH");

        require(getReleasedTokens() - purchasedTokens >= amount, "Not enough tokens released");
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");

        require(token.transfer(buyer, amount), "Transfer failed");
        purchasedTokens += amount;

        _refund(payable(msg.sender), msg.value - totalCost);

        emit TokensPurchased(buyer, amount);
    }

    function getAvailableTokens() public view override returns (uint256) {
        return getReleasedTokens() - purchasedTokens;
    }
}
