// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/deployment/RegistryDeployer.sol";

// Import modules here
import { WebAuthnValidator } from "src/signers/WebAuthnValidator.sol";
import { IntervalSpendingLimitPolicy } from "src/policies/IntervalSpendingLimitPolicy.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, RegistryDeployer {
    function run() public {
        vm.startBroadcast(vm.envUint("PK"));

        WebAuthnValidator sessionValidator = new WebAuthnValidator{ salt: 0 }();

        IntervalSpendingLimitPolicy spendingLimitPolicy =
            new IntervalSpendingLimitPolicy{ salt: 0 }();

        vm.stopBroadcast();
        console.log("Deploying WebAuthnValidator at: %s", address(sessionValidator));
        console.log("Deploying IntervalSpendingLimitPolicy at: %s", address(spendingLimitPolicy));
    }
}
