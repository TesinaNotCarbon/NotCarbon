// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {CompanyManager} from "../src/CompanyManager.sol";
import {ProjectManager} from "../src/ProjectManager.sol";
import {CarbonCreditToken} from "../src/CarbonCreditToken.sol";
import {CarbonCreditMarket} from "../src/CarbonCreditMarket.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 pricePerToken = vm.envOr("PRICE_PER_TOKEN", uint256(10));
        uint256 mintAmount = vm.envOr("MINT_AMOUNT", uint256(10000));

        vm.startBroadcast(deployerPrivateKey);

        RoleManager roleManagerImpl = new RoleManager();
        RoleManager roleManager = RoleManager(
            address(
                new ERC1967Proxy(address(roleManagerImpl), abi.encodeCall(RoleManager.initialize, (deployer, deployer)))
            )
        );

        CompanyManager companyManagerImpl = new CompanyManager();
        CompanyManager companyManager = CompanyManager(
            address(
                new ERC1967Proxy(
                    address(companyManagerImpl),
                    abi.encodeCall(CompanyManager.initialize, (address(roleManager), deployer))
                )
            )
        );

        ProjectManager projectManagerImpl = new ProjectManager();
        ProjectManager projectManager = ProjectManager(
            address(
                new ERC1967Proxy(
                    address(projectManagerImpl),
                    abi.encodeCall(
                        ProjectManager.initialize, (address(roleManager), address(companyManager), deployer, deployer)
                    )
                )
            )
        );

        CarbonCreditToken carbonTokenImpl = new CarbonCreditToken();
        CarbonCreditToken carbonToken = CarbonCreditToken(
            address(
                new ERC1967Proxy(
                    address(carbonTokenImpl),
                    abi.encodeCall(
                        CarbonCreditToken.initialize,
                        (address(projectManager), address(roleManager), deployer, deployer)
                    )
                )
            )
        );

        CarbonCreditMarket carbonMarketImpl = new CarbonCreditMarket();
        CarbonCreditMarket carbonMarket = CarbonCreditMarket(
            address(
                new ERC1967Proxy(
                    address(carbonMarketImpl),
                    abi.encodeCall(
                        CarbonCreditMarket.initialize, (address(projectManager), address(companyManager), deployer)
                    )
                )
            )
        );

        projectManager.setPricePerToken(pricePerToken);
        carbonToken.mint(mintAmount);

        vm.stopBroadcast();

        console2.log("RoleManager:", address(roleManager));
        console2.log("CompanyManager:", address(companyManager));
        console2.log("ProjectManager:", address(projectManager));
        console2.log("CarbonCreditToken:", address(carbonToken));
        console2.log("CarbonCreditMarket:", address(carbonMarket));
        console2.log("PricePerToken:", pricePerToken);
        console2.log("MintAmount:", mintAmount);
    }
}
