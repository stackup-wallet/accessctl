// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { TestHelper } from "test/TestHelper.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import {
    Action,
    ActionLib,
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

        assertTrue(action.verifyCall(address(0xdead), 0, ""));
    }

    function testVerifyCallTargetAllowOne() public pure {
        Action memory action;
        action.target = address(0xbeef);

        assertFalse(action.verifyCall(address(0xdead), 0, ""));
    }

    function testVerifyCallSelectorAllowAll() public pure {
        Action memory action;
        action.selector = SELECTOR_ALLOW_ALL;

        assertTrue(action.verifyCall(address(0), 0, hex"BAAAAAAD"));
    }

    function testVerifyCallSelectorAllowOne() public pure {
        Action memory action;
        action.selector = bytes4(0xdeadbeef);

        assertFalse(action.verifyCall(address(0), 0, hex"BAAAAAAD"));
    }

    function testVerifyCallSelectorBadData() public pure {
        Action memory action;
        action.selector = bytes4(0xdeadbeef);

        assertFalse(action.verifyCall(address(0), 0, hex"BAAD"));
    }

    function testVerifyCallArgsAllowAll() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = ARG_ALLOW_ALL;
        action.argLength = ARG_ALLOW_ALL;
        action.argOperator = OPERATOR_ALLOW_ALL;

        assertTrue(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(ERC20.transfer.selector, address(0), type(uint256).max)
            )
        );
    }

    function testVerifyCallArgsAddressEq() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4;
        action.argLength = 32;
        action.argOperator = OPERATOR_EQ;
        action.argValue = bytes32(abi.encode(address(0xdeadbeef)));

        assertTrue(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(ERC20.transfer.selector, address(0xdeadbeef), 1 ether)
            )
        );
        assertFalse(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(ERC20.transfer.selector, address(0xBAAAAAAD), 1 ether)
            )
        );
    }

    function testVerifyCallPackedAddressEq() public pure {
        Action memory action;
        action.selector = bytes4(0xffffffff);
        action.argOffset = 4 + 32 + 32;
        action.argLength = 20;
        action.argOperator = OPERATOR_EQ;
        action.argValue = bytes32(abi.encode(address(0xdeadbeef)));

        assertTrue(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(
                    bytes4(0xffffffff), abi.encodePacked(address(0xdeadbeef), uint256(1 ether))
                )
            )
        );
        assertFalse(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(
                    bytes4(0xffffffff), abi.encodePacked(address(0xBAAAAAAD), uint256(1 ether))
                )
            )
        );
    }

    function testVerifyCallStructAddressEq() public pure {
        Action memory action;
        action.selector = bytes4(0xffffffff);
        action.argOffset = 4;
        action.argLength = 32;
        action.argOperator = OPERATOR_EQ;
        action.argValue = bytes32(abi.encode(address(0xdeadbeef)));

        assertTrue(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(
                    bytes4(0xffffffff), TransferTuple(address(0xdeadbeef), uint256(1 ether))
                )
            )
        );
        assertFalse(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(
                    bytes4(0xffffffff), TransferTuple(address(0xBAAAAAAD), uint256(1 ether))
                )
            )
        );
    }

    function testVerifyCallOverflow() public pure {
        bytes memory data = abi.encodeWithSelector(bytes4(0xffffffff), "");
        Action memory action;
        action.selector = bytes4(0xffffffff);
        action.argOffset = uint16(data.length - 31);
        action.argLength = 32;
        action.argOperator = OPERATOR_EQ;
        action.argValue = bytes32(uint256(1 ether));

        assertFalse(action.verifyCall(address(0), 0, data));
    }

    function testVerifyCallArgsUint256GT() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_GT;
        action.argValue = bytes32(uint256(1 ether));

        assertFalse(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(ERC20.transfer.selector, address(0), 0.5 ether)
            )
        );
        assertFalse(
            action.verifyCall(
                address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 1 ether)
            )
        );
        assertTrue(
            action.verifyCall(
                address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
            )
        );
    }

    function testVerifyCallArgsUint256GTE() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_GTE;
        action.argValue = bytes32(uint256(1 ether));

        assertFalse(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(ERC20.transfer.selector, address(0), 0.5 ether)
            )
        );
        assertTrue(
            action.verifyCall(
                address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 1 ether)
            )
        );
        assertTrue(
            action.verifyCall(
                address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
            )
        );
    }

    function testVerifyCallArgsUint256LT() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_LT;
        action.argValue = bytes32(uint256(1 ether));

        assertTrue(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(ERC20.transfer.selector, address(0), 0.5 ether)
            )
        );
        assertFalse(
            action.verifyCall(
                address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 1 ether)
            )
        );
        assertFalse(
            action.verifyCall(
                address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
            )
        );
    }

    function testVerifyCallArgsUint256LTE() public pure {
        Action memory action;
        action.selector = ERC20.transfer.selector;
        action.argOffset = 4 + 32;
        action.argLength = 32;
        action.argOperator = OPERATOR_LTE;
        action.argValue = bytes32(uint256(1 ether));

        assertTrue(
            action.verifyCall(
                address(0),
                0,
                abi.encodeWithSelector(ERC20.transfer.selector, address(0), 0.5 ether)
            )
        );
        assertTrue(
            action.verifyCall(
                address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 1 ether)
            )
        );
        assertFalse(
            action.verifyCall(
                address(0), 0, abi.encodeWithSelector(ERC20.transfer.selector, address(0), 2 ether)
            )
        );
    }

    function testVerifyCallPayableValueAllowAll() public pure {
        Action memory action;
        action.payableOperator = OPERATOR_ALLOW_ALL;

        assertTrue(action.verifyCall(address(0), 1 ether, ""));
        assertTrue(action.verifyCall(address(0), 0.5 ether, ""));
        assertTrue(action.verifyCall(address(0), 2 ether, ""));
    }

    function testVerifyCallPayableValueEQ() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_EQ;

        assertTrue(action.verifyCall(address(0), 1 ether, ""));
        assertFalse(action.verifyCall(address(0), 0.5 ether, ""));
        assertFalse(action.verifyCall(address(0), 2 ether, ""));
    }

    function testVerifyCallPayableValueGT() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_GT;

        assertFalse(action.verifyCall(address(0), 1 ether, ""));
        assertFalse(action.verifyCall(address(0), 0.5 ether, ""));
        assertTrue(action.verifyCall(address(0), 2 ether, ""));
    }

    function testVerifyCallPayableValueGTE() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_GTE;

        assertTrue(action.verifyCall(address(0), 1 ether, ""));
        assertFalse(action.verifyCall(address(0), 0.5 ether, ""));
        assertTrue(action.verifyCall(address(0), 2 ether, ""));
    }

    function testVerifyCallPayableValueLT() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_LT;

        assertFalse(action.verifyCall(address(0), 1 ether, ""));
        assertTrue(action.verifyCall(address(0), 0.5 ether, ""));
        assertFalse(action.verifyCall(address(0), 2 ether, ""));
    }

    function testVerifyCallPayableValueLTE() public pure {
        Action memory action;
        action.payableValue = 1 ether;
        action.payableOperator = OPERATOR_LTE;

        assertTrue(action.verifyCall(address(0), 1 ether, ""));
        assertTrue(action.verifyCall(address(0), 0.5 ether, ""));
        assertFalse(action.verifyCall(address(0), 2 ether, ""));
    }
}
