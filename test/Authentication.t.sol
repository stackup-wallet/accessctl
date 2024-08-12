// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { TestHelper } from "test/TestHelper.sol";
import { IAMModule } from "src/IAMModule.sol";
import { Signer, SignerLib } from "src/Signer.sol";

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
                IAMModule.addSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
            )
        );

        s = module.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isEqual(dummySigner1));
    }

    function testAddSignerEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(module));
        emit SignerAdded(address(this), rootSignerId, dummyP256PubKeyX1, dummyP256PubKeyY1);
        module.addSigner(dummyP256PubKeyX1, dummyP256PubKeyY1);

        vm.expectEmit(true, true, true, true, address(module));
        emit SignerAdded(address(this), rootSignerId + 1, dummyP256PubKeyX2, dummyP256PubKeyY2);
        module.addSigner(dummyP256PubKeyX2, dummyP256PubKeyY2);
    }

    function testRemoveSignerWritesToState() public {
        uint112 expectedSignerId = rootSignerId + 1;
        _execUserOp(
            address(module),
            0,
            abi.encodeWithSelector(
                IAMModule.addSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
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
        module.addSigner(dummyP256PubKeyX1, dummyP256PubKeyY1);
        module.addSigner(dummyP256PubKeyX2, dummyP256PubKeyY2);

        vm.expectEmit(true, true, true, true, address(module));
        emit SignerRemoved(address(this), rootSignerId);
        module.removeSigner(rootSignerId);

        vm.expectEmit(true, true, true, true, address(module));
        emit SignerRemoved(address(this), rootSignerId + 1);
        module.removeSigner(rootSignerId + 1);
    }

    function testOrphanedSignerShouldRevert() public {
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
}
