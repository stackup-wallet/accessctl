// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { SCL_RIP7212 } from "crypto-lib/lib/libSCL_RIP7212.sol";
import { Signer } from "src/Signer.sol";
import { Policy } from "src/Policy.sol";

contract IAMValidator is ERC7579ValidatorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/
    event SignerAdded(address indexed account, uint120 indexed signerId, uint256 x, uint256 y);
    event SignerRemoved(address indexed account, uint120 indexed signerId);
    event PolicyAdded(address indexed account, uint120 indexed policyId, Policy p);
    event PolicyRemoved(address indexed account, uint120 indexed policyId);
    event RoleAdded(address indexed account, uint240 indexed roleId);
    event RoleRemoved(address indexed account, uint240 indexed roleId);

    /**
     * A packed 32 byte value for counting various account variables:
     *    2 bytes (uint16): install count
     *    15 bytes (uint120): total signers added (i.e. signerId)
     *    15 bytes (uint120): total policies added (i.e. policyId)
     * These values allow for efficient read/writes to the below mappings. For
     * instance, 1 byte install count ensures that an account state is
     * effectively reset during a reinstall without requiring any iterations.
     */
    mapping(address account => uint256 count) public Counters;

    /**
     * A register to determine if a given signer has been linked to an
     * account. The key is equal to concat(install count, signerId).
     */
    mapping(uint136 installCountAndSignerId => mapping(address account => Signer s)) public
        SignerRegister;

    /**
     * A register to determine if a given policy has been linked to an account.
     * The key is equal to concat(install count, policyId).
     */
    mapping(uint136 installCountAndPolicyId => mapping(address account => Policy p)) public
        PolicyRegister;

    /**
     * A register to determine if a given signer can assume a policy. The key is
     * equal to concat(install count, signerId, policyId).
     */
    mapping(uint256 installCountAndRoleId => mapping(address account => bool ok)) public
        RoleRegister;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     *
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        (uint256 x, uint256 y) = abi.decode(data, (uint256, uint256));
        _addSigner(x, y);
    }

    /**
     * De-initialize the module with the given data
     *
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override {
        (uint16 installCount,,) = _parseCounter(Counters[msg.sender]);
        Counters[msg.sender] = _packCounter(installCount + 1, 0, 0);
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        (, uint120 signerId,) = _parseCounter(Counters[smartAccount]);
        return signerId > 0;
    }

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
        (uint120 signerId, uint256 r, uint256 s) =
            abi.decode(userOp.signature, (uint120, uint256, uint256));
        Signer memory signer = getSigner(msg.sender, signerId);

        return SCL_RIP7212.verify(userOpHash, r, s, signer.x, signer.y)
            ? ValidationData.wrap(0)
            : ValidationData.wrap(1);
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
        (uint120 signerId, uint256 r, uint256 s) =
            abi.decode(signature, (uint120, uint256, uint256));
        (uint16 installCount,,) = _parseCounter(Counters[msg.sender]);
        Signer memory signer =
            SignerRegister[_packInstallCountAndId(installCount, signerId)][msg.sender];

        return SCL_RIP7212.verify(hash, r, s, signer.x, signer.y) ? EIP1271_SUCCESS : EIP1271_FAILED;
    }

    /**
     * Gets the public key for a given account and signerId.
     *
     * @param account The address of the modular smart account.
     * @param signerId A unique uint120 value assgined to the public key during
     * registration.
     */
    function getSigner(address account, uint120 signerId) public view returns (Signer memory) {
        (uint16 installCount,,) = _parseCounter(Counters[account]);
        return SignerRegister[_packInstallCountAndId(installCount, signerId)][account];
    }

    /**
     * Gets the policy for a given account and policyId.
     * @param account the address of the modular smart account.
     * @param policyId a unique uint120 value assigned to the policy during
     * registration.
     */
    function getPolicy(address account, uint120 policyId) public view returns (Policy memory) {
        (uint16 installCount,,) = _parseCounter(Counters[account]);
        return PolicyRegister[_packInstallCountAndId(installCount, policyId)][account];
    }

    /**
     * Checks if the role for a given account and roleId is active.
     * @param account the address of the modular smart account.
     * @param roleId a unique uint240 value assigned to the role during
     * registration.
     */
    function hasRole(address account, uint240 roleId) public view returns (bool) {
        (uint16 installCount,,) = _parseCounter(Counters[account]);
        return RoleRegister[_packInstallCountAndRoleId(installCount, roleId)][account];
    }

    /**
     * Registers a public key to the account under a unique signerId. Emits a
     * SignerAdded event on success.
     *
     * @param x The x-coordinate of the public key.
     * @param y The y-coordinate of the public key.
     */
    function addSigner(uint256 x, uint256 y) external {
        _addSigner(x, y);
    }

    /**
     * Deletes a public key registered to the account under a unique signerId.
     * Emits a SignerRemoved event on success.
     *
     * @param signerId A unique uint120 value assgined to the public key during
     * registration.
     */
    function removeSigner(uint120 signerId) external {
        (uint16 installCount,,) = _parseCounter(Counters[msg.sender]);
        uint136 key = _packInstallCountAndId(installCount, signerId);

        delete SignerRegister[key][msg.sender];
        emit SignerRemoved(msg.sender, signerId);
    }

    /**
     * Registers a policy to the account under a unique policyId. Emits a
     * PolicyRemoved event on success.
     *
     * @param p The Policy struct to add.
     */
    function addPolicy(Policy calldata p) external {
        _addPolicy(p);
    }

    /**
     * Deletes a policy registered to the account under a unique policyId.
     * Emits a SignerRemoved event on success.
     *
     * @param policyId A unique uint120 value assgined to the policy during
     * registration.
     */
    function removePolicy(uint120 policyId) external {
        (uint16 installCount,,) = _parseCounter(Counters[msg.sender]);
        uint136 key = _packInstallCountAndId(installCount, policyId);

        delete PolicyRegister[key][msg.sender];
        emit PolicyRemoved(msg.sender, policyId);
    }

    /**
     * Associates a registered signer with a registered policy. Emits a
     * RoleAdded event on success.
     *
     * @param signerId A unique uint120 value assgined to the public key during
     * registration.
     * @param policyId A unique uint120 value assgined to the policy during
     * registration.
     */
    function addRole(uint120 signerId, uint120 policyId) external {
        _addRole(signerId, policyId);
    }

    /**
     * Removes an association between a signer and policy. Emits a RoleRemoved
     * event on success.
     *
     * @param roleId A unique uint120 value assgined to the public key during
     * registration.
     */
    function removeRole(uint240 roleId) external {
        (uint16 installCount,,) = _parseCounter(Counters[msg.sender]);
        uint256 key = _packInstallCountAndRoleId(installCount, roleId);

        RoleRegister[key][msg.sender] = false;
        emit RoleRemoved(msg.sender, roleId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _addSigner(uint256 x, uint256 y) internal {
        (uint16 installCount, uint120 signerId, uint120 policyId) =
            _parseCounter(Counters[msg.sender]);
        uint136 key = _packInstallCountAndId(installCount, signerId);
        Signer memory signer = Signer(x, y);

        SignerRegister[key][msg.sender] = signer;
        emit SignerAdded(msg.sender, signerId, x, y);
        Counters[msg.sender] = _packCounter(installCount, signerId + 1, policyId);
    }

    function _addPolicy(Policy calldata p) internal {
        (uint16 installCount, uint120 signerId, uint120 policyId) =
            _parseCounter(Counters[msg.sender]);
        uint136 key = _packInstallCountAndId(installCount, policyId);

        PolicyRegister[key][msg.sender] = p;
        emit PolicyAdded(msg.sender, policyId, p);
        Counters[msg.sender] = _packCounter(installCount, signerId, policyId + 1);
    }

    function _addRole(uint120 signerId, uint120 policyId) internal {
        (uint16 installCount,,) = _parseCounter(Counters[msg.sender]);
        uint240 roleId = _packRoleId(signerId, policyId);
        uint256 key = _packInstallCountAndRoleId(installCount, roleId);

        RoleRegister[key][msg.sender] = true;
        emit RoleAdded(msg.sender, roleId);
    }

    function _packCounter(
        uint16 installCount,
        uint120 signerId,
        uint120 policyId
    )
        internal
        pure
        returns (uint256)
    {
        return uint256(installCount) | (uint256(signerId) << 16) | (uint256(policyId) << (16 + 120));
    }

    function _parseCounter(uint256 counter)
        internal
        pure
        returns (uint16 installCount, uint120 signerId, uint120 policyId)
    {
        installCount = uint16(counter);
        signerId = uint120(counter >> 16);
        policyId = uint120(counter >> (16 + 120));
    }

    function _packInstallCountAndId(
        uint16 installCount,
        uint120 id
    )
        internal
        pure
        returns (uint136)
    {
        return uint136(installCount) | (uint136(id) << 16);
    }

    function _packInstallCountAndRoleId(
        uint16 installCount,
        uint240 roleId
    )
        internal
        pure
        returns (uint256)
    {
        return uint256(installCount) | (uint256(roleId) << 16);
    }

    function _packRoleId(uint120 signerId, uint120 policyId) internal pure returns (uint240) {
        return uint240(signerId) | (uint240(policyId) << 120);
    }

    function _parseRoleId(uint240 roleId)
        internal
        pure
        returns (uint120 signerId, uint120 policyId)
    {
        signerId = uint120(roleId);
        policyId = uint120(roleId >> 120);
    }

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
