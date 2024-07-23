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

    uint256 constant testP256PrivateKeyRoot =
        0x9b6949ce4e9f7958797d91a4a51a96e9361b94451b88791d8784d8331b46c32d;
    uint256 constant testP256PublicKeyXRoot =
        0xf24b7cd0e0d84317f2fbba39add412ddd3df7cb84be213b67fb340373e9275ec;
    uint256 constant testP256PublicKeyYRoot =
        0x255417d4c6780a9db69e2023685c95a344f3e59e930e758f3829b0b10bf87ebc;
    uint24 constant rootSignerId = 0;

    uint256 constant testP256PrivateKey1 =
        0x605e0a63a358c3060f9ea4b3ee7737f21e4dc49755f90ae4ad12ffcbe71a26ef;
    uint256 constant testP256PubKeyX1 =
        0x1b0f2d89ae560071a013a47d440532c606cc7753dc38e95760895f5822de97a9;
    uint256 constant testP256PubKeyY1 =
        0xe4d714fa24d1f9d2173a18f627d73ea17307ad285bf08823bdd9bc89ff4fa3c6;

    uint256 constant testP256PrivateKey2 =
        0x982642594965c2f0998a0db98748ff267995965605a3902c11a96d304305d727;
    uint256 constant testP256PubKeyX2 =
        0xbe5627cf6a968b258bbf73c0c180dbd1f657c9852b9494fee2a56d8c2021db17;
    uint256 constant testP256PubKeyY2 =
        0x6f8ced2c10424a460bbec2099ed6688ee8d4ad9df325be516917bafcb21fe55a;

    function setUp() public {
        init();

        // Create the validator
        validator = new IAMValidator();
        vm.label(address(validator), "IAMValidator");

        // Create the account and install the validator
        instance = makeAccountInstance("MainAccount");
        vm.deal(address(instance.account), 10 ether);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(testP256PublicKeyXRoot, testP256PublicKeyYRoot)
        });
    }

    function _execOpsWithValidator(bytes memory data) public {
        UserOpData memory userOpData = instance.getExecOps({
            target: address(0),
            value: 0,
            callData: data,
            txValidator: address(validator)
        });
        (bytes32 r, bytes32 s) = vm.signP256(testP256PrivateKeyRoot, userOpData.userOpHash);
        userOpData.userOp.signature = abi.encode(rootSignerId, uint256(r), uint256(s));
        userOpData.execUserOps();
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
        (bytes32 r, bytes32 s) = vm.signP256(testP256PrivateKeyRoot, userOpData.userOpHash);
        userOpData.userOp.signature = abi.encode(rootSignerId, uint256(r), uint256(s));

        // Execute the UserOp
        userOpData.execUserOps();

        // Check if the balance of the target has increased
        assertEq(target.balance, prevBalance + value);
    }

    function testAddSignerWritesToState() public {
        uint24 expectedSignerId = rootSignerId + 1;
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, 0);
        assertEqUint(s.y, 0);

        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX1, testP256PubKeyY1
            )
        });

        s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, testP256PubKeyX1);
        assertEqUint(s.y, testP256PubKeyY1);
    }

    function testAddSignerEmitsEvent() public {
        uint24 expectedSignerId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId, testP256PubKeyX1, testP256PubKeyY1);
        validator.addSigner(testP256PubKeyX1, testP256PubKeyY1);

        uint24 expectedSignerId1 = 1;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId1, testP256PubKeyX2, testP256PubKeyY2);
        validator.addSigner(testP256PubKeyX2, testP256PubKeyY2);
    }

    function testRemoveSignerWritesToState() public {
        uint24 expectedSignerId = rootSignerId + 1;
        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX1, testP256PubKeyY1
            )
        });

        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(IAMValidator.removeSigner.selector, expectedSignerId)
        });
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, 0);
        assertEqUint(s.y, 0);
    }

    function testRemoveSignerEmitsEvent() public {
        uint24 expectedSignerId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerRemoved(address(this), expectedSignerId);
        validator.removeSigner(expectedSignerId);
    }

    function testVerify() public {
        bytes32 hash = 0x3a34e26c4380493f710261d1535694f66f9de5d2da2dddc60fce50aa7b702f81;
        (bytes32 r, bytes32 s) = vm.signP256(testP256PrivateKey1, hash);
        bool valid =
            SCL_RIP7212.verify(hash, uint256(r), uint256(s), testP256PubKeyX1, testP256PubKeyY1);
        assertTrue(valid);

        (r, s) = vm.signP256(testP256PrivateKey2, hash);
        valid = SCL_RIP7212.verify(hash, uint256(r), uint256(s), testP256PubKeyX2, testP256PubKeyY2);
        assertTrue(valid);
    }

    function testReinstallResetsState() public {
        _execOpsWithValidator(
            abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX1, testP256PubKeyY1
            )
        );
        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX2, testP256PubKeyY2
            )
        });
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });
        Signer memory sRoot = validator.getSigner(address(instance.account), rootSignerId);
        Signer memory s1 = validator.getSigner(address(instance.account), rootSignerId + 1);
        Signer memory s2 = validator.getSigner(address(instance.account), rootSignerId + 2);
        assertEqUint(sRoot.x, 0);
        assertEqUint(sRoot.y, 0);
        assertEqUint(s1.x, 0);
        assertEqUint(s1.y, 0);
        assertEqUint(s2.x, 0);
        assertEqUint(s2.y, 0);

        // add root (should have failed since not installed...)
        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PublicKeyXRoot, testP256PublicKeyYRoot
            )
        });

        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX1, testP256PubKeyY1
            )
        });
        instance.exec({
            target: address(validator),
            callData: abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX2, testP256PubKeyY2
            )
        });

        sRoot = validator.getSigner(address(instance.account), rootSignerId);
        s1 = validator.getSigner(address(instance.account), rootSignerId + 1);
        s2 = validator.getSigner(address(instance.account), rootSignerId + 2);
        assertEqUint(sRoot.x, testP256PublicKeyXRoot);
        assertEqUint(sRoot.y, testP256PublicKeyYRoot);
        assertEqUint(s1.x, testP256PubKeyX1);
        assertEqUint(s1.y, testP256PubKeyY1);
        assertEqUint(s2.x, testP256PubKeyX2);
        assertEqUint(s2.y, testP256PubKeyY2);
    }
}
