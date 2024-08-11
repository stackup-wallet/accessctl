// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { TestHelper } from "test/TestHelper.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import {
    Action,
    ActionLib,
    LEVEL_ALLOW_FAIL,
    LEVEL_MUST_PASS_FOR_TARGET,
    LEVEL_MUST_PASS,
    OPERATOR_ALLOW_ALL,
    OPERATOR_EQ,
    OPERATOR_GT,
    OPERATOR_GTE,
    OPERATOR_LT,
    OPERATOR_LTE,
    TARGET_ALLOW_ALL,
    SELECTOR_ALLOW_ALL,
    ARG_ALLOW_ALL
} from "src/Action.sol";

contract ActionLibTest is TestHelper {
    using ActionLib for Action;

    struct TransferTuple {
        address to;
        uint256 value;
    }

    function testIsEqual() public view {
        assertTrue(dummySendMax1EtherAction.isEqual(dummySendMax1EtherAction));
        assertFalse(dummySendMax1EtherAction.isEqual(dummySendMax5EtherAction));
    }

    function testisNull() public view {
        Action memory testNullAction;
        assertTrue(testNullAction.isNull());
        assertFalse(dummySendMax1EtherAction.isNull());
    }

    function testVerifyCallTargetAllowAll() public pure {
        Action memory action;
        action.target = TARGET_ALLOW_ALL;

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0xdead), 0, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallTargetAllowOne() public pure {
        Action memory action;
        action.target = address(0xbeef);

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0xdead), 0, "");
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallSelectorAllowAll() public pure {
        Action memory action;
        action.selector = SELECTOR_ALLOW_ALL;

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0xdead), 0, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallSelectorAllowOne() public pure {
        Action memory action;
        action.selector = bytes4(0xdeadbeef);

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0), 0, hex"BAAAAAAD");
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallSelectorBadData() public pure {
        Action memory action;
        action.selector = bytes4(0xdeadbeef);

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0), 0, hex"BAAD");
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallArgsAllowAll() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = ARG_ALLOW_ALL;
        action.argLength = ARG_ALLOW_ALL;
        action.argOperator = OPERATOR_ALLOW_ALL;

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0),
            0,
            abi.encodeWithSelector(ERC20.transfer.selector, address(0), type(uint256).max)
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallArgsAddressEQ() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4;
        action.argLength = 32;
        action.argOperator = OPERATOR_EQ;
        action.argValue = bytes32(abi.encode(address(0xdeadbeef)));

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0),
            0,
            abi.encodeWithSelector(ERC20.transfer.selector, address(0xdeadbeef), 1 ether)
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0),
            0,
            abi.encodeWithSelector(ERC20.transfer.selector, address(0xBAAAAAAD), 1 ether)
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallPackedAddressEQ() public pure {
        Action memory action;
        action.selector = bytes4(0xffffffff);
        action.argOffset = 4 + 32 + 32;
        action.argLength = 20;
        action.argOperator = OPERATOR_EQ;
        action.argValue = bytes32(abi.encode(address(0xdeadbeef)));

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0),
            0,
            abi.encodeWithSelector(
                bytes4(0xffffffff), abi.encodePacked(address(0xdeadbeef), uint256(1 ether))
            )
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0),
            0,
            abi.encodeWithSelector(
                bytes4(0xffffffff), abi.encodePacked(address(0xBAAAAAAD), uint256(1 ether))
            )
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallStructAddressEQ() public pure {
        Action memory action;
        action.selector = bytes4(0xffffffff);
        action.argOffset = 4;
        action.argLength = 32;
        action.argOperator = OPERATOR_EQ;
        action.argValue = bytes32(abi.encode(address(0xdeadbeef)));

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0),
            0,
            abi.encodeWithSelector(
                bytes4(0xffffffff), TransferTuple(address(0xdeadbeef), uint256(1 ether))
            )
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0),
            0,
            abi.encodeWithSelector(
                bytes4(0xffffffff), TransferTuple(address(0xBAAAAAAD), uint256(1 ether))
            )
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallOverflow() public pure {
        bytes memory data = abi.encodeWithSelector(bytes4(0xffffffff), "");
        Action memory action;
        action.selector = bytes4(0xffffffff);
        action.argOffset = uint16(data.length - 31);
        action.argLength = 32;
        action.argOperator = OPERATOR_EQ;
        action.argValue = bytes32(uint256(1 ether));

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0), 0, data);
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallArgsUint256GT() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_GT;
        action.argValue = bytes32(uint256(1 ether));

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 0.5 ether)
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 1 ether)
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallArgsUint256GTE() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_GTE;
        action.argValue = bytes32(uint256(1 ether));

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 0.5 ether)
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 1 ether)
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallArgsUint256LT() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_LT;
        action.argValue = bytes32(uint256(1 ether));

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 0.5 ether)
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 1 ether)
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallArgsUint256LTE() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_LTE;
        action.argValue = bytes32(uint256(1 ether));

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 0.5 ether)
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 1 ether)
        );
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallArgsMustPassForTarget() public pure {
        Action memory action;
        action.level = LEVEL_MUST_PASS_FOR_TARGET;
        action.target = address(0xdeadbeef);
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_LTE;
        action.argValue = bytes32(uint256(1 ether));

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0xBAAAAAAD),
            0,
            abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
        );
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0xdeadbeef),
            0,
            abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
        );
        assertFalse(callOk);
        assertTrue(revertOnFail);
    }

    function testVerifyCallArgsMustPass() public pure {
        Action memory action;
        action.level = LEVEL_MUST_PASS;
        action.target = address(0xdeadbeef);
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_LTE;
        action.argValue = bytes32(uint256(1 ether));

        (bool callOk, bool revertOnFail) = action.verifyCall(
            address(0xBAAAAAAD),
            0,
            abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
        );
        assertFalse(callOk);
        assertTrue(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(
            address(0xdeadbeef),
            0,
            abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
        );
        assertFalse(callOk);
        assertTrue(revertOnFail);
    }

    function testVerifyCallPayableValueAllowAll() public pure {
        Action memory action;
        action.payableOperator = OPERATOR_ALLOW_ALL;

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0), 1 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 0.5 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 2 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallPayableValueEQ() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_EQ;

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0), 1 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 0.5 ether, "");
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 2 ether, "");
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallPayableValueGT() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_GT;

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0), 1 ether, "");
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 0.5 ether, "");
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 2 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallPayableValueGTE() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_GTE;

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0), 1 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 0.5 ether, "");
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 2 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallPayableValueLT() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_LT;

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0), 1 ether, "");
        assertFalse(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 0.5 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 2 ether, "");
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }

    function testVerifyCallPayableValueLTE() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_LTE;

        (bool callOk, bool revertOnFail) = action.verifyCall(address(0), 1 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 0.5 ether, "");
        assertTrue(callOk);
        assertFalse(revertOnFail);
        (callOk, revertOnFail) = action.verifyCall(address(0), 2 ether, "");
        assertFalse(callOk);
        assertFalse(revertOnFail);
    }
}
