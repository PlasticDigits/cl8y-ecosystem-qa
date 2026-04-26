# CL8Y DEX Terra Classic — Security Verification Checklist

> Flow: Security review of CL8Y DEX stack — static frontend, CosmWasm contracts on Terra Classic, indexer — with gap analysis against existing tests and incident response controls
> Author: @Brouie (AVE)
> Version: 1.0 — 2026-04-23 (DRAFT — pending dev review)
> Repo: cl8y-dex-terraclassic
> Status: Draft for dev review

## 0. Purpose & Scope

This checklist covers security review of the CL8Y DEX protocol across three surfaces:
1. Static frontend (React/Vite/Tailwind, dapp at `frontend-dapp/`)
2. Terra Classic CosmWasm contracts (`smartcontracts/` — pair, router, factory, limit-book)
3. Indexer (Rust/PostgreSQL at `indexer/`)

For each surface, the top 20 most common exploit classes are enumerated with: (a) applicability to DEX, (b) existing test coverage (with file reference), and (c) any gap that requires new coverage.

The final section covers **incident response** — pause / circuit breaker controls, detection + alerting hooks, and rate limiting where applicable.

### Out-of-scope
- Chain-level risks (Tendermint consensus, Terra Classic core)
- Third-party bridges (covered in separate Bridge E2E spec)
- UST1 Window / oracle service (separate spec)
- Social engineering / private key management by operators

### Companion specs
- `UST1-Window-Security-Checklist.md` — oracle-service-focused, CW + off-chain BSC reads
- `YO-Security-Checklist-DRAFT.md` — EVM + YO-specific (peer spec)

---

## 1. Static frontend — top 20 exploits

