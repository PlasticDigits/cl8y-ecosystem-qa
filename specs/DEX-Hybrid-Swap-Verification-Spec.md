# CL8Y DEX — Hybrid Swap Verification Spec

> Flow: Hybrid Swap (AMM Pool + FIFO Limit Book)
> Author: @Brouie (AVE)
> Version: 1.0 — 2026-03-30
> Repo: cl8y-dex-terraclassic
> Reference: docs/limit-orders.md, contracts-security-audit.md (L6–L8)

---

## 1. User-Visible Steps

A hybrid swap is a single swap that splits execution between the on-chain limit order book and the AMM liquidity pool. From the user's perspective:

**Step 1: Select pair and enter amount**
- User selects token pair (e.g. TKNA/TKNB)
- Enters total swap amount
- Frontend shows estimated output (pool-only simulation — L8 caveat)

**Step 2: Frontend computes split (future — currently manual)**
- Frontend determines pool_input vs book_input allocation
- Shows breakdown: "X via limit book, Y via pool"
- Shows max_maker_fills cap
- Shows fee estimate (pool fee + book fee are separate paths)

**Step 3: Approve CW20 spend (if needed)**
- User approves token transfer to the pair contract via CW20 send

**Step 4: Submit hybrid swap**
- User signs and broadcasts the CW20 Send with Swap hook containing HybridSwapParams
- Transaction includes: pool_input, book_input, max_maker_fills, optional book_start_hint

**Step 5: View result**
- Frontend shows total received (book + pool combined)
- Transaction history shows pool_return_amount and book_return_amount breakdown
- Any unfilled book portion rolls into the pool leg

---

## 2. Expected State Changes

### 2a. Contract State (Pair)

