// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {CompanyManager} from "../src/CompanyManager.sol";
import {ProjectManager} from "../src/ProjectManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";
import {CarbonCreditMarket} from "../src/CarbonCreditMarket.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        RoleManager roleManager = new RoleManager();
        CompanyManager companyManager = new CompanyManager(address(roleManager));
        ProjectManager projectManager = new ProjectManager(address(roleManager), address(companyManager));
        CarbonCreditToken carbonToken = new CarbonCreditToken(address(projectManager), address(roleManager));
        CarbonCreditMarket carbonMarket = new CarbonCreditMarket(address(projectManager), address(companyManager));

        projectManager.setPricePerToken(10);
        carbonToken.mint(10000);

        vm.stopBroadcast();

        console2.log("RoleManager:", address(roleManager));
        console2.log("CompanyManager:", address(companyManager));
        console2.log("ProjectManager:", address(projectManager));
        console2.log("CarbonCreditToken:", address(carbonToken));
        console2.log("CarbonCreditMarket:", address(carbonMarket));
    }
}
