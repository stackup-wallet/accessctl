// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { Signer, SignerLib } from "src/Signer.sol";

contract PolicyLibTest is TestHelper {
    using SignerLib for Signer;

    function testIsEqual() public view {
        assertTrue(dummyRootSigner.isEqual(dummyRootSigner));
        assertFalse(dummyRootSigner.isEqual(dummySigner1));
    }

    function testisNull() public view {
        assertTrue(Signer(0, 0).isNull());
        assertFalse(dummyRootSigner.isNull());
    }
}
