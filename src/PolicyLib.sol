// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { Policy, ADMIN_MODE } from "src/Policy.sol";

library PolicyLib {
    function isNull(Policy calldata p) public pure returns (bool) {
        return p.validFrom == 0 && p.validUntil == 0 && p.erc1271Caller == address(0) && p.mode == 0
            && p.reserved == 0 && p.callTarget == address(0) && p.callSelector == 0
            && p.callValueOperator == 0 && p.callValue == 0 && p.callInputs.length == 0;
    }

    function verify(Policy calldata p, PackedUserOperation calldata) public pure returns (bool) {
        if (_isAdmin(p.mode)) {
            return true;
        }

        return false;
    }

    function _isAdmin(bytes1 mode) internal pure returns (bool) {
        return mode == ADMIN_MODE;
    }
}
