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

    function testERC1271ValidSignature() public virtual {
        bytes32 hash = keccak256("0xdead");
        (bytes32 r, bytes32 s) = vm.signP256(testP256PrivateKeyRoot, hash);
        bytes memory signature = abi.encode(rootSignerId, uint256(r), uint256(s));

        bool valid = _verifyEIP1271Signature(address(validator), hash, signature);

        assertTrue(valid);
    }

    function testERC1271InValidSignature() public virtual {
        bytes32 hash = keccak256("0xdead");
        (bytes32 r, bytes32 s) = vm.signP256(testP256PrivateKey2, hash);
        bytes memory signature = abi.encode(rootSignerId, uint256(r), uint256(s));

        bool valid = _verifyEIP1271Signature(address(validator), hash, signature);

        assertFalse(valid);
    }
}
