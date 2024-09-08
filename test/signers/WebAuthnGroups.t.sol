// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { PermissionId, SignerId } from "src/signers/DataTypes.sol";
import { IdLib } from "src/signers/IdLib.sol";
import { WebAuthnGroups } from "src/signers/WebAuthnGroups.sol";

contract WebAuthnGroupsTest is TestHelper {
    bytes32 internal constant dummyHash = bytes32(uint256(0xdead));
    bytes32 internal constant dummyBadHash = bytes32(uint256(0xbaad));
    PermissionId internal constant dummyPermissionId = PermissionId.wrap(bytes32(uint256(0xbeef)));

    event SignerAddedToSession(address indexed account, PermissionId pid, SignerId sid);
    event SignerRemovedFromSession(address indexed account, PermissionId pid, SignerId sid);

    function testRevertIfNotFoundInRole() public {
        bytes memory sig = _webAuthnSign(
            IdLib.getSignerId(dummyRootP256PublicKey), dummyP256PrivateKeyRoot, dummyHash
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                WebAuthnGroups.SignerDoesNotExistInSession.selector,
                address(this),
                dummyPermissionId,
                IdLib.getSignerId(dummyRootP256PublicKey)
            )
        );
        sessionValidator.validateSignatureWithData(dummyHash, sig, abi.encode(dummyPermissionId));
    }

    function testReturnsFalseIfBadSig() public {
        sessionValidator.addSigner(dummyPermissionId, dummyRootP256PublicKey);
        bytes memory sig = _webAuthnSign(
            IdLib.getSignerId(dummyRootP256PublicKey), dummyP256PrivateKeyRoot, dummyHash
        );

        assertFalse(
            sessionValidator.validateSignatureWithData(
                dummyBadHash, sig, abi.encode(dummyPermissionId)
            )
        );
    }

    function testReturnsTrueIfGoodSig() public {
        sessionValidator.addSigner(dummyPermissionId, dummyRootP256PublicKey);
        bytes memory sig = _webAuthnSign(
            IdLib.getSignerId(dummyRootP256PublicKey), dummyP256PrivateKeyRoot, dummyHash
        );

        assertTrue(
            sessionValidator.validateSignatureWithData(
                dummyHash, sig, abi.encode(dummyPermissionId)
            )
        );
    }

    function testRevertIfRemovedFromRole() public {
        sessionValidator.addSigner(dummyPermissionId, dummyRootP256PublicKey);
        sessionValidator.removeSigner(dummyPermissionId, IdLib.getSignerId(dummyRootP256PublicKey));
        bytes memory sig = _webAuthnSign(
            IdLib.getSignerId(dummyRootP256PublicKey), dummyP256PrivateKeyRoot, dummyHash
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                WebAuthnGroups.SignerDoesNotExistInSession.selector,
                address(this),
                dummyPermissionId,
                IdLib.getSignerId(dummyRootP256PublicKey)
            )
        );
        sessionValidator.validateSignatureWithData(dummyHash, sig, abi.encode(dummyPermissionId));
    }

    function testEmitsEventWhenSignerIsAdded() public {
        vm.expectEmit(true, true, true, true, address(sessionValidator));
        emit SignerAddedToSession(
            address(this), dummyPermissionId, IdLib.getSignerId(dummyRootP256PublicKey)
        );
        sessionValidator.addSigner(dummyPermissionId, dummyRootP256PublicKey);
    }

    function testEmitsEventWhenSignerIsRemoved() public {
        vm.expectEmit(true, true, true, true, address(sessionValidator));
        emit SignerRemovedFromSession(
            address(this), dummyPermissionId, IdLib.getSignerId(dummyRootP256PublicKey)
        );
        sessionValidator.removeSigner(dummyPermissionId, IdLib.getSignerId(dummyRootP256PublicKey));
    }
}
