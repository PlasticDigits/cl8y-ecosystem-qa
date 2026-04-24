# YieldOmega — Security Verification Checklist

> Flow: Security review of YieldOmega stack — static frontend, EVM smart contracts, indexer — with gap analysis against existing tests and incident response controls
> Author: @Brouie (AVE)
> Version: 1.0 — 2026-04-23 (DRAFT — pending dev review)
> Repo: yieldomega
> Status: Draft for dev review

## 0. Purpose & Scope

This checklist covers security review of the YieldOmega protocol across three surfaces:
1. Static frontend (React/Vite, dapp at `frontend/`)
2. EVM smart contracts (Solidity/Foundry at `contracts/`)
3. Indexer (Rust/PostgreSQL at `indexer/`)

For each surface, the top 20 most common exploit classes are enumerated with: (a) applicability to YO, (b) existing test coverage (with file reference), and (c) any gap that requires new coverage.

The final section covers **incident response** — pause / circuit breaker controls, detection + alerting hooks, and rate limiting where applicable.

### Out-of-scope
- Chain-level risks (consensus, L1 reorgs beyond application-level guards)
- Third-party bridges (covered in separate Bridge E2E spec)
- Kumbaya router security (third-party DEX contract; YO surface is integration only)
- Social engineering / private key management by operators

### Companion specs
- `UST1-Window-Security-Checklist.md` — oracle-service-focused, multi-chain
- `DEX-Security-Checklist.md` — Terra Classic + DEX-specific (peer spec)

---

## 1. Static frontend — top 20 exploits

| # | Exploit class | Applies to YO | Existing coverage | Gap |
|---|---|---|---|---|
| 1.1 | XSS (stored) | YES — user slug rendering, referral links | TBD | TBD |
| 1.2 | XSS (reflected) | YES — URL query params (`?ref=`) | `referralPathCapture.test.ts` | TBD |
| 1.3 | CSP bypass | YES — production CSP headers | TBD — inspect prod response headers | TBD |
| 1.4 | Clickjacking | YES — wallet approval flows | TBD — frame-ancestors header | TBD |
| 1.5 | Secret leakage in bundle | YES — no secrets should ship | TBD — scan prod bundle | TBD |
| 1.6 | Wallet connection hijack | YES — WalletConnect / EIP-6963 | TBD | TBD |
| 1.7 | Phishing chain switch | YES — wrong-chain submit risk | LaunchGate chain-id assertion | TBD |
| 1.8 | Local storage tampering | YES — referral code persistence | Accepted per spec (technical users can clear) | n/a |
| 1.9 | Supply chain (deps) | YES — package-lock pinning | TBD — audit cadence | TBD |
| 1.10 | Wallet address spoofing | YES — displayed addresses | TBD | TBD |
| 1.11 | Signature replay | YES — EIP-712 nonces | Contract-side | n/a frontend |
| 1.12 | Open redirect | LOW — no OAuth | n/a | n/a |
| 1.13 | SSRF | n/a — client-side only | n/a | n/a |
| 1.14 | Route hijack (dynamic segments) | YES — `/:slug` collision | `extractReferralCodeFromPathname` tests reject catch-all | OK |
| 1.15 | RPC URL tampering | YES — VITE_RPC_URL | TBD — HTTPS-only enforcement | TBD |
| 1.16 | Transaction parameter tampering | YES — swap min-out, slippage | TBD — UI bounds validation tests | TBD |
| 1.17 | Stale quote execution | YES — Kumbaya routing | `swapQuoteLoading` state disables Buy — verified via #52 | OK |
| 1.18 | UI denial of service (infinite loops) | LOW | TBD | TBD |
| 1.19 | Dependency typosquat | YES — npm install hygiene | TBD — lockfile audit | TBD |
| 1.20 | Source map leakage | YES — prod build | TBD — confirm `sourcemap: false` in vite.config | TBD |

---

## 2. EVM smart contracts — top 20 exploits

