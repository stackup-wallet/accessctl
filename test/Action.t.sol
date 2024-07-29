// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator } from "src/IAMValidator.sol";
import { Action, ActionLib } from "src/Action.sol";

contract ActionTest is TestHelper {
    using ActionLib for Action;

    function testAddActionWritesToState() public {
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addAction.selector, dummySendMax1EtherAction)
        );
        assertTrue(
            validator.getAction(address(instance.account), initActionId).isEqual(
                dummySendMax1EtherAction
            )
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addAction.selector, dummySendMax5EtherAction)
        );
        assertTrue(
            validator.getAction(address(instance.account), initActionId + 1).isEqual(
                dummySendMax5EtherAction
            )
        );
    }

    function testAddActionEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit ActionAdded(address(this), initActionId, dummySendMax1EtherAction);
        validator.addAction(dummySendMax1EtherAction);

        vm.expectEmit(true, true, true, true, address(validator));
        emit ActionAdded(address(this), initActionId + 1, dummySendMax5EtherAction);
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
            abi.encodeWithSelector(IAMValidator.removeAction.selector, initActionId)
        );
        assertTrue(validator.getAction(address(instance.account), initActionId).isNull());

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.removeAction.selector, initActionId + 1)
        );
        assertTrue(validator.getAction(address(instance.account), initActionId + 1).isNull());
    }

    function testRemoveActionEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit ActionRemoved(address(this), initActionId);
        validator.removeAction(initActionId);

        vm.expectEmit(true, true, true, true, address(validator));
        emit ActionRemoved(address(this), initActionId + 1);
        validator.removeAction(initActionId + 1);
    }
}
