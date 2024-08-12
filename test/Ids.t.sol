// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { AccessCtl } from "src/AccessCtl.sol";
import { Signer } from "src/Signer.sol";
import { Policy } from "src/Policy.sol";
import { Action } from "src/Action.sol";

contract IdsTest is TestHelper {
    function testGetNextIdsReturnsTheCorrectValues() public {
        (uint112 signerId, uint112 policyId, uint24 actionId) =
            module.getNextIds(address(instance.account));
        assertEq(signerId, rootSignerId + 1);
        assertEq(policyId, rootPolicyId + 1);
        assertEq(actionId, rootActionId + 1);

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(AccessCtl.addWebAuthnSigner.selector, dummySigner1)
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(AccessCtl.addPolicy.selector, dummy1EtherSinglePolicy)
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(AccessCtl.addAction.selector, dummySendMax1EtherAction)
        );

        (signerId, policyId, actionId) = module.getNextIds(address(instance.account));
        assertEq(signerId, rootSignerId + 2);
        assertEq(policyId, rootPolicyId + 2);
        assertEq(actionId, rootActionId + 2);
    }

    function testIdsOnlyGoUp() public {
        // Add entities
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(AccessCtl.addWebAuthnSigner.selector, dummySigner1)
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(AccessCtl.addPolicy.selector, dummy1EtherSinglePolicy)
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(AccessCtl.addAction.selector, dummySendMax1EtherAction)
        );

        // Remove entities
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(AccessCtl.removeSigner.selector, rootSignerId + 1)
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(AccessCtl.removePolicy.selector, rootPolicyId + 1)
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(AccessCtl.removeAction.selector, rootActionId + 1)
        );

        // Assert next ids will still go up
        (uint112 signerId, uint112 policyId, uint48 actionId) =
            module.getNextIds(address(instance.account));
        assertEq(signerId, rootSignerId + 2);
        assertEq(policyId, rootPolicyId + 2);
        assertEq(actionId, rootActionId + 2);
    }
}
