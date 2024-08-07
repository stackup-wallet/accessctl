// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import {
    IERC7579Account,
    CallType,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_STATIC,
    CALLTYPE_DELEGATECALL
} from "modulekit/external/ERC7579.sol";
import { Policy, PolicyLib, MODE_ADMIN } from "src/Policy.sol";

contract PolicyLibTest is TestHelper {
    using PolicyLib for Policy;

    function testIsEqual() public view {
        assertTrue(dummy1EtherSinglePolicy.isEqual(dummy1EtherSinglePolicy));
        assertFalse(dummy1EtherSinglePolicy.isEqual(dummy5EtherBatchPolicy));
    }

    function testisNull() public view {
        Policy memory testNullPolicy;
        assertTrue(testNullPolicy.isNull());
        assertFalse(dummy1EtherSinglePolicy.isNull());
    }

    function testUserOpNotCallingExecute() public {
        PackedUserOperation memory testOp;
        testOp.callData = hex"deadbeef";

        assertTrue(dummyAdminPolicy.verifyUserOp(testOp));

        vm.expectRevert("IAM12 not calling execute");
        dummy1EtherSinglePolicy.verifyUserOp(testOp);
    }

    function testUserOpCallTypeSingle() public {
        PackedUserOperation memory callTypeSingeOp;
        callTypeSingeOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector, bytes32(CallType.unwrap(CALLTYPE_SINGLE)), ""
        );

        assertTrue(dummyAdminPolicy.verifyUserOp(callTypeSingeOp));
        assertTrue(dummy5EtherBatchPolicy.verifyUserOp(callTypeSingeOp));
        assertTrue(dummy1EtherSinglePolicy.verifyUserOp(callTypeSingeOp));
    }

    function testUserOperationCallTypeBatch() public {
        PackedUserOperation memory callTypeBatchOp;
        callTypeBatchOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector, bytes32(CallType.unwrap(CALLTYPE_BATCH)), ""
        );

        assertTrue(dummyAdminPolicy.verifyUserOp(callTypeBatchOp));
        assertTrue(dummy5EtherBatchPolicy.verifyUserOp(callTypeBatchOp));
        vm.expectRevert("IAM13 callType not allowed");
        dummy1EtherSinglePolicy.verifyUserOp(callTypeBatchOp);
    }

    function testUserOperationCallTypeStatic() public {
        PackedUserOperation memory callTypeStaticOp;
        callTypeStaticOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector, bytes32(CallType.unwrap(CALLTYPE_STATIC)), ""
        );

        assertTrue(dummyAdminPolicy.verifyUserOp(callTypeStaticOp));
        vm.expectRevert("IAM13 callType not allowed");
        dummy5EtherBatchPolicy.verifyUserOp(callTypeStaticOp);
        vm.expectRevert("IAM13 callType not allowed");
        dummy1EtherSinglePolicy.verifyUserOp(callTypeStaticOp);
    }

    function testUserOperationCallTypeDelegate() public {
        PackedUserOperation memory callTypeDelegateOp;
        callTypeDelegateOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector, bytes32(CallType.unwrap(CALLTYPE_DELEGATECALL)), ""
        );

        assertTrue(dummyAdminPolicy.verifyUserOp(callTypeDelegateOp));
        vm.expectRevert("IAM13 callType not allowed");
        dummy5EtherBatchPolicy.verifyUserOp(callTypeDelegateOp);
        vm.expectRevert("IAM13 callType not allowed");
        dummy1EtherSinglePolicy.verifyUserOp(callTypeDelegateOp);
    }

    function testVerifyERC1271Sender() public view {
        assertTrue(dummyAdminPolicy.verifyERC1271Caller(address(0)));
        assertFalse(dummy1EtherSinglePolicy.verifyERC1271Caller(address(0)));
    }
}
