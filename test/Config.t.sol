// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { IAMValidator } from "src/IAMValidator.sol";
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

    // TODO: fix below for Safe and Kernel test cases
    function testReinstallResetsState() public {
        // _execUserOp(
        //     address(validator),
        //     0,
        //     abi.encodeWithSelector(
        //         IAMValidator.addSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
        //     )
        // );
        // _execUserOp(
        //     address(validator),
        //     0,
        //     abi.encodeWithSelector(
        //         IAMValidator.addSigner.selector, dummyP256PubKeyX2, dummyP256PubKeyY2
        //     )
        // );
        // _uninstallModule();
        // assertTrue(validator.getSigner(address(instance.account), rootSignerId).isNull());
        // assertTrue(validator.getSigner(address(instance.account), rootSignerId + 1).isNull());
        // assertTrue(validator.getSigner(address(instance.account), rootSignerId + 2).isNull());

        // _installModule();
        // _execUserOp(
        //     address(validator),
        //     0,
        //     abi.encodeWithSelector(
        //         IAMValidator.addSigner.selector, dummyP256PubKeyX1, dummyP256PubKeyY1
        //     )
        // );
        // _execUserOp(
        //     address(validator),
        //     0,
        //     abi.encodeWithSelector(
        //         IAMValidator.addSigner.selector, dummyP256PubKeyX2, dummyP256PubKeyY2
        //     )
        // );
        // assertTrue(
        //     validator.getSigner(address(instance.account), rootSignerId).isEqual(dummyRootSigner)
        // );
        // assertTrue(
        //     validator.getSigner(address(instance.account), rootSignerId +
        // 1).isEqual(dummySigner1)
        // );
        // assertTrue(
        //     validator.getSigner(address(instance.account), rootSignerId +
        // 2).isEqual(dummySigner2)
        // );
    }
}
