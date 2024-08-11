// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMModule } from "src/IAMModule.sol";
import { Policy, PolicyLib, MODE_ADMIN } from "src/Policy.sol";
import { Action, ActionLib } from "src/Action.sol";

contract AuthorizationTest is TestHelper {
    using PolicyLib for Policy;
    using ActionLib for Action;

    function testAdminPolicyExists() public view {
        assertTrue(
            module.getPolicy(address(instance.account), rootPolicyId).isEqual(dummyAdminPolicy)
        );
    }

    function testAddPolicyWritesToState() public {
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addPolicy.selector, dummy1EtherSinglePolicy)
        );

        assertTrue(
            module.getPolicy(address(instance.account), rootPolicyId + 1).isEqual(
                dummy1EtherSinglePolicy
            )
        );
    }

    function testAddPolicyEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(module));
        emit PolicyAdded(address(this), rootPolicyId, dummy1EtherSinglePolicy);
        module.addPolicy(dummy1EtherSinglePolicy);
    }

    function testRemovePolicyWritesToState() public {
        uint112 expectedPolicyId = rootPolicyId + 1;
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addPolicy.selector, dummy1EtherSinglePolicy)
        );

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.removePolicy.selector, expectedPolicyId)
        );
        assertTrue(module.getPolicy(address(instance.account), expectedPolicyId).isNull());
    }

    function testRemovePolicyEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(module));
        emit PolicyRemoved(address(this), rootPolicyId);
        module.removePolicy(rootPolicyId);
    }

    function testPolicyCanHaveNoActions() public view {
        Action[] memory dummyAdminPolicyActions = module.getActions(
            address(instance.account),
            module.getPolicy(address(instance.account), rootPolicyId).allowActions
        );

        assertTrue(dummyAdminPolicyActions[0].isNull());
        assertTrue(dummyAdminPolicyActions[1].isNull());
        assertTrue(dummyAdminPolicyActions[2].isNull());
        assertTrue(dummyAdminPolicyActions[3].isNull());
        assertTrue(dummyAdminPolicyActions[4].isNull());
        assertTrue(dummyAdminPolicyActions[5].isNull());
        assertTrue(dummyAdminPolicyActions[6].isNull());
        assertTrue(dummyAdminPolicyActions[7].isNull());
    }

    function testPolicyCanHaveMaxEightActions() public {
        Action[8] memory expectedActions;
        for (uint256 i = 0; i < expectedActions.length; i++) {
            expectedActions[i].payableValue = type(uint256).max - i;
            _execUserOp(
                address(module),
                0,
                abi.encodeWithSelector(IAMModule.addAction.selector, expectedActions[i])
            );
        }
        Policy memory policy;
        policy.allowActions = (uint192(rootActionId + 1) << 24 * 0)
            | (uint192(rootActionId + 2) << 24 * 1) | (uint192(rootActionId + 3) << 24 * 2)
            | (uint192(rootActionId + 4) << 24 * 3) | (uint192(rootActionId + 5) << 24 * 4)
            | (uint192(rootActionId + 6) << 24 * 5) | (uint192(rootActionId + 7) << 24 * 6)
            | (uint192(rootActionId + 8) << 24 * 7);
        _execUserOp(
            address(module), 0, abi.encodeWithSelector(IAMModule.addPolicy.selector, policy)
        );

        Action[] memory actualActions = module.getActions(
            address(instance.account),
            module.getPolicy(address(instance.account), rootPolicyId + 1).allowActions
        );

        assertEq(expectedActions.length, actualActions.length);
        for (uint256 i = 0; i < actualActions.length; i++) {
            assertTrue(actualActions[i].isEqual(expectedActions[i]));
        }
    }
}
