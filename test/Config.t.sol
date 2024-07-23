// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator, Signer } from "src/IAMValidator.sol";

contract ConfigTest is TestHelper {
    function testExecOk() public {
        address target = makeAddr("target");
        uint256 value = 1 ether;
        uint256 prevBalance = target.balance;

        _execUserOp(target, value, "");

        assertEq(target.balance, prevBalance + value);
    }

    function testReinstallResetsState() public {
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
            abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX2, testP256PubKeyY2
            )
        );
        _uninstallModule();
        Signer memory sRoot = validator.getSigner(address(instance.account), rootSignerId);
        Signer memory s1 = validator.getSigner(address(instance.account), rootSignerId + 1);
        Signer memory s2 = validator.getSigner(address(instance.account), rootSignerId + 2);
        assertEqUint(sRoot.x, 0);
        assertEqUint(sRoot.y, 0);
        assertEqUint(s1.x, 0);
        assertEqUint(s1.y, 0);
        assertEqUint(s2.x, 0);
        assertEqUint(s2.y, 0);

        _installModule();
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
            abi.encodeWithSelector(
                IAMValidator.addSigner.selector, testP256PubKeyX2, testP256PubKeyY2
            )
        );
        sRoot = validator.getSigner(address(instance.account), rootSignerId);
        s1 = validator.getSigner(address(instance.account), rootSignerId + 1);
        s2 = validator.getSigner(address(instance.account), rootSignerId + 2);
        assertEqUint(sRoot.x, testP256PublicKeyXRoot);
        assertEqUint(sRoot.y, testP256PublicKeyYRoot);
        assertEqUint(s1.x, testP256PubKeyX1);
        assertEqUint(s1.y, testP256PubKeyY1);
        assertEqUint(s2.x, testP256PubKeyX2);
        assertEqUint(s2.y, testP256PubKeyY2);
    }
}