| # | Exploit class | Applies to YO | Existing coverage | Gap |
|---|---|---|---|---|
| 2.1 | Reentrancy (classic) | YES — `buy`, `redeemCharms`, distribute | `nonReentrant` on mutating methods; verified in #39 B4 | OK |
| 2.2 | Reentrancy (read-only) | YES — podium reads during distribute | TBD — check for stale-view reads mid-distribution | TBD |
| 2.3 | Access control bypass | YES — governance-only ops | Foundry suite TBD | TBD |
| 2.4 | Integer overflow / underflow | LOW — pragma 0.8.x protects | Compiler default | OK |
| 2.5 | Unchecked math in unchecked blocks | YES — gas-optimized paths | TBD — audit all `unchecked {}` blocks | TBD |
| 2.6 | Timestamp manipulation (miner) | YES — timer extensions | Hard-reset + cap mitigations present | OK |
| 2.7 | Front-running (MEV) | YES — buy ordering at sale end | Accepted per spec (sale mechanics) | n/a |
| 2.8 | Price oracle manipulation | n/a — YO has no external oracle | n/a | n/a |
| 2.9 | Flash loan attack | LOW — CHARM not LP'd during sale | TBD — confirm no callable hook | TBD |
| 2.10 | Delegate call misuse | TBD | TBD | TBD |
| 2.11 | Storage collision (proxy) | YES — UUPS via OZ v5.6.1 (#54 closed 4/24) | `_disableInitializers` in impl constructors + `initializer` modifier on all init funcs | OK |
| 2.12 | Uninitialized storage | LOW | TBD | TBD |
| 2.13 | Griefing (DoS via gas) | YES — linked-list operations | ±20-hop repair cap per spec | OK |
| 2.14 | tx.origin misuse | TBD | TBD — grep codebase | TBD |
| 2.15 | Reserved-word / reserved-slot collision | YES — referral slug registry | On-chain reserved-word set per spec | OK |
| 2.16 | ERC-20 approval griefing | YES — CL8Y, DOUB approvals | Max-uint256 allowance pattern | OK |
| 2.17 | Signature malleability | LOW — ECDSA well-formed inputs | TBD | TBD |
| 2.18 | Upgrade governance takeover | TBD — governance key custody | TBD | TBD |
| 2.19 | WarBow state corruption post-end | YES — **FINDING #47** | Open | BLOCKER |
| 2.20 | Referral self-refer / sybil | YES — design constraint | Self-refer banned per spec; sybil accepted tradeoff | OK |

---

## 3. Indexer — top 20 exploits

| # | Exploit class | Applies to YO | Existing coverage | Gap |
|---|---|---|---|---|
| 3.1 | RPC HTTPS gate | YES — upstream EVM RPC | TBD — analogous to bridge `validate_rpc_url` | TBD |
| 3.2 | Confirmation depth | YES — reorg protection | TBD — check indexer processor | TBD |
| 3.3 | SQL injection | LOW — parameterized queries | sqlx compile-time checks | OK |
| 3.4 | Event decoding buffer overflow | LOW — ABI-typed decoders | TBD | TBD |
| 3.5 | Reorg handling | YES — YO indexes block-scoped events | TBD — test suite coverage | TBD |
| 3.6 | API rate limiting | YES — public `/v1/*` surface | TBD | TBD |
| 3.7 | Cache poisoning | YES — derived leaderboard | Leaderboard is on-chain linked list; indexer is read-only mirror | OK |
| 3.8 | Stale data serving | YES — #49 'Indexer unreachable' banner should surface | **FINDING #49** open | BLOCKER |
| 3.9 | Unauthenticated admin endpoints | TBD — check for admin routes | TBD | TBD |
| 3.10 | Credentials in env | YES — DB URL + private keys | Standard env-file practice | OK |
| 3.11 | Docker container breakout | YES — postgres container | Bridge cryptominer incident (handoff 0321) — tightened bindings | OK |
| 3.12 | Exposed DB ports | YES — history of this exact issue | Bind 127.0.0.1 only, strong password | OK |
| 3.13 | DoS via unbounded query | YES — leaderboard, buy history | TBD — pagination limits | TBD |
| 3.14 | Log injection | LOW | TBD | TBD |
| 3.15 | Deserialization (unsafe) | TBD | TBD | TBD |
| 3.16 | HTTP smuggling | LOW | TBD — reverse proxy config | TBD |
| 3.17 | Clock skew | YES — timestamp-dependent queries | TBD | TBD |
| 3.18 | Replay attack on admin ops | LOW — no admin write ops | TBD | TBD |
| 3.19 | Memory exhaustion (large payloads) | YES — API responses | TBD — response size limits | TBD |
| 3.20 | Dependency vulnerabilities (Cargo) | YES — cargo audit cadence | TBD | TBD |

---

## 4. Incident response controls

### 4a. Pause / circuit breakers

- [ ] **CB-01** — TimeCurve sale can be paused by governance? Identify authority + mechanism
- [ ] **CB-02** — FeeRouter can be paused? Or fee routing throttled?
- [ ] **CB-03** — RabbitTreasury withdrawals can be paused?
- [ ] **CB-04** — Referral registry governance-updatable for restricted words (already in spec)
- [ ] **CB-05** — State preservation on pause (no data loss, resumption safe)

### 4b. Incident detection

- [ ] **ID-01** — Unusual buy volume alerts (per-block, per-wallet)
- [ ] **ID-02** — WarBow action spam detection
- [ ] **ID-03** — Indexer-chain drift alerts (indexer block lag > N)
- [ ] **ID-04** — Failed tx cluster detection (revenge + steal floods)
- [ ] **ID-05** — Reserve drift (unexpected podium pool balance changes)
- [ ] **ID-06** — Governance action notifications

### 4c. Rate limiting

- [ ] **RL-01** — Indexer public `/v1/*` endpoints
- [ ] **RL-02** — WarBow actions per-wallet (already exists: 3 steals/day, bypass burn escalation)
- [ ] **RL-03** — Referral registration per-wallet (CL8Y burn as economic throttle)
- [ ] **RL-04** — Leaderboard repair hops capped at ±20 per spec

---

## 5. References

- `docs/product/primitives.md` — canonical game mechanics
- `contracts/PARAMETERS.md` — protocol parameters + BPS
- `docs/testing/invariants-and-business-logic.md` — invariant map
- Open findings: #47, #48, #49, #50, #52 (current session)
- Related specs: UST1-Window-Security-Checklist.md, DEX-Security-Checklist.md (pending peer)