| # | Exploit class | Applies to DEX | Existing coverage | Gap |
|---|---|---|---|---|
| 1.1 | XSS (stored) | YES — token metadata rendering | TBD | TBD |
| 1.2 | XSS (reflected) | YES — URL query params (`?pair=`) | TBD | TBD |
| 1.3 | CSP bypass | YES — production CSP headers | TBD — inspect prod response headers | TBD |
| 1.4 | Clickjacking | YES — wallet approval flows | TBD — frame-ancestors header | TBD |
| 1.5 | Secret leakage in bundle | YES — no secrets should ship | `frontend-dapp/src/services/terraclassic/devWallet.ts` L4-5 ships literal `DEFAULT_DEV_MNEMONIC` constant + `VITE_DEV_MNEMONIC` env-var fallback at L20 (**FINDING #118**). Runtime guard (`!DEV_MODE` throw) blocks usage but does not strip from bundle. Address is dust on-chain so no immediate loss, but pattern is bad pre-launch. | LOW pre-launch (active finding) |
| 1.6 | Wallet connection hijack | YES — Station / Keplr / WalletConnect | TBD | TBD |
| 1.7 | Phishing chain switch | YES — Columbus-5 vs LocalTerra (`utils/constants.ts` L61/68/75: `localterra` / `rebel-2` / `columbus-5`) | Wallet bound to `networkConfig.chainId` at construction (`wallet.ts` L28). Per-tx broadcast (`transactions.ts` L146/201) carries no explicit chainId assertion — relies on `cosmes` adapter internal handling. No UI-side chain-mismatch detection: if connected wallet's chain differs from `networkConfig.chainId`, broadcast would proceed against whatever `cosmes` resolves. Worth a defensive equality check pre-broadcast. | TBD pending wallet-adapter audit |
| 1.8 | Local storage tampering | LOW — session-only state | n/a | n/a |
| 1.9 | Supply chain (deps) | YES — package-lock pinning | TBD — audit cadence | TBD |
| 1.10 | Wallet address spoofing | YES — displayed addresses | TBD | TBD |
| 1.11 | Transaction parameter tampering | YES — swap min-out, slippage | `routeOperations.test.ts` (3 tests) | TBD |
| 1.12 | Stale quote execution | YES — hybrid routing re-quote | TBD — `swapQuoteLoading` state checks | TBD |
| 1.13 | Price chart data tampering | YES — TradingView candle feed | `PriceChart.test.tsx` (9 tests) | OK |
| 1.14 | Route hijack (dynamic segments) | LOW — simpler router than YO | TBD | TBD |
| 1.15 | LCD URL tampering | YES — VITE_LCD_URL | TBD — HTTPS-only enforcement | TBD |
| 1.16 | Indexer URL tampering | YES — VITE_INDEXER_URL | TBD — HTTPS-only enforcement | TBD |
| 1.17 | Order book spoofing (client-side) | YES — limit book rendering | `OrderBookPanel` component + route solver tests | TBD |
| 1.18 | UI denial of service (infinite loops) | LOW | TBD | TBD |
| 1.19 | Dependency typosquat | YES — npm install hygiene | TBD — lockfile audit | TBD |
| 1.20 | Source map leakage | YES — prod build | `vite.config.ts` L70 currently `sourcemap: true`, ships .js.map to prod (**FINDING #117**). Bridge sets `false` explicitly; YO uses Vite default (`false`). Fix pre-mainnet per #117. | BLOCKER pre-launch |

---

## 2. Terra Classic CosmWasm contracts — top 20 exploits

| # | Exploit class | Applies to DEX | Existing coverage | Gap |
|---|---|---|---|---|
| 2.1 | Reentrancy (via reply / submsg) | YES — router calls pair calls cw20 | TBD — audit reply handling | TBD |
| 2.2 | Access control bypass | YES — factory admin, pair governance | TBD — cw-multitest suite | TBD |
| 2.3 | Fixed-point math overflow / underflow | YES — swap math, LP math | TBD — invariants suite | TBD |
| 2.4 | Rounding dust accumulation | YES — constant-product swap | TBD — direction of rounding per invariant | TBD |
| 2.5 | Slippage guard bypass | YES — min-return enforcement | TBD — negative tests | TBD |
| 2.6 | Multihop path validation | YES — router hybrid paths | `route_solver.rs` tests (indexer side) | TBD |
| 2.7 | Hybrid pool-vs-book integrity | YES — split-execution across legs | ADR 0001 + hybrid QA test | TBD |
| 2.8 | Replay (cross-chain) | LOW — single-chain | n/a | n/a |
| 2.9 | Two-step governance | YES — factory admin transfer | TBD — propose/accept pattern | TBD |
| 2.10 | Migrate privilege | YES — contract admin upgradeability | TBD — migrate msg validation | TBD |
| 2.11 | Unbounded loops (DoS) | YES — deep limit book walking | #102 addressed with pagination | OK |
| 2.12 | Panic on malformed input | YES — serde + cosmwasm_std parsing | TBD — fuzz tests | TBD |
| 2.13 | Pause bypass | YES — if admin can pause pairs | TBD — pause state coverage | TBD |
| 2.14 | Fee bps bounds | YES — pair fee config | TBD — upper bound enforcement | TBD |
| 2.15 | Attribute injection (event logs) | LOW — structured emit | TBD | TBD |
| 2.16 | cw20 spoofing (fake token addresses) | YES — router accepts arbitrary cw20 | TBD — registry / allowlist pattern | TBD |
| 2.17 | Instantiate validation | YES — pair init params | TBD — zero-value rejection | TBD |
| 2.18 | Attached funds handling | YES — native Luna / USTC swap paths | TBD — funds.is_empty() enforcement on non-native msgs | TBD |
| 2.19 | Limit order expiry & eviction | YES — book state integrity | #102 + #72 + #103 coverage | OK |
| 2.20 | Pair canonical-ness (same-token-twice) | YES — **FINDING** per 4/22 smoke (dev filed #112) | Open | BLOCKER |

---

## 3. Indexer — top 20 exploits

| # | Exploit class | Applies to DEX | Existing coverage | Gap |
|---|---|---|---|---|
| 3.1 | LCD HTTPS gate | YES — upstream Terra LCD | TBD — analogous to bridge `validate_rpc_url` | TBD |
| 3.2 | Block height confirmation depth | YES — reorg protection | TBD — check indexer processor | TBD |
| 3.3 | SQL injection | LOW — parameterized queries via sqlx | sqlx compile-time checks | OK |
| 3.4 | Event decoding robustness | YES — CosmWasm event parsing | TBD — malformed event tests | TBD |
| 3.5 | Pool-state-vs-indexer-state drift | YES — indexer lag during deep reorg | TBD — drift detection | TBD |
| 3.6 | API rate limiting | YES — public `/api/v1/*` surface | TBD | TBD |
| 3.7 | Cache poisoning | YES — orderbook_sim derived depth | `orderbook_sim.rs` clearly labeled #105 | OK |
| 3.8 | Stale data serving | YES — block lag > N threshold | TBD — health endpoint alert | TBD |
| 3.9 | Unauthenticated admin endpoints | TBD — check for admin routes | TBD | TBD |
| 3.10 | Credentials in env | YES — DB URL | Standard env-file practice | OK |
| 3.11 | Docker container breakout | YES — postgres container | Bridge cryptominer incident pattern — tightened bindings | OK |
| 3.12 | Exposed DB ports | YES — history of this exact issue | Bind 127.0.0.1 only, strong password | OK |
| 3.13 | DoS via unbounded query | YES — deep limit book, historical candles | #102 pagination + candles API limits | OK |
| 3.14 | Log injection | LOW | TBD | TBD |
| 3.15 | Deserialization (unsafe) | TBD | TBD | TBD |
| 3.16 | HTTP smuggling | LOW | TBD — reverse proxy config | TBD |
| 3.17 | Clock skew (candle bucket edges) | YES — candle time-bucket boundary | TBD — candle buckets vs chain time | TBD |
| 3.18 | Hybrid route_solve injection | YES — POST body parsed + applied | `api_route_solve.rs` tests | TBD — bound-validation audit |
| 3.19 | Memory exhaustion (large payloads) | YES — API responses | TBD — response size limits | TBD |
| 3.20 | Dependency vulnerabilities (Cargo) | YES — cargo audit cadence | TBD | TBD |

---

## 4. Incident response controls

### 4a. Pause / circuit breakers

- [ ] **CB-01** — Pair contract pause authority + mechanism
- [ ] **CB-02** — Router pause (global DEX freeze)
- [ ] **CB-03** — Factory pause (block new pair creation)
- [ ] **CB-04** — Limit book freeze (no new orders; existing cancelable)
- [ ] **CB-05** — State preservation on pause (no data loss, resumption safe)

### 4b. Incident detection

- [ ] **ID-01** — Unusual swap volume alerts (per-block, per-pair)
- [ ] **ID-02** — Price spike detection (% move vs rolling average)
- [ ] **ID-03** — Indexer-chain drift alerts (indexer block lag > N)
- [ ] **ID-04** — Failed tx cluster detection (slippage reverts, insufficient funds patterns)
- [ ] **ID-05** — Reserve drift (LP balance vs expected book state)
- [ ] **ID-06** — Governance action notifications (factory admin, pair param changes)

### 4c. Rate limiting

- [ ] **RL-01** — Indexer public `/api/v1/*` endpoints
- [ ] **RL-02** — Hybrid route_solve POST (prevent DoS via crafted queries)
- [ ] **RL-03** — Candles API (bounded time range + interval)
- [ ] **RL-04** — Deep limit book pagination (per-request cap)

---

## 5. References

- `docs/adr/0001-hybrid-quoting-and-routing.md` — hybrid design decisions
- `docs/adr/0002-limit-book-surfacing.md` — limit book architecture
- `docs/indexer-invariants.md` — indexer invariant map
- `docs/testing.md` — test strategy + stub catalog (#105)
- Related open: #108 launch-blocker, #107 launch gate, #112 pair canonical-ness
- Related specs: UST1-Window-Security-Checklist.md, YO-Security-Checklist-DRAFT.md (peer)

