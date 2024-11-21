import { encodeFunctionData } from "viem";
import { sepolia } from "viem/chains";
import * as Registry from "./constants/registry";
import { getClient } from "./utils/client";

const CHAIN = sepolia;
const JSON_RPC = "http://127.0.0.1:1248";

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
      functionName: "revoke",
      args: [
        [
          // WebAuthnValidator
          { moduleAddress: "0x6140DB7a66a18A7741ED2687409ef471235b4Df0" },

          // SudoPolicy
          { moduleAddress: "0x8032214D4082714742Ba137eBfbf05e3a9a5bCfC" },

          // IntervalSpendingLimitPolicy
          { moduleAddress: "0xAd8508E62BCf4bFBC6b092E5e9e54508c4936555" },
        ],
      ],
    }),
  });
  console.log("Transaction hash:", hash);
})();
