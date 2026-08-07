# Tollgate

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat-square&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=flat-square&logo=dart&logoColor=white)
![Hackathon](https://img.shields.io/badge/Hackathon-CodeRush-success?style=flat-square)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)

> Deterministic spend management for autonomous AI agents.

## Problem Statement

**Challenge:** INF-01 — Multi-Provider Agent Payment Router & Treasury.

Agents are rapidly acquiring the ability to transact autonomously, but currently lack fundamental financial guardrails. In multi-agent systems, agents can silently overspend across multi-step tasks, execute concurrent duplicate payments for the same job, and lose state if a provider dies mid-transaction. Furthermore, "we paid for X" is often asserted rather than proven. 

## Why Tollgate Exists

The x402 protocol allows an agent to discover a priced resource and pay for it with no human in the loop. However, x402 is strictly a settlement mechanism; it does not solve governance. Without deterministic financial control, autonomous spend inevitably becomes autonomous risk. 

Tollgate exists to be the control plane. It ensures that no agentic task executes without explicit budget reservation, identity verification, multi-provider failover capability, and an append-only audit log.

## Solution Overview

Tollgate is a policy-driven treasury and settlement router for x402 agentic commerce. It sits between any agent and any priced resource (inference, storage, compute, or data), ensuring that routing, budgeting, settling, and proving are deterministically enforced.

**Architecture Flow:**
```text
AI Agent
   ↓
Policy Engine
   ↓
Routing Engine
   ↓
Treasury
   ↓
Settlement
   ↓
Ledger
   ↓
Replay
   ↓
Dashboard
```

Every payment request passes through deterministic policy evaluation before provider selection, budget reservation, settlement simulation, ledger recording, and replay generation. No routing decisions rely on probabilistic AI inference.

## Key Features

### Governance
*   **Budget reservation:** Locks funds before request dispatch to prevent concurrent overspends.
*   **Policy engine:** Discrete gates for Availability, Trust, Idempotency, and Budget.
*   **Human approval workflow:** Pauses execution for manual override when budget caps are breached.

### Reliability
*   **Duplicate payment protection (Idempotency):** Strict idempotency key validation.
*   **Provider failover:** Mid-flight rerouting upon simulated node failure.
*   **Replay mode:** Complete architectural state reconstruction from the event ledger.

### Transparency
*   **Explainable routing:** Scores and selects nodes based on real-time metrics, generating explicit scorecards.
*   **Settlement ledger:** Append-only trace of all settlements.
*   **Append-only audit log:** Chronological system logging by structural component.
*   **Treasury tracking:** Real-time visibility into spent, reserved, and available funds.

## Technical Architecture

*   **Orchestrator (`DemoState`):** The central state machine managing the lifecycle of the multi-step agent task.
*   **Provider Profiles:** Typed domain models maintaining live, fluctuating metrics for eligible providers.
*   **Policy Engine:** The gatekeeper evaluating rules (PASS/WARN/BLOCK) before any routing occurs.
*   **Routing Engine:** The algorithmic core that normalizes provider metrics and outputs a definitive routing decision.
*   **Treasury:** A concurrency-safe vault that reserves estimated costs to prevent silent double-spends.
*   **Ledger:** An append-only data structure recording TXIDs, Request IDs, and Settlement Statuses.

## Technology Stack

The prototype is implemented as a single Flutter application using Dart, enabling rapid cross-platform demonstration while maintaining a unified codebase.

*   **Framework:** Flutter
*   **Language:** Dart

## Repository Structure

```text
tollgate/
├── android/                   # Android build configuration
├── assets/
│   └── screenshots/           # UI documentation
├── docs/                      # Technical documentation and guides
│   ├── ARCHITECTURE.md
│   ├── DEMO_GUIDE.md
│   ├── LIMITATIONS.md
│   ├── PROTOTYPE.md
│   └── SYSTEM_FLOW.md
├── lib/                       # Core application logic
│   └── main.dart              # Main orchestrator and UI implementation
├── test/                      # Unit and widget tests
├── .gitignore                 # Untracked files configuration
├── analysis_options.yaml      # Strict Dart linting rules
├── pubspec.yaml               # Dependency management
└── README.md                  # Project overview
```

## Running the Project

Runs locally using Flutter.

```bash
flutter pub get
flutter run
```

Note: Android is the recommended target environment for this prototype.

Demo Scenarios
This prototype is designed to be stressed-tested live.

Happy Path: Click Start Task to watch the Policy Engine evaluate rules, the Router select the highest-scoring provider, and the Treasury settle the payment on the Ledger.

Duplicate Payment: While a task is routing, fire a duplicate request. The Policy Engine intercepts the duplicate key and blocks it, preventing a double-charge.

Budget Breach: Force a projected overage. The system halts, flags a WARN, and awaits explicit human approval to proceed.

Provider Failure: Toggle a provider offline mid-transaction. The system intercepts the failure, logs the error, releases reserved funds, and recalculates scores to select the next viable node.

Replay: After completion, clear the active UI and reconstruct the entire state sequentially from the ledger events.

Screenshots
Dashboard
Policy Engine Evaluation
Decision Explainability Trace
Idempotency Guard Block
Budget Override Modal
Mid-Flight Failover
Current Scope
Implemented:

Locally simulated state machine prototype.

Deterministic multi-factor routing algorithm.

Discrete policy engine evaluation.

Memory-based append-only ledger and treasury tracking.

Not Implemented:

Production microservices backend (Rust/Go).

Live x402 settlement on external payment rails.

Blockchain network integration or smart contracts.

Cloud deployment.

Future Work
Real x402 providers

Persistent ledger

Production policy service

Enterprise deployment

Live provider metrics

**License**
This project was developed as part of CodeRush 2.0.
Released under the MIT License.

**Contributors**
Developed by Team Penguin for CodeRush 2.0.

Pushkar Wagh

Navdeep Singh

Anika Nair

Manbhavna Khanna

Arya Sharma



