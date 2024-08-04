// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/**
 * An enum to track the valid states of module initialization.
 * v - validator
 * h - hook
 * 0 - uninitialized
 * 1 - initialized
 * Example: v1h0 means validator is initialized but hook is uninitialized.
 */
enum InitPhase {
    v0h0,
    v1h0,
    v0h1,
    v1h1
}
