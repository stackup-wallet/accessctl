// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMModule } from "src/IAMModule.sol";

contract RoleTest is TestHelper {
    function testRootSignerWithAdminPolicyRoleExists() public view {
        assertTrue(module.hasRole(address(instance.account), rootRoleId));
    }

    function testAddRoleWritesToState() public {
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addRole.selector, type(uint112).max, type(uint112).max)
        );

        assertTrue(module.hasRole(address(instance.account), type(uint224).max));
    }

    function testAddRoleEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(module));
        emit RoleAdded(address(this), type(uint224).max);
        module.addRole(type(uint112).max, type(uint112).max);
    }

    function testRemoveRoleWritesToState() public {
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addRole.selector, type(uint112).max, type(uint112).max)
        );

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.removeRole.selector, type(uint224).max)
        );
        assertFalse(module.hasRole(address(instance.account), type(uint224).max));
    }

    function testRemoveRoleEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(module));
        emit RoleRemoved(address(this), type(uint224).max);
        module.removeRole(type(uint224).max);
    }
}
