// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/deployment/RegistryDeployer.sol";

// Import modules here
import { IAMModule } from "src/IAMModule.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, RegistryDeployer {
    function run() public {
        // Setup module bytecode, deploy params, and data
        bytes memory bytecode = type(IAMModule).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(bytecode));

        // Get private key for deployment
        vm.startBroadcast(vm.envUint("PK"));
        address computedAddress = vm.computeCreate2Address(salt, keccak256(bytecode), address(this));

        console.log(computedAddress);

        IAMModule iammodule = new IAMModule{ salt: salt }();

        // Stop broadcast and log module address
        vm.stopBroadcast();
        console.log("Deploying module at: %s", address(iammodule));
    }
}
