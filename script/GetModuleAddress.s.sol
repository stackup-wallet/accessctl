// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/deployment/RegistryDeployer.sol";

// Import modules here
import { WebAuthnValidator } from "src/session-validators/WebAuthnValidator.sol";
import { SudoPolicy } from "src/policies/SudoPolicy.sol";
import { IntervalSpendingLimitPolicy } from "src/policies/IntervalSpendingLimitPolicy.sol";

/// @title GetModuleAddressScript
contract GetModuleAddressScript is Script, RegistryDeployer {
    function run() public view {
        address sessionValidator = predictModuleAddress({
            initCode: type(WebAuthnValidator).creationCode,
            salt: bytes32(0)
        });
        address sudoPolicy =
            predictModuleAddress({ initCode: type(SudoPolicy).creationCode, salt: bytes32(0) });
        address spendingLimitPolicy = predictModuleAddress({
            initCode: type(IntervalSpendingLimitPolicy).creationCode,
            salt: bytes32(0)
        });

        console.log("Counterfactual WebAuthnValidator address: %s", sessionValidator);
        console.log("Counterfactual SudoPolicy address: %s", sudoPolicy);
        console.log("Counterfactual IntervalSpendingLimitPolicy address: %s", spendingLimitPolicy);
    }
}
