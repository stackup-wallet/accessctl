// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

bytes1 constant ADMIN_MODE = 0x01;

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
    uint48 validFrom; //            6 bytes
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
    CallInput[] callInputs; //      32 bytes/item
}
