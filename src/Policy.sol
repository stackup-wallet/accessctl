// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { IERC7579Account } from "modulekit/external/ERC7579.sol";

bytes1 constant MODE_ADMIN = 0x01;
bytes1 constant MODE_ERC1271_ADMIN = 0x02;

bytes1 constant CALL_MODE_LEVEL_SINGLE = 0x01;
bytes1 constant CALL_MODE_LEVEL_BATCH = 0x02;
bytes1 constant CALL_MODE_LEVEL_DELEGATE = 0x03;

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
    bytes1 callModeLevel; //    1 byte
    uint240 allowActions; //    30 bytes (up to 10 actions per policy)
}

library PolicyLib {
    function isEqual(Policy calldata p, Policy memory q) public pure returns (bool) {
        return p.validAfter == q.validAfter && p.validUntil == q.validUntil
            && p.erc1271Caller == q.erc1271Caller && p.mode == q.mode
            && p.callModeLevel == q.callModeLevel && p.allowActions == q.allowActions;
    }

    function isNull(Policy calldata p) public pure returns (bool) {
        return p.validAfter == 0 && p.validUntil == 0 && p.erc1271Caller == address(0)
            && p.mode == 0 && p.callModeLevel == 0 && p.allowActions == 0;
    }

    function verifyUserOp(
        Policy calldata p,
        PackedUserOperation calldata op
    )
        public
        pure
        returns (bool)
    {
        if (_isAdmin(p.mode)) {
            return true;
        }

        if (!_isCallingExecute(op.callData)) {
            revert("IAM12 not calling execute");
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

    function _isCallingExecute(bytes calldata call) internal pure returns (bool) {
        return bytes4(call[:4]) == IERC7579Account.execute.selector;
    }
}
