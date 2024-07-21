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
import { IAMValidator, Signer } from "src/IAMValidator.sol";

contract IAMValidatorTest is RhinestoneModuleKit, Test {
    event SignerAdded(address indexed account, uint24 indexed signerId, uint256 x, uint256 y);

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

    function testAddSignerWritesToState() public {
        uint24 expectedSignerId = 0;
        uint256 expectedPubKeyX = 1;
        uint256 expectedPubKeyY = 2;
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, 0);
        assertEqUint(s.y, 0);

        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.addSigner.selector, expectedPubKeyX, expectedPubKeyY
            )
        });

        s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, expectedPubKeyX);
        assertEqUint(s.y, expectedPubKeyY);
    }

    function testAddSignerEmitsEvent() public {
        uint24 expectedSignerId = 0;
        uint256 expectedPubKeyX = 1;
        uint256 expectedPubKeyY = 2;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId, expectedPubKeyX, expectedPubKeyY);
        validator.addSigner(1, 2);

        uint24 expectedSignerId1 = 1;
        uint256 expectedPubKeyX1 = 2;
        uint256 expectedPubKeyY1 = 2;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId1, expectedPubKeyX1, expectedPubKeyY1);
        validator.addSigner(2, 2);
    }

    function testRemoveSigner() public {
        uint24 expectedSignerId = 0;
        uint256 expectedPubKeyX = 1;
        uint256 expectedPubKeyY = 2;
        // add the signer in
        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.addSigner.selector, expectedPubKeyX, expectedPubKeyY
            )
        });

        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, expectedPubKeyX);
        assertEqUint(s.y, expectedPubKeyY);

        // now Remove the signer
        uint24 expectedRemovedSignerId = 0;

        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.removeSigner.selector, expectedRemovedSignerId
            )
        });

        uint256 expectedPubKeyX1 = 0;
        uint256 expectedPubKeyY1 = 0;

        s = validator.getSigner(address(instance.account), expectedRemovedSignerId);
        assertEqUint(s.x, expectedPubKeyX1);
        assertEqUint(s.y, expectedPubKeyY1);
    }
}
