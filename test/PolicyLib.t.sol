// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { Policy, PolicyLib, MODE_ADMIN } from "src/Policy.sol";

contract PolicyLibTest is TestHelper {
    using PolicyLib for Policy;

    function testIsEqual() public view {
        assertTrue(dummy1EtherPolicy.isEqual(dummy1EtherPolicy));
        assertFalse(dummy1EtherPolicy.isEqual(dummy5EtherPolicy));
    }

    function testisNull() public view {
        Policy memory testNullPolicy;
        assertTrue(testNullPolicy.isNull());
        assertFalse(dummy1EtherPolicy.isNull());
    }

    function testVerify() public view {
        PackedUserOperation memory testAdminOp;
        testAdminOp.callData = hex"dead";

        assertTrue(dummyAdminPolicy.verify(testAdminOp));
        assertFalse(dummy1EtherPolicy.verify(testAdminOp));
    }
}
