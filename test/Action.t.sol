// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator } from "src/IAMValidator.sol";
import { Action, ActionLib } from "src/Action.sol";

contract ActionTest is TestHelper {
    using ActionLib for Action;

    function testRootActionIsNull() public view {
        assertTrue(validator.getAction(address(instance.account), rootActionId).isNull());
    }

    function testAddActionWritesToState() public {
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addAction.selector, dummySendMax1EtherAction)
        );
        assertTrue(
            validator.getAction(address(instance.account), rootActionId + 1).isEqual(
                dummySendMax1EtherAction
            )
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addAction.selector, dummySendMax5EtherAction)
        );
        assertTrue(
            validator.getAction(address(instance.account), rootActionId + 2).isEqual(
                dummySendMax5EtherAction
            )
        );
    }

    function testAddActionEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit ActionAdded(address(this), rootActionId, dummySendMax1EtherAction);
        validator.addAction(dummySendMax1EtherAction);

        vm.expectEmit(true, true, true, true, address(validator));
        emit ActionAdded(address(this), rootActionId + 1, dummySendMax5EtherAction);
        validator.addAction(dummySendMax5EtherAction);
    }

    function testRemoveActionWritesToState() public {
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addAction.selector, dummySendMax1EtherAction)
        );
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addAction.selector, dummySendMax5EtherAction)
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.removeAction.selector, rootActionId)
        );
        assertTrue(validator.getAction(address(instance.account), rootActionId).isNull());

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.removeAction.selector, rootActionId + 1)
        );
        assertTrue(validator.getAction(address(instance.account), rootActionId + 1).isNull());
    }

    function testRemoveActionEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit ActionRemoved(address(this), rootActionId);
        validator.removeAction(rootActionId);

        vm.expectEmit(true, true, true, true, address(validator));
        emit ActionRemoved(address(this), rootActionId + 1);
        validator.removeAction(rootActionId + 1);
    }
}
