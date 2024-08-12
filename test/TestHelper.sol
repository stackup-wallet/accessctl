// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR, MODULE_TYPE_HOOK } from "modulekit/external/ERC7579.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Base64 } from "openzeppelin-contracts/contracts/utils/Base64.sol";
import { FCL_Elliptic_ZZ } from "FreshCryptoLib/FCL_elliptic.sol";
import { IAMModule } from "src/IAMModule.sol";
import { Signer, MODE_WEBAUTHN, MODE_ECDSA } from "src/Signer.sol";
import { Policy, MODE_ADMIN, CALL_TYPE_LEVEL_SINGLE, CALL_TYPE_LEVEL_BATCH } from "src/Policy.sol";
import { Action, LEVEL_MUST_PASS, OPERATOR_LTE, OPERATOR_GT } from "src/Action.sol";

abstract contract TestHelper is RhinestoneModuleKit, Test {
    event SignerAdded(address indexed account, uint112 indexed signerId, Signer signer);
    event SignerRemoved(address indexed account, uint112 indexed signerId);
    event PolicyAdded(address indexed account, uint112 indexed policyId, Policy policy);
    event PolicyRemoved(address indexed account, uint112 indexed policyId);
    event ActionAdded(address indexed account, uint24 indexed actionId, Action action);
    event ActionRemoved(address indexed account, uint24 indexed actionId);
    event RoleAdded(address indexed account, uint224 indexed roleId);
    event RoleRemoved(address indexed account, uint224 indexed roleId);

    using LibString for string;
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    IAMModule internal module;

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
    uint112 constant rootSignerId = 0;

    uint256 constant dummyP256PrivateKey1 =
        0x605e0a63a358c3060f9ea4b3ee7737f21e4dc49755f90ae4ad12ffcbe71a26ef;
    uint256 constant dummyP256PubKeyX1 =
        0x1b0f2d89ae560071a013a47d440532c606cc7753dc38e95760895f5822de97a9;
    uint256 constant dummyP256PubKeyY1 =
        0xe4d714fa24d1f9d2173a18f627d73ea17307ad285bf08823bdd9bc89ff4fa3c6;

    uint256 constant dummyP256PrivateKey2 =
        0x982642594965c2f0998a0db98748ff267995965605a3902c11a96d304305d727;
    uint256 constant dummyP256PubKeyX2 =
        0xbe5627cf6a968b258bbf73c0c180dbd1f657c9852b9494fee2a56d8c2021db17;
    uint256 constant dummyP256PubKeyY2 =
        0x6f8ced2c10424a460bbec2099ed6688ee8d4ad9df325be516917bafcb21fe55a;

    Account public member = makeAccount("member");

    Signer public dummyRootSigner =
        Signer(dummyP256PubKeyXRoot, dummyP256PubKeyYRoot, address(0), MODE_WEBAUTHN);
    Signer public dummySigner1 =
        Signer(dummyP256PubKeyX1, dummyP256PubKeyY1, address(0), MODE_WEBAUTHN);
    Signer public dummySigner2 =
        Signer(dummyP256PubKeyX2, dummyP256PubKeyY2, address(0), MODE_WEBAUTHN);

    Policy public dummyAdminPolicy;
    Policy public dummy1EtherSinglePolicy;
    Policy public dummy5EtherBatchPolicy;
    uint112 constant rootPolicyId = 0;

    Action public dummySendMax1EtherAction;
    Action public dummySendMax5EtherAction;
    Action public dummyAlwaysFailAction;
    Action public nullAction;
    uint24 constant rootActionId = 0;

    uint224 constant rootRoleId = 0;

    constructor() {
        dummyAdminPolicy.mode = MODE_ADMIN;

        dummy1EtherSinglePolicy.callTypeLevel = CALL_TYPE_LEVEL_SINGLE;
        dummy5EtherBatchPolicy.callTypeLevel = CALL_TYPE_LEVEL_BATCH;

        dummy1EtherSinglePolicy.allowActions = rootActionId + 1;
        dummy5EtherBatchPolicy.allowActions = rootActionId + 2;

        dummySendMax1EtherAction.payableValue = 1 ether;
        dummySendMax1EtherAction.payableOperator = OPERATOR_LTE;
        dummySendMax5EtherAction.payableValue = 5 ether;
        dummySendMax5EtherAction.payableOperator = OPERATOR_LTE;

        dummyAlwaysFailAction.level = LEVEL_MUST_PASS;
        dummyAlwaysFailAction.payableValue = type(uint256).max;
        dummyAlwaysFailAction.payableOperator = OPERATOR_GT;
    }

    function _webAuthnSign(
        uint224 roleId,
        bytes32 message,
        uint256 privateKey
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

        signature = abi.encodePacked(
            roleId,
            abi.encode(
                authenticatorData,
                clientDataJSONPre,
                clientDataJSONPost,
                challangeIndex,
                typeIndex,
                r,
                s
            )
        );
    }

    function _ecdsaSign(
        uint224 roleId,
        bytes32 message,
        uint256 pk
    )
        internal
        pure
        returns (bytes memory signature)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ECDSA.toEthSignedMessageHash(message));
        signature = abi.encodePacked(roleId, r, s, v);
    }

    function _execUserOp(address target, uint256 value, bytes memory data) internal {
        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: data,
            txValidator: address(module)
        });
        userOpData.userOp.signature =
            _webAuthnSign(rootRoleId, userOpData.userOpHash, dummyP256PrivateKeyRoot);
        userOpData.execUserOps();
    }

    function _execUserOp(
        uint224 roleId,
        uint256 pk,
        address target,
        uint256 value,
        bytes memory data
    )
        internal
    {
        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: data,
            txValidator: address(module)
        });
        userOpData.userOp.signature = _webAuthnSign(roleId, userOpData.userOpHash, pk);
        userOpData.execUserOps();
    }

    function _formatERC1271Hash(address validatorModule, bytes32 hash) internal returns (bytes32) {
        return instance.formatERC1271Hash(validatorModule, hash);
    }

    function _execUserOpWithECDSA(
        uint224 roleId,
        uint256 pk,
        address target,
        uint256 value,
        bytes memory data
    )
        internal
    {
        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: data,
            txValidator: address(module)
        });
        userOpData.userOp.signature = _ecdsaSign(roleId, userOpData.userOpHash, pk);
        userOpData.execUserOps();
    }

    function _verifyERC1271Signature(
        address validatorModule,
        bytes32 hash,
        bytes memory signature
    )
        internal
        returns (bool)
    {
        return instance.isValidSignature({
            validator: validatorModule,
            hash: hash,
            signature: signature
        });
    }

    function _installModuleWithWebAuthn() internal {
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(module),
            data: abi.encode(MODE_WEBAUTHN, dummyP256PubKeyXRoot, dummyP256PubKeyYRoot)
        });
        instance.installModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(module), data: "" });
    }

    function _installModuleWithECDSA() internal {
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(module),
            data: abi.encode(MODE_ECDSA, member.addr)
        });
        instance.installModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(module), data: "" });
    }

    function _uninstallModule() internal {
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(module),
            data: ""
        });
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(module),
            data: ""
        });
    }

    function setUp() public {
        init();

        // Create the module
        module = new IAMModule();
        vm.label(address(module), "IAMModule");

        // Create the account and install the validator
        instance = makeAccountInstance("MainAccount");
        vm.deal(address(instance.account), 10 ether);
        _installModuleWithWebAuthn();
    }
}
