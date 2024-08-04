// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMModule } from "src/IAMModule.sol";
import { Signer, SignerLib } from "src/Signer.sol";

contract AuthenticationTest is TestHelper {
    using SignerLib for Signer;

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
}
