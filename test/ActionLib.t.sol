// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { Action, ActionLib } from "src/Action.sol";

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
}
