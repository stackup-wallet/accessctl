// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/deployment/RegistryDeployer.sol";

// Import modules here
import { WebAuthnGroups } from "src/signers/WebAuthnGroups.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, RegistryDeployer {
    function run() public {
        vm.startBroadcast(vm.envUint("PK"));

        WebAuthnGroups sessionValidator = new WebAuthnGroups{ salt: 0 }();

        vm.stopBroadcast();
        console.log("Deploying WebAuthnGroups at: %s", address(sessionValidator));
    }
}
