// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ISessionValidator } from "smart-sessions/interfaces/ISessionValidator.sol";
import { P256Credentials, P256CredentialsLib } from "src/signers/P256Credentials.sol";

contract WebAuthnValidator is ISessionValidator {
    using P256CredentialsLib for P256Credentials;

    function validateSignatureWithData(
        bytes32 hash,
        bytes calldata sig,
        bytes calldata data
    )
        external
        view
        returns (bool validSig)
    {
        (uint256 x, uint256 y) = abi.decode(data, (uint256, uint256));
        return P256Credentials(x, y).verifyWebAuthnSignature(hash, sig);
    }

    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return interfaceID == WebAuthnValidator.validateSignatureWithData.selector;
    }
}
