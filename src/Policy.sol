// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { IERC7579Account } from "modulekit/external/ERC7579.sol";

bytes1 constant MODE_ADMIN = 0x01;
bytes1 constant MODE_ERC1271_ADMIN = 0x02;

bytes1 constant CALL_TYPE_LEVEL_SINGLE = 0x00;
bytes1 constant CALL_TYPE_LEVEL_BATCH = 0x01;

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
    bytes1 callTypeLevel; //    1 byte
    uint48 validInterval; //    6 bytes
    uint192 allowActions; //    24 bytes (up to 8 actions per policy)
}

library PolicyLib {
    function isEqual(Policy calldata p, Policy memory q) public pure returns (bool) {
        return p.validAfter == q.validAfter && p.validUntil == q.validUntil
            && p.erc1271Caller == q.erc1271Caller && p.mode == q.mode
            && p.callTypeLevel == q.callTypeLevel && p.validInterval == q.validInterval
            && p.allowActions == q.allowActions;
    }

    function isNull(Policy calldata p) public pure returns (bool) {
        return p.validAfter == 0 && p.validUntil == 0 && p.erc1271Caller == address(0)
            && p.mode == 0 && p.callTypeLevel == 0 && p.validInterval == 0 && p.allowActions == 0;
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

        (bytes1 callType, bytes memory executionCallData) = _parseExecuteArgs(op.callData);
        if (callType > CALL_TYPE_LEVEL_BATCH || callType > p.callTypeLevel) {
            revert("IAM13 callType not allowed");
        }

        return true;
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

    function _parseExecuteArgs(bytes calldata call)
        internal
        pure
        returns (bytes1 callType, bytes memory executionCallData)
    {
        (bytes32 mode, bytes memory data) = abi.decode(call[4:], (bytes32, bytes));
        callType = mode[0];
        executionCallData = data;
    }
}
