// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";

contract AuthenticationTest is TestHelper {
    function testERC1271ValidSignature() public {
        bytes32 rawHash = keccak256("0xdead");
        bytes32 formattedHash = _formatERC1271Hash(address(module), rawHash);

        bytes memory signature = _webAuthnSign(rootRoleId, formattedHash, dummyP256PrivateKeyRoot);
        assertTrue(_verifyERC1271Signature(address(module), rawHash, signature));
    }

    function testERC1271InvalidSignature() public {
        bytes32 rawHash = keccak256("0xdead");
        bytes32 formattedHash = _formatERC1271Hash(address(module), rawHash);

        bytes memory signature = _webAuthnSign(rootRoleId, formattedHash, dummyP256PrivateKey1);
        assertFalse(_verifyERC1271Signature(address(module), rawHash, signature));
    }
}
