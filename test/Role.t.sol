// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator } from "src/IAMValidator.sol";

contract RoleTest is TestHelper {
    function testAddRoleWritesToState() public {
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMValidator.addRole.selector, type(uint120).max, type(uint120).max
            )
        );

        assertTrue(validator.hasRole(address(instance.account), type(uint240).max));
    }

    function testAddRoleEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit RoleAdded(address(this), type(uint240).max);
        validator.addRole(type(uint120).max, type(uint120).max);
    }

    function testRemoveRoleWritesToState() public {
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMValidator.addRole.selector, type(uint120).max, type(uint120).max
            )
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.removeRole.selector, type(uint240).max)
        );
        assertFalse(validator.hasRole(address(instance.account), type(uint240).max));
    }

    function testRemoveRoleEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit RoleRemoved(address(this), type(uint240).max);
        validator.removeRole(type(uint240).max);
    }
}
