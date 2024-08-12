// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { TestHelper } from "test/TestHelper.sol";
import { ContextQueue } from "src/ContextQueue.sol";

contract ContextQueueTest is TestHelper {
    function _enqueueForPrank(uint256 value) external {
        ContextQueue.enqueue(msg.sender, value);
    }

    function _dequeueForPrank() external returns (uint256) {
        return ContextQueue.dequeue(msg.sender);
    }

    function testFIFOLogic() public {
        uint256 first = 1;
        uint256 second = 2;
        uint256 third = 3;
        ContextQueue.enqueue(msg.sender, first);
        ContextQueue.enqueue(msg.sender, second);
        ContextQueue.enqueue(msg.sender, third);

        assertTrue(ContextQueue.dequeue(msg.sender) == first);
        assertTrue(ContextQueue.dequeue(msg.sender) == second);
        assertTrue(ContextQueue.dequeue(msg.sender) == third);
    }

    function testParallelFIFOLogic() public {
        uint256 first = 1;
        uint256 second = 2;
        uint256 third = 3;
        address account1 = address(1);
        address account2 = address(2);

        vm.prank(account1);
        this._enqueueForPrank(first);
        vm.prank(account2);
        this._enqueueForPrank(first);

        vm.prank(account1);
        this._enqueueForPrank(second);
        vm.prank(account2);
        this._enqueueForPrank(second);

        vm.prank(account1);
        this._enqueueForPrank(third);
        vm.prank(account2);
        this._enqueueForPrank(third);

        vm.startPrank(account1);
        assertTrue(this._dequeueForPrank() == first);
        assertTrue(this._dequeueForPrank() == second);
        assertTrue(this._dequeueForPrank() == third);
        vm.stopPrank();

        vm.startPrank(account2);
        assertTrue(this._dequeueForPrank() == first);
        assertTrue(this._dequeueForPrank() == second);
        assertTrue(this._dequeueForPrank() == third);
        vm.stopPrank();
    }
}
