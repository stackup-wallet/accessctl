// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Base64 } from "openzeppelin-contracts/contracts/utils/Base64.sol";
import { FCL_Elliptic_ZZ } from "FreshCryptoLib/FCL_elliptic.sol";
import { WebAuthnValidator } from "src/signers/WebAuthnValidator.sol";
import { IntervalSpendingLimitPolicy } from "src/policies/IntervalSpendingLimitPolicy.sol";

abstract contract TestHelper is Test {
    using LibString for string;

    WebAuthnValidator internal sessionValidator;
    IntervalSpendingLimitPolicy internal spendingLimitPolicy;

    // Dummy WebAuthn variables
    // From https://github.com/base-org/webauthn-sol/blob/main/test/WebAuthn.t.sol
    bytes constant authenticatorData =
        hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d9763050000010a";
    string constant clientDataJSONPre = '{"type":"webauthn.get","challenge":"';
    string constant clientDataJSONPost = '","origin":"http://localhost:3005","crossOrigin":false}';
    uint256 constant challangeIndex = 23;
    uint256 constant typeIndex = 1;

    uint256 constant dummyP256PrivateKeyRoot =
        0x9b6949ce4e9f7958797d91a4a51a96e9361b94451b88791d8784d8331b46c32d;
    uint256 constant dummyP256PubKeyXRoot =
        0xf24b7cd0e0d84317f2fbba39add412ddd3df7cb84be213b67fb340373e9275ec;
    uint256 constant dummyP256PubKeyYRoot =
        0x255417d4c6780a9db69e2023685c95a344f3e59e930e758f3829b0b10bf87ebc;

    function _webAuthnSign(
        uint256 privateKey,
        bytes32 message
    )
        internal
        pure
        returns (bytes memory signature)
    {
        string memory clientDataJSON = clientDataJSONPre.concat(
            Base64.encodeURL(abi.encode(message))
        ).concat(clientDataJSONPost);
        bytes32 clientDataJSONHash = sha256(bytes(clientDataJSON));
        bytes32 messageHash = sha256(abi.encodePacked(authenticatorData, clientDataJSONHash));
        (bytes32 rBytes, bytes32 sBytes) = vm.signP256(privateKey, messageHash);
        uint256 r = uint256(rBytes);
        uint256 s = uint256(sBytes);
        if (s > FCL_Elliptic_ZZ.n / 2) {
            s = FCL_Elliptic_ZZ.n - s;
        }

        signature = abi.encode(
            authenticatorData,
            clientDataJSONPre,
            clientDataJSONPost,
            challangeIndex,
            typeIndex,
            r,
            s
        );
    }

    function setUp() public {
        sessionValidator = new WebAuthnValidator();
        vm.label(address(sessionValidator), "WebAuthnValidator");

        spendingLimitPolicy = new IntervalSpendingLimitPolicy();
        vm.label(address(spendingLimitPolicy), "IntervalSpendingLimitPolicy");
    }
}
