// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

bytes1 constant MODE_ADMIN = 0xff;
bytes1 constant MODE_ERC1271_ADMIN = 0x01;

bytes1 constant CALL_MODE_SINGLE_LEVEL = 0x00;
bytes1 constant CALL_MODE_BATCH_LEVEL = 0x01;
bytes1 constant CALL_MODE_DELEGATE_LEVEL = 0xff;

/**
 * A data structure for storing transaction permissions that can be attached to
 * a Signer.
 */
struct Policy {
    /*
    * 1st storage slot
    */
    uint48 validAfter; //       6 bytes
    uint48 validUntil; //       6 bytes
    address erc1271Caller; //   20 bytes
    /*
    * 2nd storage slot
    */
    bytes1 mode; //             1 byte
    bytes1 callMode; //         1 byte
    uint240 allowActions; //    30 bytes (up to 10 actions per policy)
}

library PolicyLib {
    function isEqual(Policy calldata p, Policy memory q) public pure returns (bool) {
        return p.validAfter == q.validAfter && p.validUntil == q.validUntil
            && p.erc1271Caller == q.erc1271Caller && p.mode == q.mode && p.callMode == q.callMode
            && p.allowActions == q.allowActions;
    }

    function isNull(Policy calldata p) public pure returns (bool) {
        return p.validAfter == 0 && p.validUntil == 0 && p.erc1271Caller == address(0)
            && p.mode == 0 && p.callMode == 0 && p.allowActions == 0;
    }

    function verifyUserOp(
        Policy calldata p,
        PackedUserOperation calldata
    )
        public
        pure
        returns (bool)
    {
        if (_isAdmin(p.mode)) {
            return true;
        }

        return false;
    }

    function verifyERC1271Caller(Policy calldata p, address) public pure returns (bool) {
        if (_isAdmin(p.mode)) {
            return true;
        }

        return false;
    }

    function _isAdmin(bytes1 mode) internal pure returns (bool) {
        return mode == MODE_ADMIN;
    }
}
