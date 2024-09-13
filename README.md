# AccessControl

> **⚠️ This module is still in early development. It is not yet recommended for production.**

AccessControl (or `AccessCtl` for short) builds of the [Smart Sessions module](https://github.com/erc7579/smartsessions) to enable role-based access control (RBAC) for ERC-7579 smart accounts.

## Module status

AccessCtl is deployed using the [deterministic deployment proxy](https://github.com/Arachnid/deterministic-deployment-proxy) and has the same address on all chains.

| Contract                                                                            | Version | Address | Commit | Audit |
| ----------------------------------------------------------------------------------- | ------- | ------- | ------ | ----- |
| [`WebAuthnValidator.sol`](./src/signers/WebAuthnValidator.sol)                      | `0.1.0` | ``      | []()   | N/A   |
| [`IntervalSpendingLimitPolicy.sol`](./src/policies/IntervalSpendingLimitPolicy.sol) | `0.1.0` | ``      | []()   | N/A   |

## Compatibility status

A "✅" means that AccessCtl has been end to end tested with the following Smart Account versions and confirmed compatible.

|         | Kernel `v3.1` | Safe7579 `v1.0.2` | Nexus |
| ------- | ------------- | ----------------- | ----- |
| `0.1.0` | ✅            | ❌                | ❌    |

# Architecture

This project refers to a collection of session validators and policies to extend the ERC-7579 Smart Sessions module. The extensions are built with the following design goals in mind to support onchain organizations at every scale:

- **Authentication**: support for adding signers to specific roles on a smart account.
- **Authorization**: support for adding custom policies to each role.
- **Gas optimized**: can scale for a large number of active roles, signers, and policies.
- **Easily auditable**: allows verifiable changelogs for tracking every validation update.

The remaining documentation will assume knowledge on ERC-4337 (Account Abstraction), ERC-7579 (Minimal Modular Smart Accounts), and Smart Sessions. If you are unfamiliar, we recommend the following resources to get started:

- [erc4337.io](https://www.erc4337.io/docs)
- [erc7579.com](https://erc7579.com/)
- [Smart Sessions](https://github.com/erc7579/smartsessions)

## End to end transaction flow

The following is a sequence diagram to illustrate the end to end flow of a `UserOperation`.

```mermaid
sequenceDiagram
    Wallet->>EntryPoint:Send UserOp
    EntryPoint->>Smart Account: Calls validateUserOp
    Smart Account->>Smart Sessions: Proxy request
    Note over Policy: Authorization check
    loop for each policy in session
        alt is userOp Policy
            Smart Sessions->>Policy: Calls checkUserOpPolicy
            Policy->>Policy: Verifies userOp
            Policy->>Smart Sessions: Returns validation data
        else is action
            Smart Sessions->>Policy: Calls checkAction
            Policy->>Policy: Verifies action
            Policy->>Smart Sessions: Returns validation data
        end
    end
    Smart Sessions->>Smart Sessions: Calculates intersected validation data
    Smart Sessions->>WebAuthn Validator: Calls validateSignatureWithData
    Note over WebAuthn Validator: Authentication check
    WebAuthn Validator->>WebAuthn Validator: Verifies webAuthn signature
    WebAuthn Validator->>Smart Sessions: Returns success response
    Smart Sessions->>Smart Account: Returns success response
    Smart Account->>EntryPoint: Pay prefund
    Note over EntryPoint,Smart Account: Validation done, execution next...
```

### `WebAuthnValidator.sol`

The [WebAuthnValidator.sol](./src/signers/WebAuthnValidator.sol) is a minimal wrapper around [webauthn-sol](https://github.com/base-org/webauthn-sol) to enable compatibility with the required smart session interface. This allows sessions to be authenticated directly with an end user's passkey.

### `IntervalSpendingLimitPolicy.sol`

the [IntervalSpendingLimitPolicy](./src/policies/IntervalSpendingLimitPolicy.sol) is fork of [SpendingLimitPolicy.sol](https://github.com/erc7579/smartsessions/blob/main/contracts/external/policies/SpendingLimitPolicy.sol). The difference is the inclusion of added logic to reset the accrued spend after a defined interval.

> **Note that this policy relies on the `TIMESTAMP` opcode during validation which is not compliant with the canonical mempool. This is required to ensure time intervals work as expected.**

# Contributing

This project requires [Foundry](https://book.getfoundry.sh/) to be installed. If you're developing with VSCode, we also recommend using the [Solidity extension by Nomic Foundation](https://github.com/NomicFoundation/hardhat-vscode).

## Install dependencies

Install `node_modules`:

```shell
pnpm install
```

Install foundry submodules:

```shell
forge install
```

## Building modules

All smart contracts live under the [src](./src/) directory.

```shell
forge build
```

## Testing modules

All tests live under the [test](./test/) directory.

```shell
forge test
```

## Deploying the module

1. Import your modules into the `script/DeployModule.s.sol` file.
2. Create a `.env` file in the root directory based on the `.env.example` file and fill in the variables.
3. Run the following command:

```shell
source .env && forge script script/DeployModule.s.sol:DeployModuleScript --rpc-url $DEPLOYMENT_RPC --broadcast --sender $DEPLOYMENT_SENDER --verify
```

Your module is now deployed to the blockchain and verified on Etherscan.

If the verification fails, you can manually verify it on Etherscan using the following command:

```shell
source .env && forge verify-contract --chain-id [YOUR_CHAIN_ID] --watch --etherscan-api-key $ETHERSCAN_API_KEY [YOUR_MODULE_ADDRESS] src/[PATH_TO_MODULE].sol:[MODULE_CONTRACT_NAME]
```

# License

Distributed under the GPL-3.0 License. See [LICENSE](./LICENSE) for more information.
