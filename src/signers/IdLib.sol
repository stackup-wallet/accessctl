// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { PermissionId, SignerId, HashedPermissionAndSignerIds } from "src/signers/DataTypes.sol";
import { P256PublicKey } from "src/signers/P256PublicKey.sol";

library IdLib {
    function getSignerId(P256PublicKey memory signer) internal pure returns (SignerId sid) {
        sid = SignerId.wrap(keccak256(abi.encode(signer.x, signer.y)));
    }

    function getHashedPermissionAndSignerIds(
        PermissionId pid,
        SignerId sid
    )
        internal
        pure
        returns (HashedPermissionAndSignerIds hash)
    {
        hash = HashedPermissionAndSignerIds.wrap(keccak256(abi.encode(pid, sid)));
    }
}