| State | Before Swap | After Swap |
|-------|-------------|------------|
| Pool reserves (token0) | R0 | R0 + pool_input (+ any book remainder rolled to pool) |
| Pool reserves (token1) | R1 | R1 - pool_return_amount |
| Book: matched bid orders | Active, escrow held | Filled or partially filled, escrow released to taker |
| Book: pending_escrow | Sum of all resting order escrows | Reduced by filled amounts |
| Maker balances | Escrow locked in pair | Receive taker's offer token (minus book fee to treasury) |
| Taker balance (offer) | Has offer_amount | Reduced by offer_amount (pool_input + book_input) |
| Taker balance (receive) | Previous balance | Increased by return_amount (pool_return + book_return) |
| Fee collector / treasury | Previous balance | Receives pool commission_amount + book-side fees |
| TWAP oracle | Previous sample | New observation recorded BEFORE reserves change |
| LP token supply | Unchanged | Unchanged (swaps don't mint/burn LP) |

### 2b. Indexer State

| Table | Change |
|-------|--------|
| swap_events | New row with pool_return_amount, book_return_amount, limit_book_offer_consumed, effective_fee_bps |
| limit_order_fills | One row per maker fill (order_id, side, maker, price, token0_amount, token1_amount, commission_amount) |
| pair_stats | Updated volume, fees, last_swap_at |
| token_prices | Updated if this pair is a price source |

### 2c. Frontend State

| Component | Change |
|-----------|--------|
| Token balances | Offer token decreased, receive token increased |
| Pool reserves display | Updated within refetch interval |
| Price chart | New candle/tick reflecting the swap price |
| Transaction history | New entry showing hybrid breakdown |
| Order book display (future) | Filled orders removed, partial fills updated |

---

## 3. What Could Go Wrong

### 3a. Contract Level

| Failure Mode | Cause | Impact | Severity |
|-------------|-------|--------|----------|
| HybridSplitMismatch | pool_input + book_input != CW20 send amount | Tx reverts, no funds lost | Medium (UX confusion) |
| max_maker_fills exceeded | Deep book with many small orders | Swap completes with fewer fills than expected, remainder goes to pool | Low |
| Stale book_start_hint | Order was cancelled/filled between query and execution | Falls back to book head walk, slightly more gas | Low |
| Book empty, book_input > 0 | No resting orders on the relevant side | All book_input rolls to pool leg | Low (by design) |
| Expired order in match path | Order's expires_at < block_time during walk | Order unlinked, escrow decremented, no maker transfer — tokens follow sweep rules | Medium |
| MAX_ADJUST_STEPS_HARD_CAP hit | Insert position too far from head | PlaceLimitOrder reverts | Medium |
| Pair paused | Governance action | Swap reverts (L6). CancelLimitOrder still works. | High |
| Pool-only simulation used for hybrid quote | Router simulate_swap_operations ignores book (L8) | User sees inaccurate estimated output, actual may be better or worse | High (user safety) |
| Hook commission_amount reflects pool only | AfterSwap hook doesn't include book fees (L7) | Integrators/indexers that assume commission = total fee get wrong numbers | High (data integrity) |
| Rounding in decimal normalization | Different token decimals across legs | Dust amounts lost or gained | Low |
| Front-running: sandwich the pool leg | MEV bot detects pool_input and sandwiches | User gets worse pool price; book leg unaffected | High (mainnet) |

### 3b. Indexer Level

| Failure Mode | Cause | Impact |
|-------------|-------|--------|
| Missing limit_order_fill events | Indexer doesn't parse wasm sub-events | Fill history incomplete |
| Wrong fee attribution | Indexer uses hook commission_amount as total fee (L7) | Fee stats inflated/deflated |
| Stale route/solve | Indexer returns hybrid: null, client doesn't patch | User gets pool-only swap instead of hybrid |
| estimated_amount_out diverges from execution | Simulation is pool-only (L8), real swap hits book | User confused by different amounts |
| Parallel test DB conflicts | Integration tests share seed data (#45) | False test failures |

### 3c. Frontend Level

| Failure Mode | Cause | Impact |
|-------------|-------|--------|
| Estimated output misleads user | Pool-only simulation shown for hybrid swap (L8) | User expects X, gets Y |
| No hybrid breakdown shown | Frontend doesn't display pool vs book split | User can't understand execution |
| Split calculation error | Frontend computes wrong pool_input/book_input | HybridSplitMismatch revert or suboptimal execution |
| Stale order book data | Book not refreshed before swap | book_start_hint points to filled/cancelled order |
| No max_maker_fills warning | User doesn't understand partial book execution | Confusion about received amount |
| Fee display wrong | Shows only pool fee, not book fee | User underestimates total cost |

---

## 4. Frontend Must Show (User Safety)

### 4a. Pre-Swap (Critical)

| Element | Why | Priority |
|---------|-----|----------|
| "Estimate is pool-only" disclaimer | L8 — simulation ignores book. User must know the quote may differ from execution. | P0 |
| Pool vs book split breakdown | User needs to understand where their tokens go | P0 |
| max_maker_fills setting | User should know how many book orders will be attempted | P1 |
| Total fee estimate (pool + book) | L7 — hook commission is pool-only. Must show combined fee estimate. | P0 |
| Slippage / max_spread setting | Protects against pool leg price movement | P0 |
| Order book depth (when available) | Helps user decide split ratio | P1 |

### 4b. Post-Swap (Critical)

| Element | Why | Priority |
|---------|-----|----------|
| Actual pool_return_amount | User sees what the pool leg returned | P0 |
| Actual book_return_amount | User sees what the book leg returned | P0 |
| Number of makers filled | Transparency on book execution | P1 |
| Total fees paid (pool + book) | Accurate cost accounting | P0 |
| Per-fill details (expandable) | Advanced users want to see each fill | P2 |
| Difference from estimate | User can see if simulation diverged from reality | P1 |

### 4c. Error States

| State | Display |
|-------|---------|
| HybridSplitMismatch | "Split amounts don't add up. Please retry." |
| Pair paused | "Trading is paused by governance. You can still cancel existing limit orders." |
| All book orders expired | "No active orders in book. Full amount routed to pool." |
| Transaction failed | Show error with revert reason, don't regress to step 1 |
| Wallet disconnected mid-swap | Clear state, show reconnect prompt |

---

## 5. Automation vs Manual QA

### 5a. Automate First (Cheapest, Highest ROI)

| What | How | Why Automate |
|------|-----|-------------|
| pool_input + book_input == send amount | Contract unit test (exists: 297/297) | Deterministic, runs on every commit, catches regressions instantly |
| HybridSplitMismatch revert | Contract unit test (exists) | Same |
| Paused pair blocks swap but allows cancel (L6) | Contract unit test (exists: `pause_blocks_swap_and_place_cancel_refunds_escrow`) | Security-critical invariant |
| Router simulation ignores book (L8) | Contract unit test (exists: `router_simulate_ignores_hybrid_book`) | Critical safety invariant |
| Tx attributes emitted (pool_return, book_return, limit_book_offer_consumed) | Contract integration test or indexer test parsing tx events | Indexer depends on these; breakage is silent |
| Indexer persists fill events | Indexer integration test (needs Postgres, --test-threads=1) | Data integrity for analytics and user history |
| route/solve returns valid path | Indexer API test (exists: api_route_solve.rs) | Core routing correctness |
| estimated_amount_out matches simulation | Indexer API test with ROUTER_ADDRESS set | Catches LCD query failures |
| FIFO ordering (lower order_id fills first at same price) | Contract unit test (exists) | Ordering invariant |
| max_maker_fills cap respected | Contract unit test (exists) | Prevents gas-unbounded execution |
| Wasm checksum matches build | CI script: sha256sum artifacts vs on-chain query | Catches deploy mismatches |
| Balance changes (taker, maker, treasury) | Contract test with before/after balance assertions | Accounting correctness |

### 5b. Automate Next (Medium Effort)

| What | How | Why |
|------|-----|-----|
| E2E hybrid swap via LocalTerra | Playwright or CLI script: place limit order, execute hybrid swap, verify balances | Catches integration bugs across contract+indexer+frontend |
| Frontend displays pool vs book split | Playwright DOM assertion (once frontend supports hybrid) | User safety verification |
| Fee display accuracy | Playwright: compare displayed fee vs actual tx fee in events | L7 compliance |
| Order book state after partial fill | CLI script: place order, partial fill, query remaining size | State consistency |
| Expired order handling in match walk | Contract test with mock block_time advancement | Edge case that's hard to test manually |

### 5c. Manual QA (Keep Manual)

| What | Why Manual |
|------|-----------|
| Visual inspection of hybrid swap UI | Subjective UX quality; layout, colors, readability on multiple devices |
| Mobile viewport testing | Too many device combinations; responsive design is visual |
| "Does the user understand what's happening?" | Cognitive UX testing -- can a non-technical user complete a hybrid swap safely? |
| Cross-browser wallet integration | Keplr, Station, Leap all behave differently; interaction quirks |
| Network condition testing (slow RPC, timeout) | Hard to automate realistically; manual chaos testing |
| New feature exploratory testing | First pass on any new UI before writing automated tests |
| Security review of new contract logic | Requires human reasoning about attack vectors |

---

## Appendix A: Key Code Locations

| Component | File | Function/Section |
|-----------|------|-----------------|
| Hybrid swap execution | contracts/pair/src/contract.rs | execute_swap() |
| Book matching | contracts/pair/src/orderbook.rs | match_bids(), match_asks() |
| HybridSwapParams type | packages/dex-common/src/pair.rs | HybridSwapParams struct |
| Router hybrid passthrough | contracts/router/src/contract.rs | execute_swap_operation() |
| Indexer fill persistence | indexer/src/indexer/ | swap event handler |
| Indexer route solver | indexer/src/api/ | route/solve endpoint |
| Frontend swap form | frontend-dapp/src/pages/SwapPage.tsx | (future hybrid UI) |
| Limit order tests | tests/src/limit_order_tests.rs | All hybrid/limit tests |
| Security invariants | docs/contracts-security-audit.md | L6, L7, L8 |

## Appendix B: Existing Test Coverage

| Layer | Count | Status |
|-------|-------|--------|
| Contract unit/integration | 297/297 | All pass |
| Indexer lib | 30/30 | All pass |
| Indexer integration | 138/138 | All pass (serial) |
| Frontend Vitest | (DEX frontend tests TBD) | |
| Playwright E2E | Blocked (no browser on QA server) | |
| On-chain verification | Manual (verified 3/28: txhash 25532C4A) | |

## Appendix C: Open Gaps

1. Frontend has no hybrid swap UI yet (dev building limit order frontend integration)
2. Indexer route/solve returns hybrid: null -- clients must patch hybrid off-chain
3. No automated E2E test for full hybrid flow (place limit -> hybrid swap -> verify fills)
4. estimated_amount_out from route/solve is pool-only, no hybrid-aware estimation exists
5. Playwright blocked on QA server (no browser installed)
6. ROUTER_ADDRESS not auto-set by deploy script (manual step, noted on #42)
7. Book-side fee attribution not exposed separately in indexer API (only pool commission in AfterSwap hook per L7)

---

*This spec is a living document. Update after each session as frontend integration progresses and new automated tests are added.*
