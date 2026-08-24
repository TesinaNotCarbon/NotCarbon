# NotCarbon CRE validation workflow

EVM Log Trigger workflow for `CREValidationOracle.ValidationRequested` on Ethereum Sepolia.

Flow:
1. Decode `ValidationRequested(bytes32,address,string)` from the trigger tx.
2. Read `getValidationRequest(requestId)` from `CREValidationOracle` and trust only canonical `projectAddress`, `cellId`, `exists`, and `pending`.
3. Call `POST /validate-polygon` with `{ "cell_id": cellId }`.
4. Aggregate only `{ overlap, inconclusive }` with `consensusIdenticalAggregation`.
5. Write `abi.encode(bytes32 requestId, bool overlap, bool inconclusive)` to the oracle and require `TxStatus.SUCCESS`.

Run:

```bash
npm install
npm run typecheck
cd ..
cre workflow simulate validation-workflow --target staging-settings \
  --trigger-index 0 --evm-tx-hash <TX_HASH> --evm-event-index <LOG_INDEX>
```

Use `--broadcast --limits default` to send the on-chain report during simulation.
