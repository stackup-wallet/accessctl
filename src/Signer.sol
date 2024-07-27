// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/**
 * A data structure for storing the X and Y co-ordinates of a P256 public key.
 */
struct Signer {
    uint256 x;
    uint256 y;
}

library SignerLib {
    function isEqual(Signer calldata s, Signer memory t) public pure returns (bool) {
        return s.x == t.x && s.y == t.y;
    }

    function isNull(Signer calldata s) public pure returns (bool) {
        return s.x == 0 && s.y == 0;
    }
}
