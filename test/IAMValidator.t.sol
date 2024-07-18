// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { IAMValidator } from "src/IAMValidator.sol";

contract IAMValidatorTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    IAMValidator internal validator;

    function setUp() public {
        init();

        // Create the validator
        validator = new IAMValidator();
        vm.label(address(validator), "IAMValidator");

        // Create the account and install the validator
        instance = makeAccountInstance("IAMValidator");
        vm.deal(address(instance.account), 10 ether);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });
    }

    function testExec() public {
        // Create a target address and send some ether to it
        address target = makeAddr("target");
        uint256 value = 1 ether;

        // Get the current balance of the target
        uint256 prevBalance = target.balance;

        // Get the UserOp data (UserOperation and UserOperationHash)
        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });

        // Set the signature
        bytes memory signature = hex"414141";
        userOpData.userOp.signature = signature;

        // Execute the UserOp
        userOpData.execUserOps();

        // Check if the balance of the target has increased
        assertEq(target.balance, prevBalance + value);
    }

    event SignerAdded(address indexed account, bytes3 indexed signerId, uint256 x, uint256 y);

    function testAddSignerThatDoesNotExist() public {
        (uint256 x1, uint256 y1) = validator.SignerRegister(bytes4(0), address(instance.account));
        assertEq(x1, 0);
        assertEq(y1, 0);

        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(IAMValidator.addSigner.selector, uint256(1), uint256(3))
        });

        (uint256 x2, uint256 y2) = validator.SignerRegister(bytes4(0), address(instance.account));

        assertEq(x2, 1);
        assertEq(y2, 3);
    }
}
