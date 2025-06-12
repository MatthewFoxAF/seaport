// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {TargetedTradeZone} from "../contracts/zones/TargetTradeZone.sol";

contract DeployTargetTradeZone is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Starting TargetTradeZone Deployment ===");
        console.log("Deploying from:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the TargetedTradeZone contract
        TargetedTradeZone zone = new TargetedTradeZone();
        console.log("TargetedTradeZone deployed at:", address(zone));

        vm.stopBroadcast();

        // Verify the deployment
        console.log("");
        console.log("=== Deployment Verification ===");
        
        // Check interface support
        console.log("Supports ZoneInterface:", zone.supportsInterface(0x3839be19));
        console.log("Supports ERC165:", zone.supportsInterface(0x01ffc9a7));
        
        // Get metadata
        (string memory name, ) = zone.getSeaportMetadata();
        console.log("Zone Name:", name);
        
        // Test with a dummy order hash
        bytes32 testOrderHash = keccak256("test");
        address targetFulfiller = zone.getOrderTarget(testOrderHash);
        console.log("Test order target (should be 0x0):", targetFulfiller);
        
        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("ZONE CONTRACT ADDRESS:", address(zone));
        console.log("");
        console.log("Zone is ready to be used with Seaport!");
        console.log("Configure Seaport orders to use this zone address");
        console.log("");
        console.log("Usage:");
        console.log("1. When creating orders, set zone to:", address(zone));
        console.log("2. Include target fulfiller in extraData: abi.encode(targetAddress)");
    }
}