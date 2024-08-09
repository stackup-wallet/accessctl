// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

library ContextQueue {
    /**
     * For calculating ERC-7562 compliant transient storage slots using
     * `keccak(A||x) + n`, where A is the smart account address.
     */
    bytes32 internal constant x = 0x00000000000000000000000000000000000000000000000000000000000010F1;

    function enqueue(uint256 value) public {
        (uint128 start, uint128 end) = _parseRef(_tloadRef());

        _tstoreRef(_packRef(start, end + 1));
        _tstoreMap(end, value);
    }

    function dequeue() public returns (uint256 value) {
        (uint128 start, uint128 end) = _parseRef(_tloadRef());

        _tstoreRef(_packRef(start + 1, end));
        value = _tloadMap(start);
    }

    function _tloadRef() internal view returns (uint256 ref) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ref := tload(caller())
        }
    }

    function _tloadMap(uint256 n) internal view returns (uint256 ref) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, caller())
            mstore(add(ptr, 0x20), x)

            let hash := keccak256(ptr, 0x40)
            let slot := add(hash, n)

            ref := tload(slot)
        }
    }

    function _tstoreRef(uint256 value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            tstore(caller(), value)
        }
    }

    function _tstoreMap(uint256 n, uint256 value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, caller())
            mstore(add(ptr, 0x20), x)

            let hash := keccak256(ptr, 0x40)
            let slot := add(hash, n)

            tstore(slot, value)
        }
    }

    function _packRef(uint128 start, uint128 end) internal pure returns (uint256) {
        return uint256(start) | (uint256(end) << 128);
    }

    function _parseRef(uint256 data) internal pure returns (uint128 start, uint128 end) {
        start = uint128(data);
        end = uint128(data >> 128);
    }
}
