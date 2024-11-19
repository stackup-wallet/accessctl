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
          { moduleAddress: "0x12433894c552fc8fa16a20859df119319b71cc17" },

          // SudoPolicy
          { moduleAddress: "0x18aCF4AD3cBb7ca77743a5bEDd2597a42Bac4B7B" },

          // IntervalSpendingLimitPolicy
          { moduleAddress: "0xad8508e62bcf4bfbc6b092e5e9e54508c4936555" },
        ],
      ],
    }),
  });
  console.log("Transaction hash:", hash);
})();
