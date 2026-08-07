# Engineering Concessions & Limitations

To deliver a locally runnable, self-contained prototype within the hackathon timeframe, specific systems were simulated. 

### What is Real (Deterministic)
*   **The Routing Algorithm:** The multi-factor math is real. 
*   **The State Machine:** State transitions, ledger appends, and treasury locks are functionally executed in memory.
*   **Idempotency Guards:** The logic blocking duplicate keys is active.

### What is Simulated (Mocked)
*   **Network Latency:** Provider health and latency are simulated via a randomized local loop (`mutateFluctuations`).
*   **Settlement Engine:** The x402 protocol is visually simulated via a timed animation array rather than hitting a real payment rail.
*   **Data Persistence:** The ledger and audit logs exist in volatile memory. A production build would utilize a local SQLite/Room database or a secure offline vault.

### Production Roadmap
In a production environment, `DemoState` would be decoupled into microservices:
1.  A dedicated Rust/Go backend for the routing engine.
2.  A local secure enclave for cryptographic key signing.
3.  gRPC streams replacing the local timer loops for provider health checks.