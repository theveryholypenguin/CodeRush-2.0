# Execution Pipeline

Every agentic step passes through a strict, linear orchestration pipeline.

1. **Ingest / Step Initialization**
   * The orchestrator queues the task and intercepts the payment request.

2. **Policy Evaluation (`Gatekeeper`)**
   * *Availability Check*
   * *Trust Verification*
   * *Idempotency Lock*
   * *Budget Projection*
   * **Output:** Proceed, Warn (Require Approval), or Block.

3. **Algorithmic Scoring (`Router`)**
   * Filters offline nodes.
   * Drops nodes breaching static thresholds (e.g., >200ms latency).
   * Calculates weighted composite scores out of 100.
   * **Output:** Immutable `RoutingDecision`.

4. **Treasury Reservation (`Vault`)**
   * Locks the requested funds.
   * Updates Treasury Meter visually.

5. **Settlement Protocol (`Visualizer`)**
   * Simulates x402 lifecycle: `Request -> Signed -> Verified -> Settled`.

6. **Ledger Append (`Reconciliation`)**
   * Writes the final transaction with TXID, Request ID, and Idempotency Key.
   * Releases reservation, updates total spend.