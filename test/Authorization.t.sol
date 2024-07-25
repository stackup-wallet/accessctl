// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator } from "src/IAMValidator.sol";
import { Policy } from "src/Policy.sol";

contract AuthorizationTest is TestHelper {
    function testAddPolicyWritesToState() public {
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addPolicy.selector, testNullPolicy1)
        );

        assertTrue(validator.hasPolicy(address(instance.account), 1));
    }

    function testAddPolicyEmitsEvent() public {
        uint120 expectedPolicyId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit PolicyAdded(address(this), expectedPolicyId, testNullPolicy1);
        validator.addPolicy(testNullPolicy1);
    }

    function testRemovePolicyEmitsEvent() public {
        uint120 expectedPolicyId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit PolicyRemoved(address(this), expectedPolicyId);
        validator.removePolicy(expectedPolicyId);
    }
}
