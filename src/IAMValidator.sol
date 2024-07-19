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
    event SignerAdded(address indexed account, uint24 indexed signerId, uint256 x, uint256 y);

    error SignerNotAdded(address account, uint24 signerId);

    event SignerRemoved(address indexed account, uint24 indexed signerId);

    /**
     * @dev A monotonically increasing 3 dimensional value. It is 8 bytes and
     * composed of:
     *    1 bytes: times installed (max 255)
     *    3 bytes: total signers added (i.e. signerId, max 16,777,215)
     *    4 bytes: total policies added (i.e. policyId, max 4,294,967,295)
     * These values allow for efficient read/writes to the below mappings. For
     * instance, 1 byte install count ensures that an account state is
     * effectively reset during a reinstall without requiring any iterations.
     */
    mapping(address account => uint64 cnt) Counters;

    /**
     * @dev A register to determine if a given signer has been linked to an
     * account. The key is equal to concat(install count, signerId).
     */
    mapping(uint32 installCountAndSignerId => mapping(address account => Signer s)) public
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

    function _packCounter(
        uint8 installCount,
        uint24 signerId,
        uint32 policyId
    )
        private
        view
        returns (uint64)
    {
        return uint64(installCount) | (uint64(signerId) << 8) | (uint64(policyId) << (8 + 24));
    }

    function _parseCounter(uint64 counter)
        private
        view
        returns (uint8 installCount, uint24 signerId, uint32 policyId)
    {
        installCount = uint8(counter);
        signerId = uint24(counter >> 8);
        policyId = uint32(counter >> (8 + 24));
    }

    function _packInstallCountAndSignerId(
        uint8 installCount,
        uint24 signerId
    )
        private
        view
        returns (uint32)
    {
        return uint32(installCount) | (uint32(signerId) << 8);
    }

    function getSigner(address account, uint24 signerId) public view returns (Signer memory) {
        (uint8 installCount,,) = _parseCounter(Counters[account]);
        return SignerRegister[_packInstallCountAndSignerId(installCount, signerId)][account];
    }
    /**
     * @dev Registers a public key to the account under a unique signerId. Emits a SignerAdded
     * event on success.
     */

    function addSigner(uint256 x, uint256 y) external {
        (uint8 installCount, uint24 signerId, uint32 policyId) = _parseCounter(Counters[msg.sender]);
        uint32 key = _packInstallCountAndSignerId(installCount, signerId);
        Signer memory signer = Signer(x, y);

        SignerRegister[key][msg.sender] = signer;
        emit SignerAdded(msg.sender, signerId, x, y);
        Counters[msg.sender] = _packCounter(installCount, signerId + 1, policyId);
    }

    function removeSigner(uint24 signerId) external {
        (uint8 installCount, uint24 signerId, uint32 policyId) = _parseCounter(Counters[msg.sender]);
        uint32 key = _packInstallCountAndSignerId(installCount, signerId);
        if (SignerRegister[key][msg.sender].y == 0 && SignerRegister[key][msg.sender].x == 0) {
            revert SignerNotAdded(msg.sender, signerId);
        }
        SignerRegister[key][msg.sender].x = 0;
        SignerRegister[key][msg.sender].y = 0;

        emit SignerRemoved(msg.sender, signerId);
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
