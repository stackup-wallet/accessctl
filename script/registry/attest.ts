import { encodeFunctionData } from "viem";
import { sepolia } from "viem/chains";
import * as Registry from "./constants/registry";
import { getClient } from "./utils/client";

const CHAIN = sepolia;
const JSON_RPC = "http://127.0.0.1:1248";

const SCHEMA_ID =
  "0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1";
const MAX_TIMESTAMP = 281474976710655;
const ERC7579_MODULE_TYPE_STATELESS_VALIDATOR = BigInt(7);

(async () => {
  console.log("Module registry attestation inputs");
  const client = getClient(JSON_RPC, CHAIN);
  const [account] = await client.getAddresses();
  console.log("Using attester:", account);

  const hash = await client.sendTransaction({
    account,
    to: Registry.address,
    data: encodeFunctionData({
      abi: Registry.abi,
      functionName: "attest",
      args: [
        SCHEMA_ID,
        [
          // WebAuthnValidator
          {
            moduleAddress: "0x12433894c552fc8fa16a20859df119319b71cc17",
            expirationTime: MAX_TIMESTAMP,
            data: "0x",
            moduleTypes: [ERC7579_MODULE_TYPE_STATELESS_VALIDATOR],
          },

          // SudoPolicy
          {
            moduleAddress: "0x763a48b60b8426e2df3933e4a47d57e0d9803e9d",
            expirationTime: MAX_TIMESTAMP,
            data: "0x",
            moduleTypes: [],
          },

          // IntervalSpendingLimitPolicy
          {
            moduleAddress: "0xad8508e62bcf4bfbc6b092e5e9e54508c4936555",
            expirationTime: MAX_TIMESTAMP,
            data: "0x",
            moduleTypes: [],
          },
        ],
      ],
    }),
  });
  console.log("Transaction hash:", hash);
})();
