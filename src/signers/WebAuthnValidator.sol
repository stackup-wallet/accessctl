// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC7579_MODULE_TYPE_STATELESS_VALIDATOR } from "smart-sessions/DataTypes.sol";
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

    function isModuleType(uint256 id) external pure returns (bool) {
        return id == ERC7579_MODULE_TYPE_STATELESS_VALIDATOR;
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isInitialized(address) external pure override returns (bool) {
        return true;
    }
}
