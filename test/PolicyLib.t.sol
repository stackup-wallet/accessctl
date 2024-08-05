// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { IERC7579Account, CALLTYPE_SINGLE } from "modulekit/external/ERC7579.sol";
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

    function testUserOpNotCallingExecute() public {
        PackedUserOperation memory testOp;
        testOp.callData = hex"deadbeef";

        assertTrue(dummyAdminPolicy.verifyUserOp(testOp));

        vm.expectRevert("IAM12 not calling execute");
        dummy1EtherPolicy.verifyUserOp(testOp);
    }

    function testUserOpCallTypeSingle() public {
        PackedUserOperation memory testOp;
        testOp.callData = abi.encodeWithSelector(IERC7579Account.execute.selector, CALLTYPE_SINGLE);

        assertTrue(dummyAdminPolicy.verifyUserOp(testOp));

        vm.expectRevert("IAM13 callType not allowed");
        assertFalse(dummy1EtherPolicy.verifyUserOp(testOp));
    }

    function testVerifyERC1271Sender() public view {
        assertTrue(dummyAdminPolicy.verifyERC1271Caller(address(0)));
        assertFalse(dummy1EtherPolicy.verifyERC1271Caller(address(0)));
    }
}
