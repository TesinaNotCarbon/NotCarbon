// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ProjectManager} from "../src/ProjectManager.sol";
import {CREScoringOracle} from "../src/oracles/CREScoringOracle.sol";

contract DeployCREScoring is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address projectManagerAddress = vm.envAddress("PROJECT_MANAGER_ADDRESS");
        address forwarder = vm.envAddress("CRE_FORWARDER");

        vm.startBroadcast(deployerPrivateKey);

        CREScoringOracle scoringOracle = new CREScoringOracle(projectManagerAddress, deployer, forwarder);
        ProjectManager(projectManagerAddress).setScoringOracleAdapter(address(scoringOracle));

        vm.stopBroadcast();

        console2.log("CREScoringOracle:", address(scoringOracle));
        console2.log("ProjectManager:", projectManagerAddress);
        console2.log("CREForwarder:", forwarder);
        console2.log("Admin:", deployer);
    }
}
