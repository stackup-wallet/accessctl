// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ISessionValidator } from "smart-sessions/interfaces/ISessionValidator.sol";
import { P256PublicKey, P256PublicKeyLib } from "src/signers/P256PublicKey.sol";
import { PermissionId, SignerId, HashedPermissionAndSignerIds } from "src/signers/DataTypes.sol";
import { IdLib } from "src/signers/IdLib.sol";

contract WebAuthnGroups is ISessionValidator {
    using P256PublicKeyLib for P256PublicKey;

    error SignerDoesNotExistInSession(address account, PermissionId pid, SignerId sid);

    event SignerAddedToSession(address indexed account, PermissionId pid, SignerId sid);
    event SignerRemovedFromSession(address indexed account, PermissionId pid, SignerId sid);

    mapping(HashedPermissionAndSignerIds hash => mapping(address account => P256PublicKey signer))
        internal signers;

    function validateSignatureWithData(
        bytes32 hash,
        bytes calldata sig,
        bytes calldata data
    )
        external
        view
        returns (bool validSig)
    {
        (SignerId sid, bytes memory packedSig) = _unpackSignerIdAndSignature(sig);
        (PermissionId pid) = abi.decode(data, (PermissionId));
        P256PublicKey memory signer =
            signers[IdLib.getHashedPermissionAndSignerIds(pid, sid)][msg.sender];
        if (signer.isNull()) {
            revert SignerDoesNotExistInSession(msg.sender, pid, sid);
        }

        return signer.verifyWebAuthnSignature(hash, packedSig);
    }

    function addSigner(PermissionId pid, P256PublicKey calldata signer) external {
        SignerId sid = IdLib.getSignerId(signer);
        signers[IdLib.getHashedPermissionAndSignerIds(pid, sid)][msg.sender] = signer;

        emit SignerAddedToSession(msg.sender, pid, sid);
    }

    function removeSigner(PermissionId pid, SignerId sid) external {
        delete signers[IdLib.getHashedPermissionAndSignerIds(pid, sid)][msg.sender];

        emit SignerRemovedFromSession(msg.sender, pid, sid);
    }

    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return interfaceID == WebAuthnGroups.validateSignatureWithData.selector;
    }

    function _unpackSignerIdAndSignature(
        bytes calldata sig
    )
        internal
        pure
        returns (SignerId sid, bytes memory packedSig)
    {
        sid = SignerId.wrap(bytes32(sig[:32]));
        packedSig = sig[32:];
    }
}
