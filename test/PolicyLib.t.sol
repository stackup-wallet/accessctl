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
    CALLTYPE_DELEGATECALL,
    Execution
} from "modulekit/external/ERC7579.sol";
import { Policy, PolicyLib, MODE_ADMIN } from "src/Policy.sol";
import { Action } from "src/Action.sol";

contract PolicyLibTest is TestHelper {
    using PolicyLib for Policy;

    Action[] public nullActions;
    Action[] public sendMax5EtherActions;
    Action[] public sendMax1EtherActions;

    Execution[] public executionsLessThan1Eth;
    Execution[] public executionsLessThan10Eth;

    constructor() {
        sendMax5EtherActions.push(dummySendMax5EtherAction);
        sendMax1EtherActions.push(dummySendMax1EtherAction);
        executionsLessThan1Eth.push(Execution(address(0), uint256(0.5 ether), ""));
        executionsLessThan1Eth.push(Execution(address(0), uint256(0.75 ether), ""));
        executionsLessThan10Eth.push(Execution(address(0), uint256(5 ether), ""));
        executionsLessThan10Eth.push(Execution(address(0), uint256(7.5 ether), ""));
    }

    function testIsEqual() public view {
        assertTrue(dummy1EtherSinglePolicy.isEqual(dummy1EtherSinglePolicy));
        assertFalse(dummy1EtherSinglePolicy.isEqual(dummy5EtherBatchPolicy));
    }

    function testisNull() public view {
        Policy memory testNullPolicy;
        assertTrue(testNullPolicy.isNull());
        assertFalse(dummy1EtherSinglePolicy.isNull());
    }

    function testUserOperationNotCallingExecute() public view {
        PackedUserOperation memory testOp;
        testOp.callData = hex"deadbeef";

        (bool ok, string memory reason) = dummyAdminPolicy.verifyUserOp(testOp, nullActions);
        assertTrue(ok);
        assertEq(reason, "");

        (ok, reason) = dummy1EtherSinglePolicy.verifyUserOp(testOp, sendMax1EtherActions);
        assertFalse(ok);
        assertEq(reason, "IAM11 not calling execute");
    }

    function testUserOperationCallTypeSingle() public view {
        PackedUserOperation memory callTypeSingeOp;
        callTypeSingeOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            bytes32(CallType.unwrap(CALLTYPE_SINGLE)),
            abi.encodePacked(address(0), uint256(0.5 ether), hex"deadbeef")
        );

        (bool ok, string memory reason) =
            dummyAdminPolicy.verifyUserOp(callTypeSingeOp, nullActions);
        assertTrue(ok);
        assertEq(reason, "");
        (ok, reason) = dummy5EtherBatchPolicy.verifyUserOp(callTypeSingeOp, sendMax5EtherActions);
        assertTrue(ok);
        assertEq(reason, "");
        (ok, reason) = dummy1EtherSinglePolicy.verifyUserOp(callTypeSingeOp, sendMax1EtherActions);
        assertTrue(ok);
        assertEq(reason, "");
    }

    function testUserOperationCallTypeBatch() public view {
        PackedUserOperation memory callTypeBatchOp;
        callTypeBatchOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            bytes32(CallType.unwrap(CALLTYPE_BATCH)),
            abi.encode(executionsLessThan1Eth)
        );

        (bool ok, string memory reason) =
            dummyAdminPolicy.verifyUserOp(callTypeBatchOp, nullActions);
        assertTrue(ok);
        assertEq(reason, "");
        (ok, reason) = dummy5EtherBatchPolicy.verifyUserOp(callTypeBatchOp, sendMax5EtherActions);
        assertTrue(ok);
        assertEq(reason, "");
        (ok, reason) = dummy1EtherSinglePolicy.verifyUserOp(callTypeBatchOp, sendMax1EtherActions);
        assertFalse(ok);
        assertEq(reason, "IAM12 callType not allowed");
    }

    function testUserOperationCallTypeStatic() public view {
        PackedUserOperation memory callTypeStaticOp;
        callTypeStaticOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector, bytes32(CallType.unwrap(CALLTYPE_STATIC)), ""
        );

        (bool ok, string memory reason) =
            dummyAdminPolicy.verifyUserOp(callTypeStaticOp, nullActions);
        assertTrue(ok);
        assertEq(reason, "");
        (ok, reason) = dummy5EtherBatchPolicy.verifyUserOp(callTypeStaticOp, sendMax5EtherActions);
        assertFalse(ok);
        assertEq(reason, "IAM12 callType not allowed");
        (ok, reason) = dummy1EtherSinglePolicy.verifyUserOp(callTypeStaticOp, sendMax1EtherActions);
        assertFalse(ok);
        assertEq(reason, "IAM12 callType not allowed");
    }

    function testUserOperationCallTypeDelegate() public view {
        PackedUserOperation memory callTypeDelegateOp;
        callTypeDelegateOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector, bytes32(CallType.unwrap(CALLTYPE_DELEGATECALL)), ""
        );

        (bool ok, string memory reason) =
            dummyAdminPolicy.verifyUserOp(callTypeDelegateOp, nullActions);
        assertTrue(ok);
        assertEq(reason, "");
        (ok, reason) = dummy5EtherBatchPolicy.verifyUserOp(callTypeDelegateOp, sendMax5EtherActions);
        assertFalse(ok);
        assertEq(reason, "IAM12 callType not allowed");
        (ok, reason) =
            dummy1EtherSinglePolicy.verifyUserOp(callTypeDelegateOp, sendMax1EtherActions);
        assertFalse(ok);
        assertEq(reason, "IAM12 callType not allowed");
    }

    function testUserOperationExecutionCallDataSingleFail() public view {
        PackedUserOperation memory callTypeSingeOp;
        callTypeSingeOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            bytes32(CallType.unwrap(CALLTYPE_SINGLE)),
            abi.encodePacked(address(0), uint256(2 ether), "")
        );

        (bool ok, string memory reason) =
            dummyAdminPolicy.verifyUserOp(callTypeSingeOp, nullActions);
        assertTrue(ok);
        assertEq(reason, "");
        (ok, reason) = dummy5EtherBatchPolicy.verifyUserOp(callTypeSingeOp, sendMax5EtherActions);
        assertTrue(ok);
        assertEq(reason, "");
        (ok, reason) = dummy1EtherSinglePolicy.verifyUserOp(callTypeSingeOp, sendMax1EtherActions);
        assertFalse(ok);
        assertEq(reason, "IAM13 execution not allowed");
    }

    function testUserOperationExecutionCallDataBatchFail() public view {
        PackedUserOperation memory callTypeBatchOp;
        callTypeBatchOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            bytes32(CallType.unwrap(CALLTYPE_BATCH)),
            abi.encode(executionsLessThan10Eth)
        );

        (bool ok, string memory reason) =
            dummyAdminPolicy.verifyUserOp(callTypeBatchOp, nullActions);
        assertTrue(ok);
        assertEq(reason, "");
        (ok, reason) = dummy5EtherBatchPolicy.verifyUserOp(callTypeBatchOp, sendMax5EtherActions);
        assertFalse(ok);
        assertEq(reason, "IAM13 execution not allowed");
        (ok, reason) = dummy1EtherSinglePolicy.verifyUserOp(callTypeBatchOp, sendMax1EtherActions);
        assertFalse(ok);
        assertEq(reason, "IAM12 callType not allowed");
    }

    function testVerifyERC1271Sender() public view {
        assertTrue(dummyAdminPolicy.verifyERC1271Caller(address(0)));
        assertFalse(dummy1EtherSinglePolicy.verifyERC1271Caller(address(0)));
    }
}
