// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator } from "src/IAMValidator.sol";
import { Signer, SignerLib } from "src/Signer.sol";

contract AuthenticationTest is TestHelper {
    using SignerLib for Signer;

    function testAddSignerWritesToState() public {
        uint120 expectedSignerId = rootSignerId + 1;
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isNull());

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMValidator.addSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
            )
        );

        s = validator.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isEqual(dummySigner1));
    }

    function testAddSignerEmitsEvent() public {
        uint120 expectedSignerId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId, dummyP256PubKeyX1, dummyP256PubKeyY1);
        validator.addSigner(dummyP256PubKeyX1, dummyP256PubKeyY1);

        uint120 expectedSignerId1 = 1;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId1, dummyP256PubKeyX2, dummyP256PubKeyY2);
        validator.addSigner(dummyP256PubKeyX2, dummyP256PubKeyY2);
    }

    function testRemoveSignerWritesToState() public {
        uint120 expectedSignerId = rootSignerId + 1;
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMValidator.addSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
            )
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.removeSigner.selector, expectedSignerId)
        );
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isNull());
    }

    function testRemoveSignerEmitsEvent() public {
        uint120 expectedSignerId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerRemoved(address(this), expectedSignerId);
        validator.removeSigner(expectedSignerId);
    }

    function testERC1271ValidSignature() public {
        bytes32 rawHash = keccak256("0xdead");
        bytes32 formattedHash = _formatERC1271Hash(address(validator), rawHash);

        (bytes32 r, bytes32 s) = vm.signP256(dummyP256PrivateKeyRoot, formattedHash);
        bytes memory signature = abi.encode(rootSignerId, uint256(r), uint256(s));

        assertTrue(_verifyERC1271Signature(address(validator), rawHash, signature));
    }

    function testERC1271InvalidSignature() public {
        bytes32 rawHash = keccak256("0xdead");
        bytes32 formattedHash = _formatERC1271Hash(address(validator), rawHash);

        (bytes32 r, bytes32 s) = vm.signP256(dummyP256PrivateKey1, formattedHash);
        bytes memory signature = abi.encode(rootSignerId, uint256(r), uint256(s));

        assertFalse(_verifyERC1271Signature(address(validator), rawHash, signature));
    }
}
