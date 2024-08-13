// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

bytes1 constant LEVEL_ALLOW_FAIL = 0x00;
bytes1 constant LEVEL_MUST_PASS_FOR_TARGET = 0x01;
bytes1 constant LEVEL_MUST_PASS = 0x02;

bytes1 constant OPERATOR_ALLOW_ALL = 0x00;
bytes1 constant OPERATOR_EQ = 0x01;
bytes1 constant OPERATOR_NEQ = 0x02;
bytes1 constant OPERATOR_GT = 0x03;
bytes1 constant OPERATOR_GTE = 0x04;
bytes1 constant OPERATOR_LT = 0x05;
bytes1 constant OPERATOR_LTE = 0x06;

address constant TARGET_ALLOW_ALL = address(0);

bytes4 constant SELECTOR_ALLOW_ALL = bytes4(0);

uint16 constant ARG_ALLOW_ALL = 0;

/**
 * A data structure for validating outgoing CALLs from the account's execute
 * function.
 */
struct Action {
    /*
    * 1st storage slot
    */
    bytes1 level; //            1 byte
    address target; //          20 bytes
    bytes4 selector; //         4 bytes
    uint16 argOffset; //        2 byte
    uint16 argLength; //        2 byte
    bytes1 argOperator; //      1 byte
    bytes1 payableOperator; //  1 byte
    bytes1 unused; //           1 byte
    /*
    * 2nd storage slot
    */
    bytes32 argValue; //        32 bytes
    /*
    * 3rd storage slot
    */
    uint256 payableValue; //    32 bytes
}

library ActionLib {
    function isEqual(Action calldata a, Action memory b) public pure returns (bool) {
        return a.level == b.level && a.target == b.target && a.selector == b.selector
            && a.argOffset == b.argOffset && a.argLength == b.argLength
            && a.argOperator == b.argOperator && a.payableOperator == b.payableOperator
            && a.unused == b.unused && a.argValue == b.argValue && a.payableValue == b.payableValue;
    }

    function isNull(Action calldata a) public pure returns (bool) {
        return a.level == 0 && a.target == address(0) && a.selector == 0 && a.argOffset == 0
            && a.argLength == 0 && a.argOperator == 0 && a.payableOperator == 0 && a.unused == 0
            && a.argValue == 0 && a.payableValue == 0;
    }

    function verifyCall(
        Action calldata a,
        address target,
        uint256 value,
        bytes calldata data
    )
        public
        pure
        returns (bool callOk, bool revertOnFail)
    {
        if (a.level == LEVEL_MUST_PASS) {
            revertOnFail = true;
        }

        if (!_assertTarget(a.target, target)) {
            return (false, revertOnFail);
        }

        if (a.level == LEVEL_MUST_PASS_FOR_TARGET) {
            revertOnFail = true;
        }

        if (!_assertSelector(a.selector, data)) {
            return (false, revertOnFail);
        }

        if (!_assertArg(a.argValue, a.argOffset, a.argLength, a.argOperator, data)) {
            return (false, revertOnFail);
        }

        return (_assertPayableValue(a.payableValue, a.payableOperator, value), revertOnFail);
    }

    function _assertTarget(address ref, address target) internal pure returns (bool) {
        if (ref == TARGET_ALLOW_ALL) {
            return true;
        }

        return target == ref;
    }

    function _assertSelector(bytes4 ref, bytes calldata data) internal pure returns (bool) {
        if (data.length == 0 || ref == SELECTOR_ALLOW_ALL) {
            return true;
        }

        return data.length >= 4 && bytes4(data[:4]) == ref;
    }

    function _assertArg(
        bytes32 ref,
        uint16 offset,
        uint16 length,
        bytes1 operator,
        bytes calldata data
    )
        internal
        pure
        returns (bool)
    {
        if (offset == ARG_ALLOW_ALL && length == ARG_ALLOW_ALL && operator == OPERATOR_ALLOW_ALL) {
            return true;
        }
        if (data.length < offset + length) {
            return false;
        }

        // Extract a `bytes32` value from a slice of `data` starting at `offset`
        // and extending for `length` bytes. The extracted value is right-shifted
        // to align it correctly within the 32-byte space. This ensures that the
        // value occupies the least significant bytes of the `bytes32` variable.
        bytes32 value = (bytes32(data[offset:offset + length]) >> (8 * (32 - length)));
        if (operator == OPERATOR_EQ) {
            return value == ref;
        } else if (operator == OPERATOR_NEQ) {
            return value != ref;
        } else if (operator == OPERATOR_GT) {
            return value > ref;
        } else if (operator == OPERATOR_GTE) {
            return value >= ref;
        } else if (operator == OPERATOR_LT) {
            return value < ref;
        } else if (operator == OPERATOR_LTE) {
            return value <= ref;
        }

        // solhint-disable-next-line gas-custom-errors
        revert("IAM14 unexpected flow");
    }

    function _assertPayableValue(
        uint256 ref,
        bytes1 operator,
        uint256 value
    )
        internal
        pure
        returns (bool)
    {
        if (operator == OPERATOR_EQ) {
            return value == ref;
        } else if (operator == OPERATOR_NEQ) {
            return value != ref;
        } else if (operator == OPERATOR_GT) {
            return value > ref;
        } else if (operator == OPERATOR_GTE) {
            return value >= ref;
        } else if (operator == OPERATOR_LT) {
            return value < ref;
        } else if (operator == OPERATOR_LTE) {
            return value <= ref;
        } else if (operator == OPERATOR_ALLOW_ALL) {
            return true;
        }

        // solhint-disable-next-line gas-custom-errors
        revert("IAM14 unexpected flow");
    }
}
