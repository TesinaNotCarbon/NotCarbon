# NotCarbon CRE scoring workflow

EVM Log Trigger workflow for `CREScoringOracle.ScoringRequested` on Ethereum Sepolia.

Flow:
1. Decode `ScoringRequested(bytes32,address)` from the trigger tx.
2. Read `getScoringRequest(requestId)` from `CREScoringOracle` and require `exists && pending`.
3. Read `getProjectCellId(projectAddress)` from `ProjectManager`.
4. Call `GET /chainlink/score/{projectAddress}`.
5. Verify `schema_version`, `project_id`, `cell_id`, non-zero `measurement_date`, and scores in `0..100`.
6. Aggregate `scoring` and `fraudScoring` with median consensus.
7. Write `abi.encode(bytes32 requestId, uint256 measurementDate, uint256 scoring, uint256 fraudScoring)` and require `TxStatus.SUCCESS`.

Run:

```bash
npm install
npm run typecheck
cd ..
cre workflow simulate scoring-workflow --target staging-settings \
  --trigger-index 0 --evm-tx-hash <TX_HASH> --evm-event-index <LOG_INDEX>
```

Use `--broadcast --limits default` to send the on-chain report during simulation.
