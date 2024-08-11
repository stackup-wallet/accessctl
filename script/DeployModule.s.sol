// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/deployment/RegistryDeployer.sol";

// Import modules here
import { IAMModule } from "src/IAMModule.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, RegistryDeployer {
    function run() public {
        vm.startBroadcast(vm.envUint("PK"));

        IAMModule module = new IAMModule{ salt: 0 }();

        vm.stopBroadcast();
        console.log("Deploying module at: %s", address(module));
    }
}
