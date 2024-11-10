// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { WebAuthn } from "webauthn-sol/WebAuthn.sol";
import { Base64 } from "openzeppelin-contracts/contracts/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";

struct P256Credentials {
    uint256 x;
    uint256 y;
}

library P256CredentialsLib {
    using LibString for string;

    function verifyWebAuthnSignature(
        P256Credentials calldata credential,
        bytes32 hash,
        bytes calldata signature
    )
        public
        view
        returns (bool)
    {
        bytes memory challenge = abi.encode(hash);
        WebAuthn.WebAuthnAuth memory auth = _getWebAuthnAuth(signature, challenge);
        return WebAuthn.verify(challenge, true, auth, credential.x, credential.y);
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
        ) = abi.decode(data, (bytes, string, string, uint256, uint256, uint256, uint256));
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
}
