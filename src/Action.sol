// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

bytes1 constant OPERATOR_EQ = 0x01;
bytes1 constant OPERATOR_GT = 0x02;
bytes1 constant OPERATOR_GTE = 0x03;
bytes1 constant OPERATOR_LT = 0x04;
bytes1 constant OPERATOR_LTE = 0x05;

/**
 * A data structure for validating outgoing CALLs from the account's execute
 * function.
 */
struct Action {
    /*
    * 1st storage slot
    */
    address target; //  20 bytes
    bytes5 unused; //   5 bytes
    bytes4 selector; // 4 bytes
    uint8 offset; //    1 byte
    uint8 length; //    1 byte
    bytes1 operator; // 1 byte
    /*
    * 2nd storage slot
    */
    uint256 value; //   32 bytes
}

library ActionLib {
    function isEqual(Action calldata a, Action memory b) public pure returns (bool) {
        return a.target == b.target && a.unused == b.unused && a.selector == b.selector
            && a.offset == b.offset && a.length == b.length && a.operator == b.operator
            && a.value == b.value;
    }

    function isNull(Action calldata a) public pure returns (bool) {
        return a.target == address(0) && a.unused == 0 && a.selector == 0 && a.offset == 0
            && a.length == 0 && a.operator == 0 && a.value == 0;
    }
}
