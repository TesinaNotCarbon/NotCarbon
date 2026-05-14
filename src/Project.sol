// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {ICompanyManager} from "./interfaces/ICompanyManager.sol";
import {IProject} from "./interfaces/IProject.sol";
import {ICarbonCreditToken} from "./interfaces/ICarbonCreditToken.sol";

contract Project is IProject {
    struct ProjectMeta {
        string name;
        string description;
        string cellId;
    }

    struct ProjectAccounts {
        address projectManager;
        address creator;
        address carbonCreditTokenAddress;
        address companyManager;
    }

    struct ProjectEconomics {
        uint256 totalTokens;
        uint256 purchasedTokens;
        uint256 pricePerToken;
    }

    ProjectMeta private meta;
    ProjectAccounts private accounts;
    ProjectEconomics private economics;
    IProject.ProjectState private state;

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
        require(msg.sender == accounts.projectManager, "Only the project manager can execute this function.");
        _;
    }

    modifier onlyCreator() {
        require(msg.sender == accounts.creator, "Only the project creator can execute this function.");
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
        accounts.projectManager = msg.sender;
        accounts.creator = _creator;
        accounts.carbonCreditTokenAddress = _carbonCreditTokenAddress;
        accounts.companyManager = address(_companyManager);
        meta.name = _name;
        meta.description = _description;
        meta.cellId = _cellId;
        state = IProject.ProjectState.Registered;
        economics.totalTokens = _totalTokens;
        economics.purchasedTokens = 0;
        economics.pricePerToken = _pricePerToken;
    }

    function projectManager() public view returns (address) {
        return accounts.projectManager;
    }

    function creator() public view returns (address) {
        return accounts.creator;
    }

    function carbonCreditTokenAddress() public view returns (address) {
        return accounts.carbonCreditTokenAddress;
    }

    function companyManager() public view returns (ICompanyManager) {
        return ICompanyManager(accounts.companyManager);
    }

    function token() public view returns (ICarbonCreditToken) {
        return ICarbonCreditToken(accounts.carbonCreditTokenAddress);
    }

    function totalTokens() public view returns (uint256) {
        return economics.totalTokens;
    }

    function purchasedTokens() public view returns (uint256) {
        return economics.purchasedTokens;
    }

    function projectName() public view override returns (string memory) {
        return meta.name;
    }

    function projectDescription() public view override returns (string memory) {
        return meta.description;
    }

    function cellId() public view override returns (string memory) {
        return meta.cellId;
    }

    function pricePerToken() public view override returns (uint256) {
        return economics.pricePerToken;
    }

    function currentState() public view override returns (IProject.ProjectState) {
        return state;
    }

    // Update token price (only the project manager can call).
    function setPricePerToken(uint256 _price) public onlyProjectManager {
        economics.pricePerToken = _price;
    }

    // Update the project state.
    function updateState(IProject.ProjectState _newState) external onlyProjectManager {
        require(uint256(_newState) > uint256(state), "New state must be a higher phase.");
        state = _newState;
        emit StateChanged(_newState);
    }

    function getCreator() public view returns (address) {
        return accounts.creator;
    }

    function deposit() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getReleasedTokens() public view override returns (uint256) {
        if (state == IProject.ProjectState.Registered) {
            return 0;
        } else if (state == IProject.ProjectState.Validated) {
            return 0;
        } else if (state == IProject.ProjectState.Approved) {
            return (economics.totalTokens * 10) / 100;
        } else if (state == IProject.ProjectState.Milestone1) {
            return (economics.totalTokens * 25) / 100;
        } else if (state == IProject.ProjectState.Milestone2) {
            return (economics.totalTokens * 50) / 100;
        } else if (state == IProject.ProjectState.Milestone3) {
            return (economics.totalTokens * 75) / 100;
        } else if (state == IProject.ProjectState.Milestone4) {
            return economics.totalTokens;
        }
        return 0;
    }

    // Buy tokens with ETH.
    function buyCarbonCredits(uint256 _amount) external payable override {
        // Ensure the caller sent enough ETH.
        uint256 totalCost = _amount * economics.pricePerToken;
        require(msg.value >= totalCost, "Insufficient ETH sent");

        // Ensure enough tokens are released for this phase.
        require(_amount <= getAvailableTokens(), "Amount exceeds available tokens for this phase");

        // Ensure the contract has enough tokens.
        ICarbonCreditToken projectToken = ICarbonCreditToken(accounts.carbonCreditTokenAddress);
        require(projectToken.balanceOf(address(this)) >= _amount, "Insufficient token balance");

        // Transfer tokens to the buyer.
        require(projectToken.transfer(msg.sender, _amount), "Token transfer failed");

        // Update purchased token count.
        economics.purchasedTokens += _amount;

        _refund(payable(msg.sender), msg.value - totalCost);

        emit TokensPurchased(msg.sender, _amount);
    }

    // Allow the creator to withdraw accumulated ETH.
    function withdrawETH(uint256 _amount) public onlyCreator {
        require(address(this).balance >= _amount, "Insufficient ETH balance");
        (bool ok,) = payable(accounts.creator).call{value: _amount}("");
        require(ok, "ETH transfer failed");
        emit ETHWithdrawn(accounts.creator, _amount);
    }

    function buyFor(address buyer, uint256 amount) external payable override {
        require(ICompanyManager(accounts.companyManager).isApproved(payable(buyer)), "Company not approved");
        uint256 totalCost = amount * economics.pricePerToken;
        require(msg.value >= totalCost, "Insufficient ETH");

        require(getReleasedTokens() - economics.purchasedTokens >= amount, "Not enough tokens released");
        ICarbonCreditToken projectToken = ICarbonCreditToken(accounts.carbonCreditTokenAddress);
        require(projectToken.balanceOf(address(this)) >= amount, "Insufficient balance");

        require(projectToken.transfer(buyer, amount), "Transfer failed");
        economics.purchasedTokens += amount;

        _refund(payable(msg.sender), msg.value - totalCost);

        emit TokensPurchased(buyer, amount);
    }

    function getAvailableTokens() public view override returns (uint256) {
        return getReleasedTokens() - economics.purchasedTokens;
    }
}
