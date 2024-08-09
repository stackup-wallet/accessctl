// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import {
    Action,
    ActionLib,
    OPERATOR_EQ,
    OPERATOR_GT,
    OPERATOR_GTE,
    OPERATOR_LT,
    OPERATOR_LTE
} from "src/Action.sol";

contract ActionLibTest is TestHelper {
    using ActionLib for Action;

    function testIsEqual() public view {
        assertTrue(dummySendMax1EtherAction.isEqual(dummySendMax1EtherAction));
        assertFalse(dummySendMax1EtherAction.isEqual(dummySendMax5EtherAction));
    }

    function testisNull() public view {
        Action memory testNullAction;
        assertTrue(testNullAction.isNull());
        assertFalse(dummySendMax1EtherAction.isNull());
    }

    function testVerifyCallPayableValueEQ() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_EQ;

        assertTrue(action.verifyCall(address(0), 1 ether, ""));
        assertFalse(action.verifyCall(address(0), 0.5 ether, ""));
        assertFalse(action.verifyCall(address(0), 2 ether, ""));
    }

    function testVerifyCallPayableValueGT() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_GT;

        assertFalse(action.verifyCall(address(0), 1 ether, ""));
        assertFalse(action.verifyCall(address(0), 0.5 ether, ""));
        assertTrue(action.verifyCall(address(0), 2 ether, ""));
    }

    function testVerifyCallPayableValueGTE() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_GTE;

        assertTrue(action.verifyCall(address(0), 1 ether, ""));
        assertFalse(action.verifyCall(address(0), 0.5 ether, ""));
        assertTrue(action.verifyCall(address(0), 2 ether, ""));
    }

    function testVerifyCallPayableValueLT() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_LT;

        assertFalse(action.verifyCall(address(0), 1 ether, ""));
        assertTrue(action.verifyCall(address(0), 0.5 ether, ""));
        assertFalse(action.verifyCall(address(0), 2 ether, ""));
    }

    function testVerifyCallPayableValueLTE() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_LTE;

        assertTrue(action.verifyCall(address(0), 1 ether, ""));
        assertTrue(action.verifyCall(address(0), 0.5 ether, ""));
        assertFalse(action.verifyCall(address(0), 2 ether, ""));
    }
}
