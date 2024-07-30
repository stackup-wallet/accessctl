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
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { IAMValidator } from "src/IAMValidator.sol";
import { Signer } from "src/Signer.sol";
import { Policy, MODE_ADMIN } from "src/Policy.sol";
import { Action, OPERATOR_LTE } from "src/Action.sol";

abstract contract TestHelper is RhinestoneModuleKit, Test {
    event SignerAdded(address indexed account, uint112 indexed signerId, uint256 x, uint256 y);
    event SignerRemoved(address indexed account, uint112 indexed signerId);
    event PolicyAdded(address indexed account, uint112 indexed policyId, Policy p);
    event PolicyRemoved(address indexed account, uint112 indexed policyId);
    event ActionAdded(address indexed account, uint24 indexed actionId, Action a);
    event ActionRemoved(address indexed account, uint24 indexed actionId);
    event RoleAdded(address indexed account, uint224 indexed roleId);
    event RoleRemoved(address indexed account, uint224 indexed roleId);

    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    IAMValidator internal validator;

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

    Signer public dummyRootSigner = Signer(dummyP256PubKeyXRoot, dummyP256PubKeyYRoot);
    Signer public dummySigner1 = Signer(dummyP256PubKeyX1, dummyP256PubKeyY1);
    Signer public dummySigner2 = Signer(dummyP256PubKeyX2, dummyP256PubKeyY2);

    Policy public dummyAdminPolicy;
    Policy public dummy1EtherPolicy;
    Policy public dummy5EtherPolicy;
    uint112 constant rootPolicyId = 0;

    Action public dummySendMax1EtherAction;
    Action public dummySendMax5EtherAction;
    uint24 constant rootActionId = 0;

    uint224 constant rootRoleId = 0;

    constructor() {
        dummyAdminPolicy.mode = MODE_ADMIN;

        dummy1EtherPolicy.allowActions = rootActionId + 1;
        dummy5EtherPolicy.allowActions = rootActionId + 2;

        dummySendMax1EtherAction.payableValue = 1 ether;
        dummySendMax1EtherAction.payableOperator = OPERATOR_LTE;
        dummySendMax5EtherAction.payableValue = 5 ether;
        dummySendMax5EtherAction.payableOperator = OPERATOR_LTE;
    }

    function _execUserOp(address target, uint256 value, bytes memory data) internal {
        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: data,
            txValidator: address(validator)
        });
        (bytes32 r, bytes32 s) = vm.signP256(dummyP256PrivateKeyRoot, userOpData.userOpHash);
        userOpData.userOp.signature = abi.encode(rootRoleId, uint256(r), uint256(s));
        userOpData.execUserOps();
    }

    function _formatERC1271Hash(address validator, bytes32 hash) internal returns (bytes32) {
        return instance.formatERC1271Hash(validator, hash);
    }

    function _verifyERC1271Signature(
        address validator,
        bytes32 hash,
        bytes memory signature
    )
        internal
        returns (bool)
    {
        return instance.isValidSignature({ validator: validator, hash: hash, signature: signature });
    }

    function _installModule() internal {
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(dummyP256PubKeyXRoot, dummyP256PubKeyYRoot)
        });
    }

    function _uninstallModule() internal {
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });
    }

    function setUp() public {
        init();

        // Create the validator
        validator = new IAMValidator();
        vm.label(address(validator), "IAMValidator");

        // Create the account and install the validator
        instance = makeAccountInstance("MainAccount");
        vm.deal(address(instance.account), 10 ether);
        _installModule();
    }
}
