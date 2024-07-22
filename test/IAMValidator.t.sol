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
import "forge-std/console.sol";
import { SCL_RIP7212 } from "crypto-lib/lib/libSCL_RIP7212.sol";

contract IAMValidatorTest is RhinestoneModuleKit, Test {
    event SignerAdded(address indexed account, uint24 indexed signerId, uint256 x, uint256 y);
    event SignerRemoved(address indexed account, uint24 indexed signerId);

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

    function testRemoveSignerWritesToState() public {
        uint24 expectedSignerId = 0;
        uint256 expectedPubKeyX = 1;
        uint256 expectedPubKeyY = 2;
        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.addSigner.selector, expectedPubKeyX, expectedPubKeyY
            )
        });
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, expectedPubKeyX);
        assertEqUint(s.y, expectedPubKeyY);

        uint256 expectedPubKeyX1 = 0;
        uint256 expectedPubKeyY1 = 0;
        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(IAMValidator.removeSigner.selector, expectedSignerId)
        });
        s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, expectedPubKeyX1);
        assertEqUint(s.y, expectedPubKeyY1);
    }

    function testRemoveSignerEmitsEvent() public {
        uint24 expectedSignerId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerRemoved(address(this), expectedSignerId);
        validator.removeSigner(expectedSignerId);
    }

    function testVerify() public {
        uint256 pk = 0x605e0a63a358c3060f9ea4b3ee7737f21e4dc49755f90ae4ad12ffcbe71a26ef;
        bytes32 hash = 0x3a34e26c4380493f710261d1535694f66f9de5d2da2dddc60fce50aa7b702f81;
        uint256 x = 0x1b0f2d89ae560071a013a47d440532c606cc7753dc38e95760895f5822de97a9;
        uint256 y = 0xe4d714fa24d1f9d2173a18f627d73ea17307ad285bf08823bdd9bc89ff4fa3c6;

        (bytes32 r, bytes32 s) = vm.signP256(pk, hash);
        console.logBytes32(r);
        console.logBytes32(s);
        console.logUint(x);
        console.logUint(y);

        bool valid = SCL_RIP7212.verify(hash, uint256(r), uint256(s), x, y);
        assertTrue(valid);
    }
}
