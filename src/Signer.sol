// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/**
 * A data structure for storing the X and Y co-ordinates of a P256 public key.
 */
struct Signer {
    uint256 x;
    uint256 y;
}
