// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/**
 * This is the same id assigned to a smart-session "Session". A session in our
 * use case can be validated by multiple independent passkeys. Therefore a session
 * will pass its permissionId to validateSignatureWithData in order to lookup the
 * correct mapping to find the relevant signer in.
 */
type PermissionId is bytes32;

/**
 * This id is packed into the sig value thats passed into validateSignatureWithData.
 * Along with the permissionId, it tells the SessionValidator exactly which public
 * key to validate the signature against.
 */
type SignerId is bytes32;

/**
 * This is the hash of a permissionId and signerId to prevent three levels of
 * mapping in the signers storage.
 */
type HashedPermissionAndSignerIds is bytes32;
