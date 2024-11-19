import { Chain, createWalletClient, custom } from "viem";

export const getClient = (rpc: string, chain: Chain) =>
  createWalletClient({
    chain,
    transport: custom({
      async request({ method, params }) {
        const response = await fetch(rpc, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            id: Date.now(),
            jsonrpc: "2.0",
            method,
            params,
          }),
        });

        if (!response.ok) {
          throw new Error(`RPC request failed with status ${response.status}`);
        }

        const responseData = await response.json();
        if (responseData.error) {
          throw new Error(`RPC Error: ${responseData.error.message}`);
        }

        return responseData.result;
      },
    }),
  });
