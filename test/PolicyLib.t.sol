// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { Policy, CallInput, ADMIN_MODE } from "src/Policy.sol";
import { PolicyLib } from "src/PolicyLib.sol";

contract PolicyLibTest is Test {
    using PolicyLib for Policy;

    Policy public testNullPolicy;
    Policy public testAdminPolicy;

    function setUp() public {
        testAdminPolicy.mode = ADMIN_MODE;
    }

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
