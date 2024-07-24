// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator } from "src/IAMValidator.sol";
import { Signer } from "src/Signer.sol";

contract AuthenticationTest is TestHelper {
    function testAddSignerWritesToState() public {
        uint120 expectedSignerId = rootSignerId + 1;
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, 0);
        assertEqUint(s.y, 0);

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX1, testP256PubKeyY1
            )
        );

        s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, testP256PubKeyX1);
        assertEqUint(s.y, testP256PubKeyY1);
    }

    function testAddSignerEmitsEvent() public {
        uint120 expectedSignerId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId, testP256PubKeyX1, testP256PubKeyY1);
        validator.addSigner(testP256PubKeyX1, testP256PubKeyY1);

        uint120 expectedSignerId1 = 1;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId1, testP256PubKeyX2, testP256PubKeyY2);
        validator.addSigner(testP256PubKeyX2, testP256PubKeyY2);
    }

    function testRemoveSignerWritesToState() public {
        uint120 expectedSignerId = rootSignerId + 1;
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX1, testP256PubKeyY1
            )
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.removeSigner.selector, expectedSignerId)
        );
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, 0);
        assertEqUint(s.y, 0);
    }

    function testRemoveSignerEmitsEvent() public {
        uint120 expectedSignerId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerRemoved(address(this), expectedSignerId);
        validator.removeSigner(expectedSignerId);
    }

    function testValidSig() public virtual {
        bytes32 message = hex"dead";
        (bytes32 r, bytes32 s) = vm.signP256(testP256PrivateKeyRoot, message);
        bytes memory signature = abi.encode(rootSignerId, uint256(r), uint256(s));

        bool valid = _verifyEIP1271Signature(address(validator), message, signature);

        assertTrue(valid);
    }

    function testInValidSig() public virtual {
        uint24 invalidSignerId = 3;
        bytes32 message = bytes32(keccak256("hash"));
        (bytes32 r, bytes32 s) = vm.signP256(testP256PubKeyX1, message);
        bytes memory signature = abi.encode(invalidSignerId, uint256(r), uint256(s));

        bool valid = _verifyEIP1271Signature(address(validator), message, signature);

        assertFalse(valid);
    }
}
