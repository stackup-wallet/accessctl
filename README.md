# AccessControl

**AccessControl (or `AccessCtl` for short) is a collection of modules for enabling IAM capabilities for modular smart accounts.**

These modules power [Stackup's onchain financial platform]() and are built to be interoperable with ERC-7579 and the [Smart Sessions](https://github.com/erc7579/smartsessions) standard.

## Summary of modules

AccessCtl modules are deployed using the [deterministic deployment proxy](https://github.com/Arachnid/deterministic-deployment-proxy) and have the same address on all chains.

<details>
  <summary><b>`v1.0.0 (WIP)`</b></summary>

| Contract                                                                            | Address                                      | Type              |
| ----------------------------------------------------------------------------------- | -------------------------------------------- | ----------------- |
| [`WebAuthnValidator.sol`](./src/signers/WebAuthnValidator.sol)                      | `0xcB6D0D07f8304db1bfa06D75bD4F9a9F559b312e` | Session validator |
| [`IntervalSpendingLimitPolicy.sol`](./src/policies/IntervalSpendingLimitPolicy.sol) | `0xe72ae3a8F17471396cD8E33572de662792C6Cf42` | Action policy     |

</details>

# Modules

The remaining section will assume knowledge on ERC-4337 (Account Abstraction), ERC-7579 (Minimal Modular Smart Accounts), and Smart Sessions. If you are unfamiliar, we recommend the following resources to get started:

- [erc4337.io](https://www.erc4337.io/docs)
- [erc7579.com](https://erc7579.com/)
- [Smart Sessions](https://github.com/erc7579/smartsessions)

The following is a sequence diagram is a summary of the end to end flow for a `UserOperation` under the ERC-7579 + Smart Sessions standard. AccessCtl is a collection of modules for the _Session Validator_ and _Policy_ entities which are concerned with authentication and authorization.

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
    Smart Sessions->>Session Validator: Calls validateSignatureWithData
    Note over Session Validator: Authentication check
    Session Validator->>Session Validator: Verifies webAuthn signature
    Session Validator->>Smart Sessions: Returns success response
    Smart Sessions->>Smart Account: Returns success response
    Smart Account->>EntryPoint: Pay prefund
    Note over EntryPoint,Smart Account: Validation done, execution next...
```

## Authentication modules

These are `SessionValidator` modules made for the Smart Sessions standard.

### [WebAuthnValidator.sol](./src/signers/WebAuthnValidator.sol)

A minimal wrapper around [webauthn-sol](https://github.com/base-org/webauthn-sol) to enable compatibility with the required smart session interface. This allows sessions to be authenticated directly with an end user's passkey.

## Authorization modules

These are `Policy` modules made for the Smart Sessions standard.

### [IntervalSpendingLimitPolicy](./src/policies/IntervalSpendingLimitPolicy.sol)

A fork of [SpendingLimitPolicy.sol](https://github.com/erc7579/smartsessions/blob/main/contracts/external/policies/SpendingLimitPolicy.sol). The difference is the inclusion of two additional features:

1. Resetting the accrued spend at defined intervals set by the end user during initialization.
   - `Daily`: on midnight everyday.
   - `Weekly`: on Monday every week.
   - `Monthly`: on the first day of every month.
2. Track both native token transfers and ERC20 tokens.

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
