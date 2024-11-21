// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { ConfigId } from "smart-sessions/DataTypes.sol";
import {
    IUserOpPolicy,
    IActionPolicy,
    I1271Policy,
    IPolicy,
    VALIDATION_SUCCESS
} from "smart-sessions/interfaces/IPolicy.sol";
import { IERC165 } from "forge-std/interfaces/IERC165.sol";
import { EnumerableSet } from "smart-sessions/utils/EnumerableSet4337.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

/**
 * This contract is a fork of SudoPolicy.sol from erc7579/smartsessions.
 * The difference is the added compatibility with the IUserOpPolicy interface.
 * See https://github.com/erc7579/smartsessions/pull/145 for details.
 */
contract SudoPolicy is IUserOpPolicy, IActionPolicy, I1271Policy {
    function initializeWithMultiplexer(
        address account,
        ConfigId configId,
        bytes calldata /*initData*/
    )
        external
    {
        emit IPolicy.PolicySet(configId, msg.sender, account);
    }

    function checkUserOpPolicy(
        ConfigId, /*id*/
        PackedUserOperation calldata /*userOp*/
    )
        external
        pure
        returns (uint256)
    {
        return VALIDATION_SUCCESS;
    }

    function checkAction(
        ConfigId, /*id*/
        address, /*account*/
        address, /*target*/
        uint256, /*value*/
        bytes calldata /*data*/
    )
        external
        pure
        override
        returns (uint256)
    {
        return VALIDATION_SUCCESS;
    }

    function check1271SignedAction(
        ConfigId, /*id*/
        address, /*requestSender*/
        address, /*account*/
        bytes32, /*hash*/
        bytes calldata /*signature*/
    )
        external
        pure
        returns (bool)
    {
        return true;
    }

    function supportsInterface(bytes4 interfaceID) external pure override returns (bool) {
        return interfaceID == type(IUserOpPolicy).interfaceId
            || interfaceID == type(IActionPolicy).interfaceId
            || interfaceID == type(I1271Policy).interfaceId || interfaceID == type(IERC165).interfaceId
            || interfaceID == type(IPolicy).interfaceId;
    }
}
