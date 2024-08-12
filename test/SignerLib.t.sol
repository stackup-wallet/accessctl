// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { Signer, SignerLib, MODE_WEBAUTHN } from "src/Signer.sol";

contract PolicyLibTest is TestHelper {
    using SignerLib for Signer;

    function testIsEqual() public view {
        assertTrue(dummyRootSigner.isEqual(dummyRootSigner));
        assertFalse(dummyRootSigner.isEqual(dummySigner1));
    }

    function testisNull() public view {
        assertTrue(Signer(0, 0, address(0), MODE_WEBAUTHN).isNull());
        assertFalse(dummyRootSigner.isNull());
    }
}
