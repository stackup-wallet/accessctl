// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { WebAuthn } from "webauthn-sol/WebAuthn.sol";
import { Base64 } from "openzeppelin-contracts/contracts/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

bytes1 constant MODE_WEBAUTHN = 0x00;
bytes1 constant MODE_ECDSA = 0x01;

/**
 * A data structure for storing an associated signer's public key.
 */
struct Signer {
    /*
    * 1st storage slot
    */
    uint256 p256x;
    /*
    * 2st storage slot
    */
    uint256 p256y;
    /*
    * 3rd storage slot
    */
    address ecdsa;
    bytes1 mode;
}

library SignerLib {
    using LibString for string;

    function isEqual(Signer calldata s, Signer memory t) public pure returns (bool) {
        return s.p256x == t.p256x && s.p256y == t.p256y && s.ecdsa == t.ecdsa && s.mode == t.mode;
    }

    function isNull(Signer calldata s) public pure returns (bool) {
        return s.p256x == 0 && s.p256y == 0 && s.ecdsa == address(0) && s.mode == 0;
    }

    function verifySignature(
        Signer calldata s,
        bytes32 hash,
        bytes calldata signature
    )
        public
        view
        returns (bool)
    {
        if (s.mode == MODE_WEBAUTHN) {
            bytes memory challenge = abi.encode(hash);
            WebAuthn.WebAuthnAuth memory auth = _getWebAuthnAuth(signature, challenge);
            return WebAuthn.verify(challenge, true, auth, s.p256x, s.p256y);
        } else if (s.mode == MODE_ECDSA) {
            return s.ecdsa
                == ECDSA.recover(ECDSA.toEthSignedMessageHash(hash), _getECDSASignature(signature));
        }

        // solhint-disable-next-line gas-custom-errors
        revert("IAM14 unexpected flow");
    }

    function _getWebAuthnAuth(
        bytes calldata data,
        bytes memory challange
    )
        internal
        pure
        returns (WebAuthn.WebAuthnAuth memory auth)
    {
        (
            bytes memory authenticatorData,
            string memory clientDataJSONPre,
            string memory clientDataJSONPost,
            uint256 challengeIndex,
            uint256 typeIndex,
            uint256 r,
            uint256 s
        ) = abi.decode(data[28:], (bytes, string, string, uint256, uint256, uint256, uint256));
        auth = WebAuthn.WebAuthnAuth({
            authenticatorData: authenticatorData,
            clientDataJSON: clientDataJSONPre.concat(Base64.encodeURL(challange)).concat(
                clientDataJSONPost
            ),
            challengeIndex: challengeIndex,
            typeIndex: typeIndex,
            r: r,
            s: s
        });
    }

    function _getECDSASignature(
        bytes calldata data
    )
        internal
        pure
        returns (bytes memory signature)
    {
        signature = data[28:];
    }
}
