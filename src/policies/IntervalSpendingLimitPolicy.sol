// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ConfigId, ERC7579_MODULE_TYPE_POLICY } from "smart-sessions/DataTypes.sol";
import { IActionPolicy } from "smart-sessions/interfaces/IPolicy.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { DateTimeLib } from "solady/utils/DateTimeLib.sol";

address constant NATIVE_TOKEN = address(type(uint160).max);

uint256 constant VALIDATION_SUCCESS = 0;
uint256 constant VALIDATION_FAILED = 1;

enum Intervals {
    Daily,
    Weekly,
    Monthly
}

/**
 * This contract is a fork of SpendingLimitPolicy.sol from erc7579/smartsessions.
 * The difference is the inclusion of added logic to reset the accrued spend after
 * a defined interval and include native token transfers.
 *
 * Note: This policy relies on the TIMESTAMP opcode during validation which is not
 * compliant with the canonical mempool. This is required to ensure time intervals
 * work as expected.
 */
contract IntervalSpendingLimitPolicy is IActionPolicy {
    event TokenSpent(
        ConfigId id,
        address multiplexer,
        address token,
        address account,
        uint256 amount,
        uint256 remaining
    );
    event IntervalUpdated(
        ConfigId id,
        address multiplexer,
        address token,
        address account,
        uint256 previous,
        uint256 current
    );

    error InvalidTokenAddress(address token);
    error InvalidLimit(uint256 limit);

    struct TokenPolicyData {
        uint256 alreadySpent;
        uint256 spendingLimit;
        uint256 currentIntervalEnd;
        Intervals interval;
    }

    mapping(
        ConfigId id
            => mapping(
                address mulitplexer
                    => mapping(address token => mapping(address userOpSender => TokenPolicyData))
            )
    ) internal $policyData;

    function _getPolicy(
        ConfigId id,
        address userOpSender,
        address token
    )
        internal
        view
        returns (TokenPolicyData storage s)
    {
        if (token == address(0)) revert InvalidTokenAddress(token);
        s = $policyData[id][msg.sender][token][userOpSender];
    }

    function supportsInterface(bytes4 interfaceID) external pure override returns (bool) {
        if (interfaceID == type(IActionPolicy).interfaceId) {
            return true;
        }
        if (interfaceID == IActionPolicy.checkAction.selector) {
            return true;
        }

        return false;
    }

    function onInstall(bytes calldata data) external override { }

    function initializeWithMultiplexer(
        address account,
        ConfigId configId,
        bytes calldata initData
    )
        external
    {
        (Intervals interval, address[] memory tokens, uint256[] memory limits) =
            abi.decode(initData, (Intervals, address[], uint256[]));

        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 limit = limits[i];
            if (token == address(0)) revert InvalidTokenAddress(token);
            if (limit == 0) revert InvalidLimit(limit);
            TokenPolicyData storage $ =
                _getPolicy({ id: configId, userOpSender: account, token: token });
            $.spendingLimit = limit;

            $.currentIntervalEnd = _getNextIntervalTimestamp(interval);
            $.interval = interval;
        }
    }

    function onUninstall(bytes calldata data) external override { }

    function isModuleType(uint256 id) external pure returns (bool) {
        return id == ERC7579_MODULE_TYPE_POLICY;
    }

    function isInitialized(address smartAccount) external view override returns (bool) { }

    function isInitialized(address account, ConfigId id) external view override returns (bool) { }

    function isInitialized(
        address account,
        address multiplexer,
        ConfigId id
    )
        external
        view
        override
        returns (bool)
    { }

    function _isTokenTransfer(
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        pure
        returns (bool isTransfer, address token, uint256 amount)
    {
        // Detect a native ETH transfer. We don't check that value is more than
        // 0 since we assume a 0 ETH transfer is a valid use case.
        if (callData.length == 0) return (true, NATIVE_TOKEN, value);

        // Assuming callData is not nil, then value has to be 0.
        if (value != 0) return (false, address(0), 0);
        bytes4 functionSelector = bytes4(callData[0:4]);

        if (functionSelector == IERC20.approve.selector) {
            (, amount) = abi.decode(callData[4:], (address, uint256));
            return (true, target, amount);
        } else if (functionSelector == IERC20.transfer.selector) {
            (, amount) = abi.decode(callData[4:], (address, uint256));
            return (true, target, amount);
        } else if (functionSelector == IERC20.transferFrom.selector) {
            (,, amount) = abi.decode(callData[4:], (address, address, uint256));
            return (true, target, amount);
        }
        return (false, address(0), 0);
    }

    function _getNextIntervalTimestamp(Intervals interval)
        internal
        view
        returns (uint256 timestamp)
    {
        // This is the line that will violate the TIMESTAMP restriction for the
        // canonical UserOperation mempool.
        uint256 currentTimestamp = block.timestamp;

        if (interval == Intervals.Daily) {
            (uint256 currentYear, uint256 currentMonth, uint256 currentDay) =
                DateTimeLib.timestampToDate(currentTimestamp);
            timestamp = DateTimeLib.addDays(
                DateTimeLib.dateToTimestamp(currentYear, currentMonth, currentDay), 1
            );
        } else if (interval == Intervals.Weekly) {
            timestamp = DateTimeLib.addDays(DateTimeLib.mondayTimestamp(currentTimestamp), 7);
        } else if (interval == Intervals.Monthly) {
            (uint256 currentYear, uint256 currentMonth,) =
                DateTimeLib.timestampToDate(currentTimestamp);
            timestamp =
                DateTimeLib.addMonths(DateTimeLib.dateToTimestamp(currentYear, currentMonth, 1), 1);
        }
    }

    function _resetIntervalIfNeeded(
        TokenPolicyData storage $,
        ConfigId id,
        address target,
        address account
    )
        internal
    {
        uint256 nextIntervalEnd = _getNextIntervalTimestamp($.interval);
        uint256 currentIntervalEnd = $.currentIntervalEnd;
        if (nextIntervalEnd > currentIntervalEnd) {
            $.alreadySpent = 0;
            $.currentIntervalEnd = nextIntervalEnd;
            emit IntervalUpdated(
                id, msg.sender, target, account, currentIntervalEnd, nextIntervalEnd
            );
        }
    }

    function _check(
        TokenPolicyData storage $,
        ConfigId id,
        address token,
        address account,
        uint256 amount
    )
        internal
        returns (uint256)
    {
        uint256 spendingLimit = $.spendingLimit;
        uint256 alreadySpent = $.alreadySpent;

        uint256 newAmount = alreadySpent + amount;

        if (newAmount > spendingLimit) {
            return VALIDATION_FAILED;
        } else {
            $.alreadySpent = newAmount;

            emit TokenSpent(id, msg.sender, token, account, amount, spendingLimit - newAmount);
            return VALIDATION_SUCCESS;
        }
    }

    function checkAction(
        ConfigId id,
        address account,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        override
        returns (uint256)
    {
        (bool isTokenTransfer, address token, uint256 amount) =
            _isTokenTransfer(target, value, callData);
        if (!isTokenTransfer) return VALIDATION_FAILED;

        TokenPolicyData storage $ = _getPolicy({ id: id, userOpSender: account, token: token });
        _resetIntervalIfNeeded($, id, token, account);
        return _check($, id, token, account, amount);
    }
}
