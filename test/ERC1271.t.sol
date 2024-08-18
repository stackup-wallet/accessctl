// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { AccountType } from "modulekit/test/RhinestoneModuleKit.sol";
import { TestHelper } from "test/TestHelper.sol";

contract AuthenticationTest is TestHelper {
    function testERC1271ValidSignature() public {
        // TODO: Figure out proper ERC1271 setup for NEXUS
        if (instance.accountType == AccountType.NEXUS) return;

        bytes32 rawHash = keccak256("0xdead");
        bytes32 formattedHash = _formatERC1271Hash(address(module), rawHash);

        bytes memory signature = _webAuthnSign(rootRoleId, formattedHash, dummyP256PrivateKeyRoot);
        assertTrue(_verifyERC1271Signature(address(module), rawHash, signature));
    }

    function testERC1271InvalidSignature() public {
        // TODO: Figure out proper ERC1271 setup for NEXUS
        if (instance.accountType == AccountType.NEXUS) return;

        bytes32 rawHash = keccak256("0xdead");
        bytes32 formattedHash = _formatERC1271Hash(address(module), rawHash);

        bytes memory signature = _webAuthnSign(rootRoleId, formattedHash, dummyP256PrivateKey1);
        assertFalse(_verifyERC1271Signature(address(module), rawHash, signature));
    }
}
