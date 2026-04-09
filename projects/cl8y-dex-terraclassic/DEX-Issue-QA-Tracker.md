# CL8Y DEX — Issue QA Tracker (44 Issues, Filed 4/9)
> Created: 2026-04-09 by @Brouie
> Source: 44 issues filed by @PlasticDigits across 8 epics (#56-#63)
> Purpose: Map new issues to QA actions, track what we can verify vs what's blocked

---

## Epics Overview

| Epic | Title | Blocker Labels | Issue Count |
|------|-------|----------------|-------------|
| #56 | Product & hybrid architecture | blocker:hybrid, blocker:launch | Design decisions |
| #57 | v2 pool-only launch readiness | blocker:launch, blocker:v2 | Launch gates |
| #58 | Limit order product completion | blocker:limit-orders | Feature completion |
| #59 | Hybrid implementation post-ADR | blocker:hybrid | Implementation |
| #60 | Security hardening | security | Reviews |
| #61 | Testing & verification gates | testing | Test gaps |
| #62 | Observability & operations | infra | Ops tooling |
| #63 | Documentation & integrator experience | documentation | Docs |

---

## QA Action Items — Can Act Now

### Testing we can write or verify immediately

| Issue | Title | QA Action | Priority |
|-------|-------|-----------|----------|
| #66 | CI/CD wasm parity | Verify wasm checksums match deployed artifacts | blocker:launch |
| #69 | Pin LocalTerra images | Verify image tags in docker-compose, test reproducibility | Medium |
| #77 | Contract test: single-hop hybrid book+pool | Review test exists, run and verify | blocker:hybrid |
| #78 | Contract test: multi-hop router hybrid | Review test exists, run and verify | blocker:hybrid |
| #82 | Indexer test: hybrid swap attributes | Run indexer integration tests, verify columns | Medium |
| #83 | Contract: fee discount on limit book | Run test, verify discount applies | Medium |
| #84 | Vitest: hybrid CW20 message shape | Run frontend tests, verify message construction | Medium |
| #85 | Contract test: max_maker_fills hard cap | Run test, verify cap enforced | Medium |
| #86 | Script: post-deploy pool swap smoke | Write or verify smoke script exists | blocker:v2 |
| #87 | Test: pause blocks swap, limit place/cancel | Run test, verify pause behavior | blocker:v2 |
| #88 | Indexer: strict env validation | Review and test production profile | Medium |

### Documentation we can review

| Issue | Title | QA Action | Priority |
|-------|-------|-----------|----------|
| #67 | Launch checklist runbook | Review completeness, cross-check with our QA pass | blocker:launch |
| #68 | Fee tier docs alignment | Review, flag discrepancies | Medium |
| #80 | AfterSwap L7 docs | Review accuracy vs contract behavior | Medium |
| #91 | Wasm migration runbook | Review for completeness | Medium |
| #92 | Operator secrets handling | Security review | Medium |
| #93 | Incident response template | Review template | Medium |
| #94 | Environment matrix docs | Review local/testnet/mainnet | Medium |
| #95 | Indexer block-time parse risk | Review and document | Medium |
| #96 | Integrators doc (L7, L8, hybrid:null) | Review for accuracy | blocker:hybrid |
| #97 | Frontend/indexer .env.example | Verify examples match actual config | Medium |
| #98 | README production review bundle | Review links and completeness | Medium |
| #99 | UI hybrid badge tooltip | Verify tooltip appears on TradesTable | Medium |

---

## QA Action Items — Blocked (Needs Dev/Design First)

### Needs design decision

| Issue | Title | Blocked By | Notes |
|-------|-------|------------|-------|
| #56 | Epic: Product & hybrid architecture | ADR needed | blocker:launch |
| #64 | ADR for hybrid quoting (L8) | Design decision | blocker:hybrid, blocker:launch |
| #65 | Product scope for hybrid routing | Design decision | blocker:hybrid |
| #70 | Limit book surfacing strategy | Design decision | blocker:limit-orders |
| #81 | max_spread for hybrid total return | Design + security review | blocker:hybrid |

### Needs implementation

| Issue | Title | Blocked By | Notes |
|-------|-------|------------|-------|
| #71 | Limit book visibility (indexer API/frontend) | #70 design | blocker:limit-orders |
| #72 | E2E limit order place/cancel | Funded wallet + runner | blocker:limit-orders |
| #73 | Frontend: pair pause blocks limit cancel (L6) | Implementation needed | Limit orders |
| #74 | Indexer: wasm attribute version matrix | Implementation needed | Limit orders |
| #75 | Hybrid quote/routing per ADR | #64 ADR needed | blocker:hybrid |
| #76 | Frontend: hybrid book leg disclosure | #64 ADR needed | blocker:hybrid, blocker:launch |
| #79 | E2E Playwright: hybrid swap | Browser on QA server or local | blocker:hybrid |
| #89 | Indexer: Prometheus metrics | Implementation needed | Ops |
| #90 | Indexer: reorg/replay/backfill runbook | Implementation needed | Ops |

---

## Launch Blockers Summary

Issues that must be resolved before launch (blocker:launch label):

| Issue | Title | Status |
|-------|-------|--------|
| #56 | Epic: Product & hybrid architecture | Needs ADR |
| #64 | ADR for hybrid quoting | Needs design |
| #66 | CI/CD wasm parity | **Can verify now** |
| #67 | Launch checklist runbook | **Can review now** |
| #76 | Frontend hybrid disclosure | Needs #64 ADR |

---

## QA Test Counts (Baseline 38afbf8 — verified 4/7)

| Layer | Count | Status |
|-------|-------|--------|
| Contracts | 286/286 | All pass |
| Indexer unit | 60/60 | All pass |
| Frontend Vitest | 214/214 | All pass |
| Indexer integration (CoinGecko) | 9 | Need stack |

---

*Updated as issues are resolved or new tests are added.*
