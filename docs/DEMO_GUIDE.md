# Evaluator Demo Guide

This prototype is designed to be broken. Use the top Control Bar to test the system's resilience.

### Scenario 1: The Golden Path
1. Click **Start Task**.
2. Watch the Policy Engine evaluate rules, route to the highest-scoring provider, and settle on the Ledger.

### Scenario 2: Idempotency Strike
1. While a task is running, click **Simulate Idempotency Strike**.
2. **Expected Result:** The Policy Engine instantly flags the duplicate key. The Ledger records a `Blocked - Idempotent` row. System metrics update.

### Scenario 3: Budget Governance
1. Click **Force Budget Guardrail**.
2. **Expected Result:** The system pauses execution. The Policy panel flags a `WARN`. A modal demands manual override. Clicking "Override" forces a PASS state and continues.

### Scenario 4: Mid-Flight Failover
1. In the Provider Grid, toggle a live provider's switch to **Offline**.
2. **Expected Result:** The node dies. If it was selected for the current routing step, the system intercepts the failure, logs a `Failed - Rerouted` ledger entry, releases locked funds, and automatically recalculates scores to select the next best node.

### Scenario 5: Traceability Verification
1. Once the task finishes, click **Execute Architectural Replay**.
2. **Expected Result:** The system zeroes out its state and reconstructs the UI purely from the immutable `LedgerEntry` objects.