// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { IERC7579Account, Execution, ERC7579ExecutionLib } from "modulekit/external/ERC7579.sol";
import { Action, ActionLib } from "src/Action.sol";

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
    using ActionLib for Action;

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
        PackedUserOperation calldata op,
        Action[] calldata actions
    )
        public
        pure
        returns (bool ok, string memory reason)
    {
        if (_isAdmin(p.mode)) {
            return (true, "");
        }

        if (!_isCallingExecute(op.callData)) {
            return (false, "IAM11 not calling execute");
        }

        bytes1 callType = _parseCallType(op.callData);
        if (callType > CALL_TYPE_LEVEL_BATCH || callType > p.callTypeLevel) {
            return (false, "IAM12 callType not allowed");
        }

        return _verifyExecutionCallData(callType, op.callData, actions);
    }

    function verifyERC1271Caller(Policy calldata p, address) public pure returns (bool) {
        if (_isAdmin(p.mode)) {
            return true;
        }

        return false;
    }

    function parsePackedActionIds(uint192 packedActionIds) public pure returns (uint24[8] memory) {
        return [
            uint24(packedActionIds >> (24 * 0)),
            uint24(packedActionIds >> (24 * 1)),
            uint24(packedActionIds >> (24 * 2)),
            uint24(packedActionIds >> (24 * 3)),
            uint24(packedActionIds >> (24 * 4)),
            uint24(packedActionIds >> (24 * 5)),
            uint24(packedActionIds >> (24 * 6)),
            uint24(packedActionIds >> (24 * 7))
        ];
    }

    function _isAdmin(bytes1 mode) internal pure returns (bool) {
        return mode == MODE_ADMIN;
    }

    function _isCallingExecute(bytes calldata call) internal pure returns (bool) {
        return bytes4(call[:4]) == IERC7579Account.execute.selector;
    }

    function _parseCallType(bytes calldata call) internal pure returns (bytes1 callType) {
        // Mode is the first byte after the selector, or the first byte in the
        // 32 byte mode argument of an execute call.
        callType = bytes1(call[4:5]);
    }

    function _verifyExecutionCallData(
        bytes1 callType,
        bytes calldata opCallData,
        Action[] calldata actions
    )
        internal
        pure
        returns (bool ok, string memory reason)
    {
        if (callType == CALL_TYPE_LEVEL_SINGLE) {
            return _verifyExecutionCallDataSingle(opCallData, actions);
        } else if (callType == CALL_TYPE_LEVEL_BATCH) {
            return _verifyExecutionCallDataBatch(opCallData, actions);
        }

        return (false, "IAM14 unexpected flow");
    }

    function _verifyExecutionCallDataSingle(
        bytes calldata opCallData,
        Action[] calldata actions
    )
        internal
        pure
        returns (bool ok, string memory reason)
    {
        (address target, uint256 value, bytes memory data) =
            _parseExecutionCallDataSingle(opCallData);

        bool actionMatched = false;
        for (uint256 i = 0; i < actions.length; i++) {
            Action memory action = actions[i];
            if (action.isNull()) {
                continue;
            }

            (bool callOk, bool revertOnFail) = action.verifyCall(target, value, data);
            if (callOk && !revertOnFail) {
                actionMatched = true;
            } else if (revertOnFail) {
                return (false, "IAM13 execution not allowed");
            }
        }
        if (!actionMatched) {
            return (false, "IAM13 execution not allowed");
        }
        return (true, "");
    }

    function _parseExecutionCallDataSingle(
        bytes calldata call
    )
        internal
        pure
        returns (address target, uint256 value, bytes calldata data)
    {
        // executionCallData is a dynamic sized byte value. We need to first get
        // the offset and length to know how to properly splice the userOp.callData.
        //
        // The offset starts after the 4 byte selector and the 32 byte mode
        // argument. It takes 32 bytes (i.e position 36 to 68).
        //
        // The length starts after the offset and takes 32 bytes (i.e position 68
        // to 100).
        uint256 offset = uint256(bytes32(call[36:68]));
        uint256 length = uint256(bytes32(call[68:100]));

        return ERC7579ExecutionLib.decodeSingle(call[100:36 + offset + length]);
    }

    function _verifyExecutionCallDataBatch(
        bytes calldata opCallData,
        Action[] calldata actions
    )
        internal
        pure
        returns (bool ok, string memory reason)
    {
        Execution[] memory executions = _parseExecutionCallDataBatch(opCallData);

        for (uint256 i = 0; i < executions.length; i++) {
            Execution memory execution = executions[i];

            bool actionMatched = false;
            for (uint256 j = 0; j < actions.length; j++) {
                Action memory action = actions[j];
                if (action.isNull()) {
                    continue;
                }

                (bool callOk, bool revertOnFail) =
                    action.verifyCall(execution.target, execution.value, execution.callData);
                if (callOk && !revertOnFail) {
                    actionMatched = true;
                } else if (revertOnFail) {
                    return (false, "IAM13 execution not allowed");
                }
            }
            if (!actionMatched) {
                return (false, "IAM13 execution not allowed");
            }
        }
        return (true, "");
    }

    function _parseExecutionCallDataBatch(
        bytes calldata call
    )
        internal
        pure
        returns (Execution[] memory executions)
    {
        // See comments in _parseExecutionCallDataSingle.
        uint256 offset = uint256(bytes32(call[36:68]));
        uint256 length = uint256(bytes32(call[68:100]));

        return ERC7579ExecutionLib.decodeBatch(call[100:36 + offset + length]);
    }
}
