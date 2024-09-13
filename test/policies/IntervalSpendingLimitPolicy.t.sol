// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "smart-sessions/DataTypes.sol";
import { TestHelper } from "test/TestHelper.sol";
import {
    IntervalSpendingLimitPolicy,
    Intervals,
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
        dummyValues.push(1 ether);
    }

    function assertForInterval(
        Intervals interval,
        uint256 currentIntervalEnd,
        uint256 nextIntervalEnd
    )
        public
    {
        // Initialize policy
        vm.warp(dummyCurrentTimestamp);
        spendingLimitPolicy.initializeWithMultiplexer(
            dummyAccount, dummyConfigId, abi.encode(interval, dummyTokens, dummyValues)
        );

        // Spend up to the max
        vm.expectEmit(true, true, true, true, address(spendingLimitPolicy));
        emit TokenSpent(dummyConfigId, address(this), dummyTokens[0], dummyAccount, 1 ether, 0);
        uint256 vd = spendingLimitPolicy.checkAction(
            dummyConfigId,
            dummyAccount,
            dummyTokens[0],
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0), 1 ether)
        );
        assertEq(vd, VALIDATION_SUCCESS);

        // Over spend should fail even a second before new time interval
        vm.warp(DateTimeLib.subSeconds(currentIntervalEnd, 1));
        vd = spendingLimitPolicy.checkAction(
            dummyConfigId,
            dummyAccount,
            dummyTokens[0],
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0), 1 ether)
        );
        assertEq(vd, VALIDATION_FAILED);

        // Spend is reset right at the new time interval
        vm.warp(currentIntervalEnd);
        vm.expectEmit(true, true, true, true, address(spendingLimitPolicy));
        emit IntervalUpdated(
            dummyConfigId,
            address(this),
            dummyTokens[0],
            dummyAccount,
            currentIntervalEnd,
            nextIntervalEnd
        );
        vd = spendingLimitPolicy.checkAction(
            dummyConfigId,
            dummyAccount,
            dummyTokens[0],
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0), 1 ether)
        );
        assertEq(vd, VALIDATION_SUCCESS);

        // Over spend should fail again in the new time interval
        vm.warp(DateTimeLib.addSeconds(currentIntervalEnd, 1));
        vd = spendingLimitPolicy.checkAction(
            dummyConfigId,
            dummyAccount,
            dummyTokens[0],
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0), 1 ether)
        );
        assertEq(vd, VALIDATION_FAILED);
    }

    function testCheckActionMontly() public {
        assertForInterval(
            Intervals.Monthly, dummyCurrentMonthlyIntervalEnd, dummyNextMonthlyIntervalEnd
        );
    }

    function testCheckActionWeekly() public {
        assertForInterval(
            Intervals.Weekly, dummyCurrentWeeklyIntervalEnd, dummyNextWeeklyIntervalEnd
        );
    }

    function testCheckActionDaily() public {
        assertForInterval(Intervals.Daily, dummyCurrentDailyIntervalEnd, dummyNextDailyIntervalEnd);
    }
}
