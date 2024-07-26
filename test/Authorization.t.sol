// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator } from "src/IAMValidator.sol";
import { Policy } from "src/Policy.sol";

contract AuthorizationTest is TestHelper {
    function testAddPolicyWritesToState() public {
        uint8 expectedAdminModes = 0x01;
        uint8 expectedNonAdminModes = 0x02;
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addPolicy.selector, testAdminPolicy)
        );

        Policy memory p = validator.getPolicy(address(instance.account), 0);
        assertEqUint(uint8(p.adminModes), expectedAdminModes);

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addPolicy.selector, testNonAdminPolicy)
        );

        p = validator.getPolicy(address(instance.account), 1);
        assertEqUint(uint8(p.adminModes), expectedNonAdminModes);
    }

    function testAddPolicyEmitsEvent() public {
        uint120 expectedPolicyId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit PolicyAdded(address(this), expectedPolicyId, testAdminPolicy);
        validator.addPolicy(0);
    }

    function testRemovePolicyWritesToState() public {
        uint120 expectedPolicyId = 0;
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.addPolicy.selector, testAdminPolicy)
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.removePolicy.selector, expectedPolicyId)
        );

        assertTrue(_isZeroPolicy(validator.getPolicy(address(instance.account), 0)));
    }

    function testRemovePolicyEmitsEvent() public {
        uint120 expectedPolicyId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit PolicyRemoved(address(this), expectedPolicyId);
        validator.removePolicy(0);
    }

    function testAddRoleWritesToState() public {
        _execUserOp(address(validator), 0, abi.encodeWithSelector(IAMValidator.addRole.selector, 1));

        assertTrue(validator.hasRole(address(instance.account), 1));
    }

    function testAddRoleEmitsEvent() public {
        uint240 expectedRoleId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit RoleAdded(address(this), expectedRoleId);
        validator.addRole(0);
    }

    function testRemoveRoleWritesToState() public {
        _execUserOp(
            address(validator), 0, abi.encodeWithSelector(IAMValidator.removeRole.selector, 1)
        );

        assertFalse(validator.hasRole(address(instance.account), 1));
    }

    function testRemoveRoleEmitsEvent() public {
        uint240 expectedRoleId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit RoleRemoved(address(this), expectedRoleId);
        validator.removeRole(expectedRoleId);
    }
}
