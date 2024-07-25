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
            abi.encodeWithSelector(IAMValidator.addPolicy.selector, testNullPolicy)
        );

        assertTrue(validator.hasPolicy(address(instance.account)));
    }

    function testAddPolicyEmitsEvent() public {
        uint120 expectedPolicyId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit PolicyAdded(address(this), expectedPolicyId, testNullPolicy);
        validator.addPolicy(testNullPolicy);
    }
}
