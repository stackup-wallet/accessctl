// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMModule } from "src/IAMModule.sol";
import { Action, ActionLib } from "src/Action.sol";

contract ActionTest is TestHelper {
    using ActionLib for Action;

    function testRootActionIsNull() public view {
        assertTrue(module.getAction(address(instance.account), rootActionId).isNull());
    }

    function testAddActionWritesToState() public {
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addAction.selector, dummySendMax1EtherAction)
        );
        assertTrue(
            module.getAction(address(instance.account), rootActionId + 1).isEqual(
                dummySendMax1EtherAction
            )
        );

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addAction.selector, dummySendMax5EtherAction)
        );
        assertTrue(
            module.getAction(address(instance.account), rootActionId + 2).isEqual(
                dummySendMax5EtherAction
            )
        );
    }

    function testAddActionEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(module));
        emit ActionAdded(address(this), rootActionId, dummySendMax1EtherAction);
        module.addAction(dummySendMax1EtherAction);

        vm.expectEmit(true, true, true, true, address(module));
        emit ActionAdded(address(this), rootActionId + 1, dummySendMax5EtherAction);
        module.addAction(dummySendMax5EtherAction);
    }

    function testRemoveActionWritesToState() public {
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addAction.selector, dummySendMax1EtherAction)
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addAction.selector, dummySendMax5EtherAction)
        );

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.removeAction.selector, rootActionId)
        );
        assertTrue(module.getAction(address(instance.account), rootActionId).isNull());

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.removeAction.selector, rootActionId + 1)
        );
        assertTrue(module.getAction(address(instance.account), rootActionId + 1).isNull());
    }

    function testRemoveActionEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(module));
        emit ActionRemoved(address(this), rootActionId);
        module.removeAction(rootActionId);

        vm.expectEmit(true, true, true, true, address(module));
        emit ActionRemoved(address(this), rootActionId + 1);
        module.removeAction(rootActionId + 1);
    }
}
