// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { AccountType } from "modulekit/test/RhinestoneModuleKit.sol";
import { TestHelper } from "test/TestHelper.sol";
import { AccessCtl } from "src/AccessCtl.sol";
import { Signer, SignerLib } from "src/Signer.sol";

contract ConfigTest is TestHelper {
    using SignerLib for Signer;

    function testExecOk() public {
        address target = makeAddr("target");
        uint256 value = 1 ether;
        uint256 prevBalance = target.balance;

        _execUserOp(target, value, "");

        assertEq(target.balance, prevBalance + value);
    }

    function testReinstallResetsState() public {
        // TODO: Remove this once modulekit updates Kernel to v3.1.
        // Kernel 3.0 has an issue that causes this test to fail.
        if (instance.accountType == AccountType.KERNEL) return;

        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(
                AccessCtl.addWebAuthnSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
            )
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(
                AccessCtl.addWebAuthnSigner.selector, dummyP256PubKeyX2, dummyP256PubKeyY2
            )
        );
        _uninstallModule();
        assertTrue(module.getSigner(address(instance.account), rootSignerId).isNull());
        assertTrue(module.getSigner(address(instance.account), rootSignerId + 1).isNull());
        assertTrue(module.getSigner(address(instance.account), rootSignerId + 2).isNull());

        _installModuleWithWebAuthn();
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(
                AccessCtl.addWebAuthnSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
            )
        );
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(
                AccessCtl.addWebAuthnSigner.selector, dummyP256PubKeyX2, dummyP256PubKeyY2
            )
        );
        assertTrue(
            module.getSigner(address(instance.account), rootSignerId).isEqual(dummyRootSigner)
        );
        assertTrue(
            module.getSigner(address(instance.account), rootSignerId + 1).isEqual(dummySigner1)
        );
        assertTrue(
            module.getSigner(address(instance.account), rootSignerId + 2).isEqual(dummySigner2)
        );
    }

    function testInstallWithECDSA() public {
        // TODO: Remove this once modulekit updates Kernel to v3.1.
        // Kernel 3.0 has an issue that causes this test to fail.
        if (instance.accountType == AccountType.KERNEL) return;

        _uninstallModule();
        _installModuleWithECDSA();
    }
}
