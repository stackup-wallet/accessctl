// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator, Signer } from "src/IAMValidator.sol";

contract AuthenticationTest is TestHelper {
    function testAddSignerWritesToState() public {
        uint24 expectedSignerId = rootSignerId + 1;
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, 0);
        assertEqUint(s.y, 0);

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX1, testP256PubKeyY1
            )
        );

        s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, testP256PubKeyX1);
        assertEqUint(s.y, testP256PubKeyY1);
    }

    function testAddSignerEmitsEvent() public {
        uint24 expectedSignerId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId, testP256PubKeyX1, testP256PubKeyY1);
        validator.addSigner(testP256PubKeyX1, testP256PubKeyY1);

        uint24 expectedSignerId1 = 1;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerAdded(address(this), expectedSignerId1, testP256PubKeyX2, testP256PubKeyY2);
        validator.addSigner(testP256PubKeyX2, testP256PubKeyY2);
    }

    function testRemoveSignerWritesToState() public {
        uint24 expectedSignerId = rootSignerId + 1;
        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX1, testP256PubKeyY1
            )
        );

        _execUserOp(
            address(validator),
            0,
            abi.encodeWithSelector(IAMValidator.removeSigner.selector, expectedSignerId)
        );
        Signer memory s = validator.getSigner(address(instance.account), expectedSignerId);
        assertEqUint(s.x, 0);
        assertEqUint(s.y, 0);
    }

    function testRemoveSignerEmitsEvent() public {
        uint24 expectedSignerId = 0;
        vm.expectEmit(true, true, true, true, address(validator));
        emit SignerRemoved(address(this), expectedSignerId);
        validator.removeSigner(expectedSignerId);
    }
}
