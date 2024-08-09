// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

bytes1 constant OPERATOR_EQ = 0x01;
bytes1 constant OPERATOR_GT = 0x02;
bytes1 constant OPERATOR_GTE = 0x03;
bytes1 constant OPERATOR_LT = 0x04;
bytes1 constant OPERATOR_LTE = 0x05;

bytes1 constant LEVEL_ALLOW_FAIL = 0x00;
bytes1 constant LEVEL_MUST_PASS_FOR_TARGET = 0x01;
bytes1 constant LEVEL_MUST_PASS = 0x02;

/**
 * A data structure for validating outgoing CALLs from the account's execute
 * function.
 */
struct Action {
    /*
    * 1st storage slot
    */
    address target; //          20 bytes
    bytes4 selector; //         4 bytes
    bytes1 level; //            1 byte
    uint8 argOffset; //         1 byte
    uint8 argLength; //         1 byte
    bytes1 argOperator; //      1 byte
    bytes1 payableOperator; //  1 byte
    bytes3 unused; //           3 bytes
    /*
    * 2nd storage slot
    */
    uint256 argValue; //        32 bytes
    /*
    * 3rd storage slot
    */
    uint256 payableValue; //    32 bytes
}

library ActionLib {
    function isEqual(Action calldata a, Action memory b) public pure returns (bool) {
        return a.target == b.target && a.selector == b.selector && a.level == b.level
            && a.argOffset == b.argOffset && a.argLength == b.argLength
            && a.argOperator == b.argOperator && a.payableOperator == b.payableOperator
            && a.unused == b.unused && a.argValue == b.argValue && a.payableValue == b.payableValue;
    }

    function isNull(Action calldata a) public pure returns (bool) {
        return a.target == address(0) && a.selector == 0 && a.level == 0 && a.argOffset == 0
            && a.argLength == 0 && a.argOperator == 0 && a.payableOperator == 0 && a.unused == 0
            && a.argValue == 0 && a.payableValue == 0;
    }

    function verifyCall(
        Action calldata a,
        address,
        uint256 value,
        bytes calldata
    )
        public
        pure
        returns (bool ok)
    {
        return value <= a.payableValue;
    }
}
