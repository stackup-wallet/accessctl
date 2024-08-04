// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase, ERC7579HookBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { SCL_RIP7212 } from "crypto-lib/lib/libSCL_RIP7212.sol";
import { Signer } from "src/Signer.sol";
import { Policy, PolicyLib, MODE_ADMIN } from "src/Policy.sol";
import { Action } from "src/Action.sol";
import { InitPhase } from "src/InitPhase.sol";
import { ContextQueue } from "src/ContextQueue.sol";

contract IAMValidator is ERC7579ValidatorBase, ERC7579HookBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    using PolicyLib for Policy;

    event SignerAdded(address indexed account, uint112 indexed signerId, uint256 x, uint256 y);
    event SignerRemoved(address indexed account, uint112 indexed signerId);
    event PolicyAdded(address indexed account, uint112 indexed policyId, Policy p);
    event PolicyRemoved(address indexed account, uint112 indexed policyId);
    event ActionAdded(address indexed account, uint24 indexed actionId, Action a);
    event ActionRemoved(address indexed account, uint24 indexed actionId);
    event RoleAdded(address indexed account, uint224 indexed roleId);
    event RoleRemoved(address indexed account, uint224 indexed roleId);

    /**
     * The IAMValidator is a combination of an ERC-7579 Validator and Hook. To
     * operation correctly, both validator and hook must be explicitly installed
     * on the smart account for the IAMValidator to be considered initialized.
     *
     * We use the InitPhase enum to track the state machine of initialization.
     */
    mapping(address account => InitPhase phase) internal CurrentInitPhase;

    /**
     * A packed 32 byte value for counting various account variables:
     *    1 bytes (uint8): install count
     *    14 bytes (uint112): total signers added (i.e. signerId)
     *    14 bytes (uint112): total policies added (i.e. policyId)
     *    3 bytes (uint24): total actions added (i.e. actionId)
     * These values allow for efficient read/writes to the below mappings. For
     * instance, 1 byte install count ensures that an account state is
     * effectively reset during a reinstall without requiring any iterations.
     */
    mapping(address account => uint256 count) internal Counters;

    /**
     * A register to determine if a given signer has been linked to an
     * account. The key is equal to concat(install count, signerId).
     */
    mapping(uint120 installCountAndSignerId => mapping(address account => Signer s)) internal
        SignerRegister;

    /**
     * A register to determine if a given policy has been linked to an account.
     * The key is equal to concat(install count, policyId).
     */
    mapping(uint120 installCountAndPolicyId => mapping(address account => Policy p)) internal
        PolicyRegister;

    /**
     * A register to determine if a given action has been linked to an account.
     * The key is equal to concat(install count, actionId).
     */
    mapping(uint32 installCountAndActionId => mapping(address account => Action a)) internal
        ActionRegister;

    /**
     * A register to determine if a given signer can assume a policy. The key is
     * equal to concat(install count, roleId).
     */
    mapping(uint232 installCountAndRoleId => mapping(address account => bool ok)) internal
        RoleRegister;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given root signer, adds an admin policy,
     * and associates the root signer with the admin policy.
     *
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        require(!this.isInitialized(msg.sender), "IAM31 already installed");

        InitPhase phase = CurrentInitPhase[msg.sender];
        if (phase == InitPhase.v0h0 && data.length == 0) {
            // installing hook first
            CurrentInitPhase[msg.sender] = InitPhase.v0h1;
        } else if (phase == InitPhase.v0h0) {
            // installing validator first
            _initializeValidator(data);
            CurrentInitPhase[msg.sender] = InitPhase.v1h0;
        } else if (phase == InitPhase.v1h0) {
            // install hook second
            CurrentInitPhase[msg.sender] = InitPhase.v1h1;
        } else if (phase == InitPhase.v0h1) {
            // installing validator second
            _initializeValidator(data);
            CurrentInitPhase[msg.sender] = InitPhase.v1h1;
        } else {
            revert("IAM36 unexpected phase");
        }
    }

    /**
     * De-initialize the module with the given data
     *
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override {
        InitPhase phase = CurrentInitPhase[msg.sender];
        require(phase != InitPhase.v0h0, "IAM32 already uninstalled");
        require(data.length == 32, "IAM33 bad uninstall data");

        uint256 typeId = abi.decode(data, (uint256));
        if (typeId == TYPE_VALIDATOR) {
            if (phase == InitPhase.v1h1) {
                // Uninstall validator first
                _uninitializeValiator();
                CurrentInitPhase[msg.sender] = InitPhase.v0h1;
            } else if (phase == InitPhase.v1h0) {
                // Uninstall validator second
                _uninitializeValiator();
                CurrentInitPhase[msg.sender] = InitPhase.v0h0;
            } else if (phase == InitPhase.v0h1) {
                revert("IAM35 validator already uninstalled");
            }
        } else if (typeId == TYPE_HOOK) {
            if (phase == InitPhase.v1h1) {
                // Uninstall hook first
                CurrentInitPhase[msg.sender] = InitPhase.v1h0;
            } else if (phase == InitPhase.v1h0) {
                revert("IAM36 hook already uninstalled");
            } else if (phase == InitPhase.v0h1) {
                // Uninstall hook second
                CurrentInitPhase[msg.sender] = InitPhase.v0h0;
            }
        } else {
            revert("IAM34 unexpected typeId");
        }
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return CurrentInitPhase[smartAccount] == InitPhase.v1h1;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Called on precheck before every execution
     */
    function _preCheck(
        address,
        address,
        uint256,
        bytes calldata
    )
        internal
        override
        returns (bytes memory hookData)
    {
        hookData = abi.encode(uint224(ContextQueue.dequeue()));
    }

    /**
     * Called on postcheck after every execution
     */
    function _postCheck(address, bytes calldata data) internal pure override { }

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
        override
        returns (ValidationData)
    {
        // Role check
        (uint224 roleId, uint256 r, uint256 s) =
            abi.decode(userOp.signature, (uint224, uint256, uint256));
        require(hasRole(msg.sender, roleId), "IAM10 invalid role");

        (uint112 signerId, uint112 policyId) = _parseRoleId(roleId);

        // Authorization check
        Policy memory p = getPolicy(msg.sender, policyId);
        require(p.verifyUserOp(userOp), "IAM11 userOp not allowed");

        // Authentication check
        Signer memory signer = getSigner(msg.sender, signerId);
        if (SCL_RIP7212.verify(userOpHash, r, s, signer.x, signer.y)) {
            // Load required context for execution hooks
            ContextQueue.enqueue(uint256(roleId));

            return _packValidationData(false, p.validUntil, p.validAfter);
        }
        return _packValidationData(true, p.validUntil, p.validAfter);
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
        // Role check
        (uint224 roleId, uint256 r, uint256 s) = abi.decode(signature, (uint224, uint256, uint256));
        require(hasRole(msg.sender, roleId), "IAM20 invalid role");

        (uint112 signerId, uint112 policyId) = _parseRoleId(roleId);

        // Authorization check
        Policy memory p = getPolicy(msg.sender, policyId);
        require(p.verifyERC1271Caller(sender), "IAM21 caller not allowed");

        // Authentication check
        Signer memory signer = getSigner(msg.sender, signerId);
        return SCL_RIP7212.verify(hash, r, s, signer.x, signer.y) ? EIP1271_SUCCESS : EIP1271_FAILED;
    }

    /**
     * Gets the public key for a given account and signerId.
     *
     * @param account The address of the modular smart account.
     * @param signerId A unique uint112 value assgined to the public key during
     * registration.
     */
    function getSigner(address account, uint112 signerId) public view returns (Signer memory) {
        (uint8 installCount,,,) = _parseCounter(Counters[account]);
        return SignerRegister[_packInstallCountAndId(installCount, signerId)][account];
    }

    /**
     * Gets the policy for a given account and policyId.
     * @param account the address of the modular smart account.
     * @param policyId a unique uint112 value assigned to the policy during
     * registration.
     */
    function getPolicy(address account, uint112 policyId) public view returns (Policy memory) {
        (uint8 installCount,,,) = _parseCounter(Counters[account]);
        return PolicyRegister[_packInstallCountAndId(installCount, policyId)][account];
    }

    /**
     * Gets the action for a given account and actionId.
     * @param account the address of the modular smart account.
     * @param actionId a unique uint24 value assigned to the action during
     * registration.
     */
    function getAction(address account, uint24 actionId) public view returns (Action memory) {
        (uint8 installCount,,,) = _parseCounter(Counters[account]);
        return ActionRegister[_packInstallCountAndActionId(installCount, actionId)][account];
    }

    /**
     * Checks if the role for a given account and roleId is active.
     * @param account the address of the modular smart account.
     * @param roleId a unique uint224 value assigned to the role during
     * registration.
     */
    function hasRole(address account, uint224 roleId) public view returns (bool) {
        (uint8 installCount,,,) = _parseCounter(Counters[account]);
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
     * @param signerId A unique uint112 value assgined to the public key during
     * registration.
     */
    function removeSigner(uint112 signerId) external {
        (uint8 installCount,,,) = _parseCounter(Counters[msg.sender]);

        delete SignerRegister[_packInstallCountAndId(installCount, signerId)][msg.sender];
        emit SignerRemoved(msg.sender, signerId);
    }

    /**
     * Registers a policy to the account under a unique policyId. Emits a
     * PolicyAdded event on success.
     *
     * @param p The Policy struct to add.
     */
    function addPolicy(Policy calldata p) external {
        _addPolicy(p);
    }

    /**
     * Deletes a policy registered to the account under a unique policyId.
     * Emits a PolicyRemoved event on success.
     *
     * @param policyId A unique uint112 value assgined to the policy during
     * registration.
     */
    function removePolicy(uint112 policyId) external {
        (uint8 installCount,,,) = _parseCounter(Counters[msg.sender]);

        delete PolicyRegister[_packInstallCountAndId(installCount, policyId)][msg.sender];
        emit PolicyRemoved(msg.sender, policyId);
    }

    /**
     * Registers an action to the account under a unique actionId. Emits an
     * actionAdded event on success.
     *
     * @param a The Action struct to add.
     */
    function addAction(Action calldata a) external {
        _addAction(a);
    }

    /**
     * Deletes an action registered to the account under a unique actionId.
     * Emits an ActionRemoved event on success.
     *
     * @param actionId A unique uint24 value assgined to the action during
     * registration.
     */
    function removeAction(uint24 actionId) external {
        (uint8 installCount,,,) = _parseCounter(Counters[msg.sender]);

        delete ActionRegister[_packInstallCountAndActionId(installCount, actionId)][msg.sender];
        emit ActionRemoved(msg.sender, actionId);
    }

    /**
     * Associates a registered signer with a registered policy. Emits a
     * RoleAdded event on success.
     *
     * @param signerId A unique uint112 value assgined to the public key during
     * registration.
     * @param policyId A unique uint112 value assgined to the policy during
     * registration.
     */
    function addRole(uint112 signerId, uint112 policyId) external {
        _addRole(signerId, policyId);
    }

    /**
     * Removes an association between a signer and policy. Emits a RoleRemoved
     * event on success.
     *
     * @param roleId A unique uint224 value assgined to the role during
     * registration.
     */
    function removeRole(uint224 roleId) external {
        (uint8 installCount,,,) = _parseCounter(Counters[msg.sender]);

        RoleRegister[_packInstallCountAndRoleId(installCount, roleId)][msg.sender] = false;
        emit RoleRemoved(msg.sender, roleId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _initializeValidator(bytes calldata data) internal {
        (uint256 x, uint256 y) = abi.decode(data, (uint256, uint256));
        _addSigner(x, y);

        Policy memory p;
        p.mode = MODE_ADMIN;
        _addPolicy(p);

        Action memory a;
        _addAction(a);

        _addRole(0, 0);
    }

    function _uninitializeValiator() internal {
        (uint8 installCount,,,) = _parseCounter(Counters[msg.sender]);
        Counters[msg.sender] = _packCounter(installCount + 1, 0, 0, 0);
    }

    function _addSigner(uint256 x, uint256 y) internal {
        (uint8 installCount, uint112 signerId, uint112 policyId, uint24 actionId) =
            _parseCounter(Counters[msg.sender]);
        Signer memory signer = Signer(x, y);

        SignerRegister[_packInstallCountAndId(installCount, signerId)][msg.sender] = signer;
        emit SignerAdded(msg.sender, signerId, x, y);
        Counters[msg.sender] = _packCounter(installCount, signerId + 1, policyId, actionId);
    }

    function _addPolicy(Policy memory p) internal {
        (uint8 installCount, uint112 signerId, uint112 policyId, uint24 actionId) =
            _parseCounter(Counters[msg.sender]);

        PolicyRegister[_packInstallCountAndId(installCount, policyId)][msg.sender] = p;
        emit PolicyAdded(msg.sender, policyId, p);
        Counters[msg.sender] = _packCounter(installCount, signerId, policyId + 1, actionId);
    }

    function _addAction(Action memory a) internal {
        (uint8 installCount, uint112 signerId, uint112 policyId, uint24 actionId) =
            _parseCounter(Counters[msg.sender]);

        ActionRegister[_packInstallCountAndActionId(installCount, actionId)][msg.sender] = a;
        emit ActionAdded(msg.sender, actionId, a);
        Counters[msg.sender] = _packCounter(installCount, signerId, policyId, actionId + 1);
    }

    function _addRole(uint112 signerId, uint112 policyId) internal {
        (uint8 installCount,,,) = _parseCounter(Counters[msg.sender]);
        uint224 roleId = _packRoleId(signerId, policyId);

        RoleRegister[_packInstallCountAndRoleId(installCount, roleId)][msg.sender] = true;
        emit RoleAdded(msg.sender, roleId);
    }

    function _packCounter(
        uint8 installCount,
        uint112 signerId,
        uint112 policyId,
        uint24 actionId
    )
        internal
        pure
        returns (uint256)
    {
        return uint256(installCount) | (uint256(signerId) << 8) | (uint256(policyId) << (8 + 112))
            | (uint256(actionId) << 8 + 112 + 112);
    }

    function _parseCounter(uint256 counter)
        internal
        pure
        returns (uint8 installCount, uint112 signerId, uint112 policyId, uint24 actionId)
    {
        installCount = uint8(counter);
        signerId = uint112(counter >> 8);
        policyId = uint112(counter >> (8 + 112));
        actionId = uint24(counter >> (8 + 112 + 112));
    }

    function _packInstallCountAndId(
        uint8 installCount,
        uint112 id
    )
        internal
        pure
        returns (uint120)
    {
        return uint120(installCount) | (uint120(id) << 8);
    }

    function _packInstallCountAndActionId(
        uint8 installCount,
        uint24 actionId
    )
        internal
        pure
        returns (uint32)
    {
        return uint32(installCount) | (uint32(actionId) << 8);
    }

    function _packInstallCountAndRoleId(
        uint8 installCount,
        uint224 roleId
    )
        internal
        pure
        returns (uint232)
    {
        return uint232(installCount) | (uint232(roleId) << 8);
    }

    function _packRoleId(uint112 signerId, uint112 policyId) internal pure returns (uint224) {
        return uint224(signerId) | (uint224(policyId) << 112);
    }

    function _parseRoleId(uint224 roleId)
        internal
        pure
        returns (uint112 signerId, uint112 policyId)
    {
        signerId = uint112(roleId);
        policyId = uint112(roleId >> 112);
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
        return typeID == TYPE_VALIDATOR || typeID == TYPE_HOOK;
    }
}
