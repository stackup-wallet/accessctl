// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "smart-sessions/DataTypes.sol";
import { TestHelper } from "test/TestHelper.sol";
import {
    IntervalSpendingLimitPolicy,
    Intervals,
    NATIVE_TOKEN,
    VALIDATION_SUCCESS,
    VALIDATION_FAILED
} from "src/policies/IntervalSpendingLimitPolicy.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { DateTimeLib } from "solady/utils/DateTimeLib.sol";

contract IntervalSpendingLimitPolicyTest is TestHelper {
    ConfigId internal constant dummyConfigId = ConfigId.wrap(bytes32(uint256(0xbeef)));
    address internal constant dummyAccount = address(0xdead);

    // Saturday, 14 September 2024 06:35:55 GMT
    uint256 internal constant dummyCurrentTimestamp = 1_726_295_755;

    // Tuesday, 1 October 2024 00:00:00 GMT
    uint256 internal constant dummyCurrentMonthlyIntervalEnd = 1_727_740_800;

    // Monday, 16 September 2024 00:00:00 GMT
    uint256 internal constant dummyCurrentWeeklyIntervalEnd = 1_726_444_800;

    // Sunday, 15 September 2024 00:00:00 GMT
    uint256 internal constant dummyCurrentDailyIntervalEnd = 1_726_358_400;

    // Friday, 1 November 2024 00:00:00 GMT
    uint256 internal constant dummyNextMonthlyIntervalEnd = 1_730_419_200;

    // Monday, 23 September 2024 00:00:00 GMT
    uint256 internal constant dummyNextWeeklyIntervalEnd = 1_727_049_600;

    // Monday, 16 September 2024 00:00:00 GMT
    uint256 internal constant dummyNextDailyIntervalEnd = 1_726_444_800;

    address[] internal dummyTokens;
    address[] internal nativeTokens;
    uint256[] internal dummyValues;

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

    constructor() {
        dummyTokens.push(address(0xcafe));
        nativeTokens.push(NATIVE_TOKEN);
        dummyValues.push(1 ether);
    }

    function assertForInterval(
        bool isNative,
        bool isErc20Payable,
        Intervals interval,
        uint256 currentIntervalEnd,
        uint256 nextIntervalEnd
    )
        public
    {
        address[] memory tokens;
        address target;
        uint256 value;
        bytes memory callData;
        if (isNative) {
            tokens = nativeTokens;
            target = address(0);
            value = 1 ether;
        } else if (isErc20Payable) {
            tokens = dummyTokens;
            target = dummyTokens[0];
            value = 1 ether;
            callData = abi.encodeWithSelector(IERC20.transfer.selector, address(0), 1 ether);
        } else {
            // ERC20 base case
            tokens = dummyTokens;
            target = dummyTokens[0];
            value = 0;
            callData = abi.encodeWithSelector(IERC20.transfer.selector, address(0), 1 ether);
        }

        // Initialize policy
        vm.warp(dummyCurrentTimestamp);
        spendingLimitPolicy.initializeWithMultiplexer(
            dummyAccount, dummyConfigId, abi.encode(interval, tokens, dummyValues)
        );

        // Spend up to the max
        uint256 vd;
        if (isErc20Payable) {
            vd = spendingLimitPolicy.checkAction(
                dummyConfigId, dummyAccount, target, value, callData
            );
            assertEq(vd, VALIDATION_FAILED);
            return;
        }
        vm.expectEmit(true, true, true, true, address(spendingLimitPolicy));
        emit TokenSpent(dummyConfigId, address(this), tokens[0], dummyAccount, 1 ether, 0);
        vd = spendingLimitPolicy.checkAction(dummyConfigId, dummyAccount, target, value, callData);
        assertEq(vd, VALIDATION_SUCCESS);

        // Over spend should fail even a second before new time interval
        vm.warp(DateTimeLib.subSeconds(currentIntervalEnd, 1));
        vd = spendingLimitPolicy.checkAction(dummyConfigId, dummyAccount, target, value, callData);
        assertEq(vd, VALIDATION_FAILED);

        // Spend is reset right at the new time interval
        vm.warp(currentIntervalEnd);
        vm.expectEmit(true, true, true, true, address(spendingLimitPolicy));
        emit IntervalUpdated(
            dummyConfigId,
            address(this),
            tokens[0],
            dummyAccount,
            currentIntervalEnd,
            nextIntervalEnd
        );
        vd = spendingLimitPolicy.checkAction(dummyConfigId, dummyAccount, target, value, callData);
        assertEq(vd, VALIDATION_SUCCESS);

        // Over spend should fail again in the new time interval
        vm.warp(DateTimeLib.addSeconds(currentIntervalEnd, 1));
        vd = spendingLimitPolicy.checkAction(dummyConfigId, dummyAccount, target, value, callData);
        assertEq(vd, VALIDATION_FAILED);
    }

    function testCheckActionMonthlyForERC20() public {
        assertForInterval({
            isNative: false,
            isErc20Payable: false,
            interval: Intervals.Monthly,
            currentIntervalEnd: dummyCurrentMonthlyIntervalEnd,
            nextIntervalEnd: dummyNextMonthlyIntervalEnd
        });
    }

    function testCheckActionWeeklyForERC20() public {
        assertForInterval({
            isNative: false,
            isErc20Payable: false,
            interval: Intervals.Weekly,
            currentIntervalEnd: dummyCurrentWeeklyIntervalEnd,
            nextIntervalEnd: dummyNextWeeklyIntervalEnd
        });
    }

    function testCheckActionDailyForERC20() public {
        assertForInterval({
            isNative: false,
            isErc20Payable: false,
            interval: Intervals.Daily,
            currentIntervalEnd: dummyCurrentDailyIntervalEnd,
            nextIntervalEnd: dummyNextDailyIntervalEnd
        });
    }

    function testCheckActionMonthlyForERC20Payable() public {
        assertForInterval({
            isNative: false,
            isErc20Payable: true,
            interval: Intervals.Monthly,
            currentIntervalEnd: dummyCurrentMonthlyIntervalEnd,
            nextIntervalEnd: dummyNextMonthlyIntervalEnd
        });
    }

    function testCheckActionWeeklyForERC20Payable() public {
        assertForInterval({
            isNative: false,
            isErc20Payable: true,
            interval: Intervals.Weekly,
            currentIntervalEnd: dummyCurrentWeeklyIntervalEnd,
            nextIntervalEnd: dummyNextWeeklyIntervalEnd
        });
    }

    function testCheckActionDailyForERC20Payable() public {
        assertForInterval({
            isNative: false,
            isErc20Payable: true,
            interval: Intervals.Daily,
            currentIntervalEnd: dummyCurrentDailyIntervalEnd,
            nextIntervalEnd: dummyNextDailyIntervalEnd
        });
    }

    function testCheckActionMonthlyForNativeTransfer() public {
        assertForInterval({
            isNative: true,
            isErc20Payable: false,
            interval: Intervals.Monthly,
            currentIntervalEnd: dummyCurrentMonthlyIntervalEnd,
            nextIntervalEnd: dummyNextMonthlyIntervalEnd
        });
    }

    function testCheckActionWeeklyForNativeTransfer() public {
        assertForInterval({
            isNative: true,
            isErc20Payable: false,
            interval: Intervals.Weekly,
            currentIntervalEnd: dummyCurrentWeeklyIntervalEnd,
            nextIntervalEnd: dummyNextWeeklyIntervalEnd
        });
    }

    function testCheckActionDailyForNativeTransfer() public {
        assertForInterval({
            isNative: true,
            isErc20Payable: false,
            interval: Intervals.Daily,
            currentIntervalEnd: dummyCurrentDailyIntervalEnd,
            nextIntervalEnd: dummyNextDailyIntervalEnd
        });
    }
}
