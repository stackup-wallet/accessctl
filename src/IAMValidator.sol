// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

struct Signer {
    uint256 x;
    uint256 y;
}

contract IAMValidator is ERC7579ValidatorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/
    event SignerAdded(address indexed account, bytes3 indexed signerId, uint256 x, uint256 y);

    error SignerAlreadyAdded(address account, bytes3 signerId);
    error SignerNotAdded(address account, bytes3 signerId);
    /**
     * @dev A register to determine if a given signer has been linked to an
     * account. The key is equal to concat(install count, signerId).
     */

    mapping(bytes4 installCountAndSignerId => mapping(address account => Signer s)) public
        SignerRegister;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     *
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override { }

    /**
     * De-initialize the module with the given data
     *
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override { }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) { }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Validates PackedUserOperation
     *
     * @param userOp UserOperation to be validated
     * @param userOpHash Hash of the UserOperation to be validated
     *
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - 0 if the signature is valid
     *  - 1 if the signature is invalid
     *  - <20-byte> aggregatorOrSigFail, <6-byte> validUntil and <6-byte> validAfter (see ERC-4337
     * for more details)
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        return ValidationData.wrap(0);
    }

    /**
     * Validates an ERC-1271 signature
     *
     * @param sender The sender of the ERC-1271 call to the account
     * @param hash The hash of the message
     * @param signature The signature of the message
     *
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - EIP1271_SUCCESS if the signature is valid
     *  - EIP1271_FAILED if the signature is invalid
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        virtual
        override
        returns (bytes4 sigValidationResult)
    {
        return EIP1271_FAILED;
    }

    /**
     * @dev Registers a new public key to the account. Emits a SignerAdded
     * event on success. Reverts with SignerAlreadyAdded if the key has
     * been initialized for the account.
     */
    function addSigner(uint256 x, uint256 y) external {
        if (
            SignerRegister[bytes4(0)][msg.sender].x == x
                && SignerRegister[bytes4(0)][msg.sender].y == y
        ) {
            revert SignerNotAdded(msg.sender, bytes3(0));
        }
        SignerRegister[bytes4(0)][msg.sender].x = x;
        SignerRegister[bytes4(0)][msg.sender].y = y;

        emit SignerAdded(msg.sender, bytes3(0), x, y);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     *
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "ValidatorTemplate";
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /**
     * Check if the module is of a certain type
     *
     * @param typeID The type ID to check
     *
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }
}
