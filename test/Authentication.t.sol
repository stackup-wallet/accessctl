// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMModule } from "src/IAMModule.sol";
import { Signer, SignerLib } from "src/Signer.sol";

contract AuthenticationTest is TestHelper {
    using SignerLib for Signer;

    function testAddSignerWritesToState() public {
        uint112 expectedSignerId = rootSignerId + 1;
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isNull());

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMModule.addSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
            )
        );

        s = validator.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isEqual(dummySigner1));
    }

    function testAddSignerEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), rootSignerId, dummyP256PubKeyX1, dummyP256PubKeyY1);
        validator.addSigner(dummyP256PubKeyX1, dummyP256PubKeyY1);

        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), rootSignerId + 1, dummyP256PubKeyX2, dummyP256PubKeyY2);
        validator.addSigner(dummyP256PubKeyX2, dummyP256PubKeyY2);
    }

    function testRemoveSignerWritesToState() public {
        uint112 expectedSignerId = rootSignerId + 1;
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMModule.addSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
            )
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMModule.removeSigner.selector, expectedSignerId)
        );
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertTrue(s.isNull());
    }

    function testRemoveSignerEmitsEvent() public {
        validator.addSigner(dummyP256PubKeyX1, dummyP256PubKeyY1);
        validator.addSigner(dummyP256PubKeyX2, dummyP256PubKeyY2);

        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerRemoved(address(this), rootSignerId);
        validator.removeSigner(rootSignerId);

        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerRemoved(address(this), rootSignerId + 1);
        validator.removeSigner(rootSignerId + 1);
    }
}
