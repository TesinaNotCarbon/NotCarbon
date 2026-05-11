// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {ProjectManager} from "../src/ProjectManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";

contract Setup is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address roleManagerAddress = vm.envAddress("ROLE_MANAGER_ADDRESS");
        address projectManagerAddress = vm.envAddress("PROJECT_MANAGER_ADDRESS");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");

        address staffAddress = vm.envOr("STAFF_ADDRESS", address(0));
        uint256 pricePerToken = vm.envOr("PRICE_PER_TOKEN", uint256(10));
        uint256 mintAmount = vm.envOr("MINT_AMOUNT", uint256(10000));
        uint256 setChainlink = vm.envOr("SET_CHAINLINK", uint256(0));

        RoleManager roleManager = RoleManager(roleManagerAddress);
        ProjectManager projectManager = ProjectManager(projectManagerAddress);
        CarbonCreditToken token = CarbonCreditToken(tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        if (staffAddress != address(0) && !roleManager.isStaff(staffAddress)) {
            roleManager.addStaff(staffAddress);
        }

        projectManager.setPricePerToken(pricePerToken);
        token.mint(mintAmount);

        if (setChainlink == 1) {
            address linkToken = vm.envAddress("CHAINLINK_LINK_TOKEN");
            address oracle = vm.envAddress("CHAINLINK_ORACLE");
            bytes32 jobId = vm.envBytes32("CHAINLINK_JOB_ID");
            uint256 fee = vm.envUint("CHAINLINK_FEE");
            projectManager.setChainlinkConfig(linkToken, oracle, jobId, fee);
        }

        vm.stopBroadcast();

        console2.log("RoleManager:", roleManagerAddress);
        console2.log("ProjectManager:", projectManagerAddress);
        console2.log("Token:", tokenAddress);
        if (staffAddress != address(0)) {
            console2.log("StaffAdded:", staffAddress);
        }
        console2.log("PricePerToken:", pricePerToken);
        console2.log("MintAmount:", mintAmount);
        if (setChainlink == 1) {
            console2.log("ChainlinkConfig: enabled");
        }
    }
}
