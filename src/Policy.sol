// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

bytes1 constant MODE_ADMIN = 0x01;

bytes1 constant OPERATOR_EQ = 0x01;
bytes1 constant OPERATOR_GT = 0x02;
bytes1 constant OPERATOR_GTE = 0x03;
bytes1 constant OPERATOR_LT = 0x04;
bytes1 constant OPERATOR_LTE = 0x05;

/**
 * A data structure with information for splicing and comparing arguments from
 * call data.
 */
struct CallInput {
    uint8 offset; //    1 byte
    uint8 length; //    1 byte
    bytes1 operator; // 1 byte
    uint232 value; //   29 bytes
}

/**
 * A data structure for storing transaction permissions that can be attached to
 * a Signer.
 */
struct Policy {
    /*
    * 1st storage slot (32 bytes)
    */
    uint48 validAfter; //           6 bytes
    uint48 validUntil; //           6 bytes
    address erc1271Caller; //       20 bytes
    /*
    * 2nd storage slot (32 bytes)
    */
    bytes1 mode; //                 1 byte
    bytes5 reserved; //             5 bytes
    address callTarget; //          20 bytes
    bytes4 callSelector; //         4 bytes
    bytes1 callValueOperator; //    1 byte
    /*
    * 3rd storage slot (32 bytes)
    */
    uint256 callValue; //           32 bytes
    /*
    * Nth storage slots
    */
    bytes callInputValidationData;
}

library PolicyLib {
    function isEqual(Policy calldata p, Policy memory q) public pure returns (bool) {
        return p.validAfter == q.validAfter && p.validUntil == q.validUntil
            && p.erc1271Caller == q.erc1271Caller && p.mode == q.mode && p.reserved == q.reserved
            && p.callTarget == q.callTarget && p.callSelector == q.callSelector
            && p.callValueOperator == q.callValueOperator && p.callValue == q.callValue
            && keccak256(p.callInputValidationData) == keccak256(q.callInputValidationData);
    }

    function isNull(Policy calldata p) public pure returns (bool) {
        return p.validAfter == 0 && p.validUntil == 0 && p.erc1271Caller == address(0)
            && p.mode == 0 && p.reserved == 0 && p.callTarget == address(0) && p.callSelector == 0
            && p.callValueOperator == 0 && p.callValue == 0 && p.callInputValidationData.length == 0;
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
