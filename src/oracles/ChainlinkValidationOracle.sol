// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ChainlinkClient} from "chainlink-brownie-contracts/contracts/src/v0.8/ChainlinkClient.sol";
import {Chainlink} from "chainlink-brownie-contracts/contracts/src/v0.8/Chainlink.sol";
import {LinkTokenInterface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IProjectValidationOracle} from "../interfaces/IProjectValidationOracle.sol";
import {IProjectValidationReceiver} from "../interfaces/IProjectValidationReceiver.sol";

contract ChainlinkValidationOracle is IProjectValidationOracle, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    address public admin;
    address public receiver;
    bytes32 public jobId;
    uint256 public fee;

    event ValidationRequested(bytes32 indexed requestId, address indexed projectAddress, string cellId);
    event ChainlinkConfigUpdated(address indexed linkToken, address indexed oracle, bytes32 jobId, uint256 fee);
    event ReceiverUpdated(address indexed receiver);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can execute this function.");
        _;
    }

    modifier onlyReceiver() {
        require(msg.sender == receiver, "Only the receiver can execute this function.");
        _;
    }

    constructor(address _receiver, address _admin) {
        require(_receiver != address(0), "Invalid receiver.");
        require(_admin != address(0), "Invalid admin.");
        receiver = _receiver;
        admin = _admin;
    }

    function setReceiver(address _receiver) external onlyAdmin {
        require(_receiver != address(0), "Invalid receiver.");
        receiver = _receiver;
        emit ReceiverUpdated(_receiver);
    }

    function setChainlinkConfig(address _linkToken, address _oracle, bytes32 _jobId, uint256 _fee)
        external
        onlyAdmin
    {
        require(_linkToken != address(0), "Invalid LINK token.");
        require(_oracle != address(0), "Invalid oracle.");
        require(_jobId != bytes32(0), "Invalid job id.");
        _setChainlinkToken(_linkToken);
        _setChainlinkOracle(_oracle);
        jobId = _jobId;
        fee = _fee;
        emit ChainlinkConfigUpdated(_linkToken, _oracle, _jobId, _fee);
    }

    function isConfigured() public view override returns (bool) {
        return _chainlinkOracleAddress() != address(0) && jobId != bytes32(0);
    }

    function requestValidation(address projectAddress, string calldata cellId)
        external
        override
        onlyReceiver
        returns (bytes32)
    {
        require(isConfigured(), "Chainlink config not set.");
        Chainlink.Request memory req = _buildOperatorRequest(jobId, this.fulfillValidation.selector);
        req._add("cell_id", cellId);
        bytes32 requestId = _sendOperatorRequest(req, fee);
        emit ValidationRequested(requestId, projectAddress, cellId);
        return requestId;
    }

    function fulfillValidation(bytes32 requestId, bool overlap, bool inconclusive)
        public
        recordChainlinkFulfillment(requestId)
    {
        IProjectValidationReceiver(receiver).receiveValidationResult(requestId, overlap, inconclusive);
    }

    function withdrawLink(address _to, uint256 _amount) external onlyAdmin {
        require(_to != address(0), "Invalid recipient.");
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(link.transfer(_to, _amount), "LINK transfer failed.");
    }
}
