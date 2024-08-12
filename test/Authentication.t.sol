// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { TestHelper } from "test/TestHelper.sol";
import { IAMModule } from "src/IAMModule.sol";
import { Signer, SignerLib, MODE_WEBAUTHN, MODE_ECDSA } from "src/Signer.sol";

contract AuthenticationTest is TestHelper {
    using SignerLib for Signer;
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    function testAddSignerWritesToState() public {
        uint112 expectedSignerId = rootSignerId + 1;
        Signer memory s = module.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isNull());

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(
                IAMModule.addWebAuthnSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
            )
        );

        s = module.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isEqual(dummySigner1));
    }

    function testAddSignerEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(module));
        emit SignerAdded(
            address(this),
            rootSignerId,
            Signer(dummyP256PubKeyX1, dummyP256PubKeyY1, address(0), MODE_WEBAUTHN)
        );
        module.addWebAuthnSigner(dummyP256PubKeyX1, dummyP256PubKeyY1);

        vm.expectEmit(true, true, true, true, address(module));
        emit SignerAdded(
            address(this),
            rootSignerId + 1,
            Signer(dummyP256PubKeyX2, dummyP256PubKeyY2, address(0), MODE_WEBAUTHN)
        );
        module.addWebAuthnSigner(dummyP256PubKeyX2, dummyP256PubKeyY2);

        vm.expectEmit(true, true, true, true, address(module));
        emit SignerAdded(address(this), rootSignerId + 2, Signer(0, 0, member.addr, MODE_ECDSA));
        module.addECDSASigner(member.addr);
    }

    function testRemoveSignerWritesToState() public {
        uint112 expectedSignerId = rootSignerId + 1;
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(
                IAMModule.addWebAuthnSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
            )
        );

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.removeSigner.selector, expectedSignerId)
        );
        Signer memory s = module.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isNull());
    }

    function testRemoveSignerEmitsEvent() public {
        module.addWebAuthnSigner(dummyP256PubKeyX1, dummyP256PubKeyY1);
        module.addWebAuthnSigner(dummyP256PubKeyX2, dummyP256PubKeyY2);

        vm.expectEmit(true, true, true, true, address(module));
        emit SignerRemoved(address(this), rootSignerId);
        module.removeSigner(rootSignerId);

        vm.expectEmit(true, true, true, true, address(module));
        emit SignerRemoved(address(this), rootSignerId + 1);
        module.removeSigner(rootSignerId + 1);
    }

    function testOrphanedSignerShouldRevert() public {
        // TODO: check why SIMULATE test doesn't catch validateUserOp revert.
        if (vm.envOr("SIMULATE", false)) return;

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.removeSigner.selector, rootSignerId)
        );
        address target = makeAddr("target");
        uint256 initBalance = target.balance;

        instance.expect4337Revert();
        _execUserOp(target, 1 ether, "");
        assertEq(target.balance, initBalance);
    }

    function testECDSASignerOk() public {
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addECDSASigner.selector, member.addr)
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addRole.selector, rootSignerId + 1, rootPolicyId)
        );

        address target = makeAddr("target");
        uint256 value = 1 ether;
        uint256 initBalance = target.balance;
        uint224 roleId = uint224(rootSignerId + 1) | (uint224(rootPolicyId) << 112);

        _execUserOpWithECDSA(roleId, member.key, target, value, "");
        assertEq(target.balance, initBalance + value);
    }

    function testECDSASignerFail() public {
        // TODO: check why SIMULATE test doesn't catch validateUserOp revert.
        if (vm.envOr("SIMULATE", false)) return;

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addECDSASigner.selector, member.addr)
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(IAMModule.addRole.selector, rootSignerId + 1, rootPolicyId)
        );

        address target = makeAddr("target");
        uint256 value = 1 ether;
        uint256 initBalance = target.balance;
        uint224 roleId = uint224(rootSignerId + 1) | (uint224(rootPolicyId) << 112);
        Account memory fake = makeAccount("fake");

        instance.expect4337Revert();
        _execUserOpWithECDSA(roleId, fake.key, target, value, "");
        assertEq(target.balance, initBalance);
    }
}
