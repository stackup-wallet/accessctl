// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator } from "src/IAMValidator.sol";
import { Policy, ADMIN_MODE } from "src/Policy.sol";
import { PolicyLib } from "src/PolicyLib.sol";

contract AuthorizationTest is TestHelper {
    using PolicyLib for Policy;

    function testAddPolicyWritesToState() public {
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addPolicy.selector, testAdminPolicy)
        );

        Policy memory p = validator.getPolicy(address(instance.account), 0);
        assertEq(p.mode, ADMIN_MODE);
    }

    function testAddPolicyEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit PolicyAdded(address(this), adminPolicyId, testAdminPolicy);
        validator.addPolicy(testAdminPolicy);
    }

    function testRemovePolicyWritesToState() public {
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addPolicy.selector, testAdminPolicy)
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.removePolicy.selector, adminPolicyId)
        );
        assertTrue(validator.getPolicy(address(instance.account), adminPolicyId).isNull());
    }

    function testRemovePolicyEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit PolicyRemoved(address(this), adminPolicyId);
        validator.removePolicy(adminPolicyId);
    }
}
