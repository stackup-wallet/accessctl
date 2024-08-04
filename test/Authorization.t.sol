// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMModule } from "src/IAMModule.sol";
import { Policy, PolicyLib, MODE_ADMIN } from "src/Policy.sol";

contract AuthorizationTest is TestHelper {
    using PolicyLib for Policy;

    function testAdminPolicyExists() public view {
        assertTrue(
            validator.getPolicy(address(instance.account), rootPolicyId).isEqual(dummyAdminPolicy)
        );
    }

    function testAddPolicyWritesToState() public {
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMModule.addPolicy.selector, dummy1EtherPolicy)
        );

        assertTrue(
            validator.getPolicy(address(instance.account), rootPolicyId + 1).isEqual(
                dummy1EtherPolicy
            )
        );
    }

    function testAddPolicyEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit PolicyAdded(address(this), rootPolicyId, dummy1EtherPolicy);
        validator.addPolicy(dummy1EtherPolicy);
    }

    function testRemovePolicyWritesToState() public {
        uint112 expectedPolicyId = rootPolicyId + 1;
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMModule.addPolicy.selector, dummy1EtherPolicy)
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMModule.removePolicy.selector, expectedPolicyId)
        );
        assertTrue(validator.getPolicy(address(instance.account), expectedPolicyId).isNull());
    }

    function testRemovePolicyEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit PolicyRemoved(address(this), rootPolicyId);
        validator.removePolicy(rootPolicyId);
    }
}
