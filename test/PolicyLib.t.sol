// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { Policy, CallInput, ADMIN_MODE } from "src/Policy.sol";
import { PolicyLib } from "src/PolicyLib.sol";

contract PolicyLibTest is TestHelper {
    using PolicyLib for Policy;

    function testisNull() public view {
        assertTrue(testNullPolicy.isNull());
        assertFalse(testAdminPolicy.isNull());
    }

    function testVerify() public view {
        PackedUserOperation memory testAdminOp;
        testAdminOp.callData = hex"dead";

        assertFalse(testNullPolicy.verify(testAdminOp));
        assertTrue(testAdminPolicy.verify(testAdminOp));
    }
}
