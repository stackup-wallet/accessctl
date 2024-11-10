# Account Modules

A collection of ERC-7579 and smart session modules built and maintained by the Stackup team.

## Summary of modules

All modules are deployed using the [deterministic deployment proxy](https://github.com/Arachnid/deterministic-deployment-proxy) and have the same address on all chains.

<details>
  <summary><b>v1.0.0 (WIP)</b></summary>

| Contract                                                                            | Address                                      | Type                |
| ----------------------------------------------------------------------------------- | -------------------------------------------- | ------------------- |
| [`WebAuthnValidator.sol`](./src/session-validators/WebAuthnValidator.sol)           | `0x1B0696411bF73C01Bfdf7bcFee1282189D8C7FFf` | `ISessionValidator` |
| [`IntervalSpendingLimitPolicy.sol`](./src/policies/IntervalSpendingLimitPolicy.sol) | `0xDd2a9575952fA08B327A28c46FC314E7A86C5A99` | `IActionPolicy`     |

</details>

# Modules

The remaining section will assume knowledge on **ERC-4337 (Account Abstraction)**, **ERC-7579 (Minimal Modular Smart Accounts)**, and **Smart Sessions**. If you are unfamiliar, we recommend the following resources to get started:

- [erc4337.io](https://www.erc4337.io/docs)
- [erc7579.com](https://erc7579.com/)
- [Smart Sessions wiki](https://github.com/erc7579/smartsessions/wiki/Smart-Sessions)

## `ISessionValidator`

### [WebAuthnValidator.sol](./src/session-validators/WebAuthnValidator.sol)

A minimal wrapper around [webauthn-sol](https://github.com/base-org/webauthn-sol) to enable compatibility with smart sessions. This allows sessions to be authenticated directly with an end user's passkey.

## `IActionPolicy`

### [IntervalSpendingLimitPolicy.sol](./src/policies/IntervalSpendingLimitPolicy.sol)

A fork of [SpendingLimitPolicy.sol](https://github.com/erc7579/smartsessions/blob/main/contracts/external/policies/SpendingLimitPolicy.sol). The difference is the inclusion of two additional features:

1. Efficiently resetting the accrued spend at defined intervals set during initialization.
   - `Daily`: on midnight everyday.
   - `Weekly`: on Monday every week.
   - `Monthly`: on the first day of every month.
2. Ability to track both native and ERC20 tokens.

> **Note that this policy relies on the `TIMESTAMP` opcode during validation and requires an alternative mempool. This is needed to ensure time intervals work as expected.**

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
