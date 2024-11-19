// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/deployment/RegistryDeployer.sol";

// Import modules here
import { WebAuthnValidator } from "src/session-validators/WebAuthnValidator.sol";
import { SudoPolicy } from "src/policies/SudoPolicy.sol";
import { IntervalSpendingLimitPolicy } from "src/policies/IntervalSpendingLimitPolicy.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, RegistryDeployer {
    function run() public {
        bytes memory resolverContext = "";
        bytes memory metadata = "";
        vm.startBroadcast(vm.envUint("PK"));

        address sessionValidator = deployModule({
            initCode: type(WebAuthnValidator).creationCode,
            resolverContext: resolverContext,
            salt: bytes32(0),
            metadata: metadata
        });
        address sudoPolicy = deployModule({
            initCode: type(SudoPolicy).creationCode,
            resolverContext: resolverContext,
            salt: bytes32(0),
            metadata: metadata
        });
        address spendingLimitPolicy = deployModule({
            initCode: type(IntervalSpendingLimitPolicy).creationCode,
            resolverContext: resolverContext,
            salt: bytes32(0),
            metadata: metadata
        });

        vm.stopBroadcast();
        console.log("Deploying WebAuthnValidator at: %s", sessionValidator);
        console.log("Deploying SudoPolicy at: %s", sudoPolicy);
        console.log("Deploying IntervalSpendingLimitPolicy at: %s", spendingLimitPolicy);
    }
}
