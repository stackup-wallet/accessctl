// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { WebAuthnValidator } from "src/signers/WebAuthnValidator.sol";

contract WebAuthnValidatorTest is TestHelper {
    bytes32 internal constant dummyHash = bytes32(uint256(0xdead));
    bytes32 internal constant dummyBadHash = bytes32(uint256(0xbaad));

    function testReturnsFalseIfBadSig() public view {
        bytes memory sig = _webAuthnSign(dummyP256PrivateKeyRoot, dummyHash);

        assertFalse(
            sessionValidator.validateSignatureWithData(
                dummyBadHash, sig, abi.encode(dummyP256PubKeyXRoot, dummyP256PubKeyYRoot)
            )
        );
    }

    function testReturnsTrueIfGoodSig() public view {
        bytes memory sig = _webAuthnSign(dummyP256PrivateKeyRoot, dummyHash);

        assertTrue(
            sessionValidator.validateSignatureWithData(
                dummyHash, sig, abi.encode(dummyP256PubKeyXRoot, dummyP256PubKeyYRoot)
            )
        );
    }
}
