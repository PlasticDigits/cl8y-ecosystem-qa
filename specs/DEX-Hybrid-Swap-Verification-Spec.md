# CL8Y DEX — Hybrid Swap Verification Spec
> Flow: Hybrid Swap (AMM Pool + FIFO Limit Book)
> Author: @Brouie (AVE)
> Version: 3.0 — 2026-04-01
> Repo: cl8y-dex-terraclassic
> Reference: docs/limit-orders.md, contracts-security-audit.md (L6-L8)
> Status legend: [CURRENT] = implemented and verified, [FUTURE] = not yet implemented
> v3 changes: Limit Orders UI landed, ROUTER_ADDRESS auto-set, test counts updated, release gate items checked off, new findings from 4/1 QA session

---

## 1. User-Visible Steps

A hybrid swap splits execution between the on-chain limit order book and the AMM liquidity pool.

**Step 1: Select pair and enter amount**
- [CURRENT] User selects token pair and enters swap amount
- [CURRENT] Frontend shows estimated output via pool-only simulation (L8 caveat)
- [CURRENT] Pool reserves, fee %, price impact, min received all display correctly
- [FUTURE] Frontend shows disclaimer that estimate is pool-only and may differ from hybrid execution

**Step 2: Configure split**
- [CURRENT] Limit Orders page exists (LimitOrdersPage.tsx) with pair selector, bid/ask toggle, price, amount, max_adjust_steps, expiry
- [CURRENT] Place and cancel limit order transactions work via Keplr
- [CURRENT] Indexer picks up placed orders ("YOUR RECENT PLACEMENTS" section)
- [FUTURE] Frontend computes optimal pool_input vs book_input allocation for hybrid swap
- [FUTURE] Shows breakdown: "X via limit book, Y via pool"
- [FUTURE] Shows max_maker_fills cap and fee estimate (pool + book separate)

**Step 3: Approve CW20 spend**
- [CURRENT] User approves token transfer to pair contract via CW20 send
- [CURRENT] Works for both pool-only and hybrid swaps

**Step 4: Submit hybrid swap**
- [CURRENT] Contract accepts CW20 Send with Swap hook containing HybridSwapParams
- [CURRENT] Executes book leg first (up to max_maker_fills), then pool leg
- [CURRENT] Pool-only swaps confirmed working (EMBER/CORAL swap success 4/1)
- [CURRENT] High price impact correctly rejected (ONYX/CORAL 9.17% > 2% tolerance)
- [FUTURE] Frontend constructs and submits HybridSwapParams automatically

**Step 5: View result**
- [CURRENT] Tx attributes emitted: pool_return_amount, book_return_amount, limit_book_offer_consumed (verified txhash 25532C4A)
- [CURRENT] Swap success shows tx hash with link (minor: hash overflow in success box)
- [FUTURE] Frontend shows pool vs book breakdown in transaction history
- [FUTURE] Frontend shows per-fill details (expandable)

---

## 2. Expected State Changes

### 2a. Contract State (Pair) [CURRENT -- all verified via 297+/297+ tests]

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

### 2b. Indexer State [CURRENT -- 138/138 integration tests, verified on-chain]

| Table | Change | Status |
|-------|--------|--------|
| swap_events | New row with pool_return_amount, book_return_amount, limit_book_offer_consumed, effective_fee_bps | [CURRENT] |
| limit_order_fills | One row per maker fill (order_id, side, maker, price, token0_amount, token1_amount, commission_amount) | [CURRENT] |
| limit_order_placements | Indexed from wasm place_limit_order events | [CURRENT] verified 4/1 (order #1 bid pickup) |
| limit_order_cancellations | Indexed from wasm cancel_limit_order events | [CURRENT] |
| pair_stats | Updated volume, fees, last_swap_at | [CURRENT] |
| token_prices | Updated if this pair is a price source | [CURRENT] |

### 2c. Frontend State

| Component | Change | Status |
|-----------|--------|--------|
| Token balances | Offer token decreased, receive token increased | [CURRENT] |
| Pool reserves display | Updated within refetch interval | [CURRENT] verified 4/1 (96.00K/94.01K) |
| Price chart | New candle/tick reflecting the swap price | [CURRENT] |
| Transaction history | Shows swap entry | [CURRENT] basic, [FUTURE] hybrid breakdown |
| Limit order placements | Shows in "YOUR RECENT PLACEMENTS" via indexer | [CURRENT] verified 4/1 |
| Order book display | Filled orders removed, partial fills updated | [FUTURE] |
| Hybrid split breakdown | Shows pool vs book allocation pre/post swap | [FUTURE] |

---

## 3. What Could Go Wrong

### 3a. Contract Level [CURRENT -- covered by 297+/297+ tests]

| Failure Mode | Cause | Impact | Severity | Test Coverage |
|-------------|-------|--------|----------|---------------|
| HybridSplitMismatch | pool_input + book_input != CW20 send amount | Tx reverts, no funds lost | Medium | [CURRENT] unit test exists |
| max_maker_fills exceeded | Deep book with many small orders | Remainder goes to pool | Low | [CURRENT] unit test exists |
| Stale book_start_hint | Order cancelled/filled between query and execution | Falls back to book head walk | Low | [CURRENT] handled in contract |
| Book empty, book_input > 0 | No resting orders | All rolls to pool leg | Low | [CURRENT] by design |
| Expired order in match path | expires_at < block_time | Order unlinked, follows sweep rules | Medium | [CURRENT] contract handles |
| MAX_ADJUST_STEPS_HARD_CAP hit | Insert too far from head | PlaceLimitOrder reverts | Medium | [CURRENT] unit test exists |
| Pair paused (L6) | Governance action | Swap reverts. CancelLimitOrder still works. | High | [CURRENT] `pause_blocks_swap_and_place_cancel_refunds_escrow` |
| Pool-only simulation for hybrid (L8) | Router ignores book | User sees inaccurate estimate | High | [CURRENT] `router_simulate_ignores_hybrid_book` |
| Hook commission pool-only (L7) | AfterSwap excludes book fees | Integrators get wrong fee totals | High | [CURRENT] documented invariant |
| Rounding in decimal normalization | Different token decimals | Dust amounts lost/gained | Low | [CURRENT] proptest 4096 cases |
| Front-running pool leg | MEV sandwich attack | Worse pool price; book leg unaffected | High | [FUTURE] mainnet mitigation needed |
| Max spread assertion rejects | Actual spread exceeds max_allowed | Swap reverts | Low | [CURRENT] verified 4/1 (ONYX/CORAL 9.17% > 2%) |

### 3b. Indexer Level

| Failure Mode | Cause | Impact | Status |
|-------------|-------|--------|--------|
| Missing limit_order_fill events | Indexer doesn't parse wasm sub-events | Fill history incomplete | [CURRENT] indexed in limit_order_fills table |
| Wrong fee attribution (L7) | Uses hook commission as total fee | Fee stats wrong | [CURRENT] book-side fees stored separately |
| Stale route/solve | Returns hybrid: null, client doesn't patch | Pool-only swap | [CURRENT] by design -- clients patch |
| estimated_amount_out diverges | Simulation pool-only (L8), real swap hits book | User confusion | [CURRENT] known limitation, documented |
| Parallel test DB conflicts (#45) | Tests share seed data | False failures | [CURRENT] workaround: --test-threads=1 |
| ROUTER_ADDRESS not set | Deploy script doesn't write to indexer .env | No estimated_amount_out | [CURRENT] FIXED -- deploy script auto-sets (verified #42 4/1) |

### 3c. Frontend Level

| Failure Mode | Cause | Impact | Status |
|-------------|-------|--------|--------|
| Estimated output misleads user | Pool-only simulation for hybrid (L8) | User expects X, gets Y | [FUTURE] needs disclaimer |
| No hybrid breakdown shown | Frontend doesn't display split | User can't understand execution | [FUTURE] needs implementation |
| Split calculation error | Wrong pool_input/book_input | Revert or bad execution | [FUTURE] needs implementation |
| Stale order book data | Book not refreshed before swap | Stale hints | [FUTURE] needs implementation |
| No max_maker_fills warning | User doesn't understand partial fills | Confusion | [FUTURE] needs implementation |
| Fee display wrong | Shows only pool fee | Underestimated cost | [FUTURE] needs combined display |
| Dark mode dropdown invisible | White text on white bg | Pair selector unusable in dark mode | [CURRENT] BUG filed #44 (4/1) |
| Limit order pair dropdown overlap | Dropdown overlaps form on mobile | UX issue on narrow viewports | [CURRENT] BUG filed #44 (4/1) |
| Tx hash overflow in success box | Hash text not truncated | Visual overflow | [CURRENT] BUG noted 4/1 |
| BigInt crash on large amounts | Scientific notation (e.g. 5e+23) | UI goes blank | [CURRENT] bridge #95 -- same pattern may affect DEX |

---

## 4. Frontend Must Show (User Safety)

### 4a. Pre-Swap

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| "Estimate is pool-only" disclaimer | L8 -- quote may differ from hybrid execution | P0 | [FUTURE] |
| Pool vs book split breakdown | User needs to understand allocation | P0 | [FUTURE] |
| max_maker_fills setting | Transparency on book execution limit | P1 | [CURRENT] exists in Limit Orders as "MAX ADJUST STEPS" |
| Total fee estimate (pool + book) | L7 -- hook commission is pool-only | P0 | [FUTURE] |
| Slippage / max_spread setting | Protects pool leg | P0 | [CURRENT] exists with 0.1%/0.5%/1%/custom presets |
| Order book depth | Helps user decide split | P1 | [FUTURE] |
| "Hold CL8Y to reduce swap fees" | Fee discount transparency | P2 | [CURRENT] shown in swap form |

### 4b. Post-Swap

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| Actual pool_return_amount | Pool leg transparency | P0 | [FUTURE] display; [CURRENT] in tx attributes |
| Actual book_return_amount | Book leg transparency | P0 | [FUTURE] display; [CURRENT] in tx attributes |
| Number of makers filled | Execution transparency | P1 | [FUTURE] display; [CURRENT] in indexer |
| Total fees paid (pool + book) | Cost accounting | P0 | [FUTURE] combined display |
| Per-fill details | Advanced user needs | P2 | [FUTURE] display; [CURRENT] via indexer API |
| Difference from estimate | Reality vs prediction | P1 | [FUTURE] |

### 4c. Error States

| State | Display | Status |
|-------|---------|--------|
| HybridSplitMismatch | "Split amounts don't add up. Please retry." | [FUTURE] |
| Pair paused | "Trading paused. You can still cancel limit orders." | [FUTURE] |
| All book orders expired | "No active orders. Full amount routed to pool." | [FUTURE] |
| Transaction failed | Show revert reason, stay on current step | [CURRENT] verified 4/1 (spread assertion revert shown correctly) |
| Wallet disconnected mid-swap | Clear state, show reconnect prompt | [CURRENT] |
| Max spread exceeded | Show actual vs allowed spread | [CURRENT] error message displays both values |

---

## 5. Automation vs Manual QA

### 5a. Automate First (Cheapest, Highest ROI) [CURRENT -- most already exist]

| What | How | Status |
|------|-----|--------|
| pool_input + book_input == send amount | Contract unit test | [CURRENT] exists in 297+ tests |
| HybridSplitMismatch revert | Contract unit test | [CURRENT] exists |
| Paused pair blocks swap, allows cancel (L6) | Contract unit test | [CURRENT] exists |
| Router simulation ignores book (L8) | Contract unit test | [CURRENT] exists |
| Tx attributes emitted | Contract integration test | [CURRENT] verified on-chain txhash 25532C4A |
| Indexer persists fill events | Indexer integration test | [CURRENT] 138/138 pass |
| route/solve returns valid path | Indexer API test | [CURRENT] api_route_solve.rs |
| estimated_amount_out matches simulation | Indexer API test | [CURRENT] verified with ROUTER_ADDRESS |
| FIFO ordering at same price | Contract unit test | [CURRENT] exists |
| max_maker_fills cap | Contract unit test | [CURRENT] exists |
| Wasm checksum matches build | sha256sum artifacts vs on-chain | [CURRENT] verified pair+router 3/28 |
| Balance changes (taker, maker, treasury) | Contract test | [CURRENT] exists |
| Limit order placement indexer pickup | Indexer integration test | [CURRENT] verified 4/1 manual + automated |
| Limit order security tests | Contract test | [CURRENT] 132+ limit order tests in tests/src/limit_order_tests.rs |
| Indexer security tests | Indexer test | [CURRENT] 55+ tests in indexer/tests/security.rs |

### 5b. Automate Next (Medium Effort) [FUTURE]

| What | How | Blocked By |
|------|-----|-----------|
| E2E hybrid swap via LocalTerra | Playwright or CLI script | Frontend hybrid UI needed (limit orders UI exists, hybrid swap form pending) |
| Frontend displays pool vs book split | Playwright DOM assertion | Frontend hybrid UI needed |
| Fee display accuracy | Playwright: compare displayed vs actual | Frontend hybrid UI needed |
| Order book state after partial fill | CLI script: place, partial fill, query | Nothing -- can build now |
| Expired order handling in match walk | Contract test with mock block_time | Nothing -- can build now |
| Limit order place/cancel E2E | Playwright: select pair, place bid, verify indexer, cancel | [CURRENT] manual verified, needs automation |

### 5c. Manual QA (Keep Manual)

| What | Why Manual |
|------|-----------|
| Visual inspection of hybrid swap UI | Subjective UX quality |
| Dark mode theme validation | Color contrast, text visibility (#44) |
| Mobile viewport testing | Too many device combinations |
| "Does the user understand?" | Cognitive UX testing |
| Cross-browser wallet integration | Keplr, Station, Leap quirks |
| Network condition testing | Hard to automate realistically |
| New feature exploratory testing | First pass before automation |
| Security review of new contract logic | Human reasoning required |

---

## 6. Release Gate Checklist

Minimum must-complete and verify items before hybrid swap can ship to production.

### 6a. Contract (Must Pass)

- [x] 297+/297+ contract tests pass (including all limit order + security tests) -- verified 4/1
- [x] HybridSplitMismatch revert confirmed (pool_input + book_input != amount)
- [x] Paused pair blocks swap but allows CancelLimitOrder (L6)
- [x] Router simulation ignores hybrid/book (L8) -- documented and tested
- [x] AfterSwap hook commission is pool-only (L7) -- documented
- [x] FIFO ordering verified at same price level
- [x] max_maker_fills cap enforced
- [x] Expired order handling in match walk correct
- [ ] Wasm checksums (pair + router) match build artifacts on deployed chain -- needs re-verify with latest build
- [x] No new clippy warnings or test regressions after merge

### 6b. Indexer (Must Pass)

- [x] 138/138 indexer integration tests pass (serial, --test-threads=1)
- [ ] 30/30 indexer lib tests pass -- needs recount with new tests
- [x] swap_events table stores pool_return_amount, book_return_amount, limit_book_offer_consumed
- [x] limit_order_fills table populated per maker fill
- [x] route/solve returns valid paths (pool-only with hybrid: null)
- [x] estimated_amount_out populated when ROUTER_ADDRESS set
- [x] ROUTER_ADDRESS set in indexer .env (deploy script auto-sets) -- verified #42 4/1

### 6c. Frontend (Must Pass Before Hybrid UI Ships)

- [x] Pool-only swap flow unchanged (no regression) -- verified 4/1 (EMBER/CORAL success)
- [ ] L8 disclaimer shown when hybrid is selected ("estimate is pool-only")
- [ ] Pool vs book split breakdown visible pre-swap
- [ ] Combined fee estimate shown (pool + book)
- [ ] Post-swap: pool_return_amount and book_return_amount displayed
- [ ] Transaction history shows hybrid breakdown
- [x] Error states don't regress to step 1 -- verified 4/1 (spread assertion shown, stays on form)
- [x] Wallet disconnect handled gracefully
- [ ] Mobile viewports tested -- partial: dark mode dropdown issues (#44), limit orders overlap
- [x] Limit order place/cancel works via UI -- verified 4/1 (EMBER/CORAL bid placed, indexer pickup)
- [ ] Dark mode dropdown text visible (#44)
- [ ] Tx hash overflow fixed in success/status boxes

### 6d. Integration (Must Pass)

- [ ] Full E2E: place limit order -> hybrid swap -> verify maker receives tokens -> verify taker receives tokens -> verify indexer records fills
- [ ] Fee accounting: pool commission + book treasury fees sum to expected total
- [x] On-chain tx attributes match indexer records -- verified 3/28
- [ ] Playwright E2E passes (needs browser on QA server or local runner)
- [x] Limit order placement -> indexer pickup -- verified 4/1

### 6e. Security (Must Review)

- [ ] No new attack vectors from hybrid swap path (review execute_swap changes)
- [ ] MEV sandwich risk documented for pool leg (mainnet consideration)
- [x] Decimal normalization verified across token pairs with different decimals (proptest 4096 cases)
- [ ] Rate limiting applies to hybrid swaps same as pool-only

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
| Frontend swap form | frontend-dapp/src/pages/SwapPage.tsx | Pool-only swap + settings |
| Limit orders UI | frontend-dapp/src/pages/LimitOrdersPage.tsx | Pair selector, place/cancel |
| Portal listbox (shared) | frontend-dapp/src/components/ui/PortalListbox.tsx | MenuSelect + TokenSelect |
| Limit order tests | tests/src/limit_order_tests.rs | All hybrid/limit tests (132+) |
| Indexer security tests | indexer/tests/security.rs | 55+ security tests |
| Security invariants | docs/contracts-security-audit.md | L6, L7, L8 |
| QA scripts | scripts/qa/ | start-qa, stop-qa, status, tunnel help |

## Appendix B: Existing Test Coverage

| Layer | Count | Status |
|-------|-------|--------|
| Contract unit/integration | 297+ (recount needed with limit order additions) | [CURRENT] All pass |
| Indexer lib | 30+ (recount needed) | [CURRENT] All pass |
| Indexer integration | 138/138 | [CURRENT] All pass (serial) |
| Indexer security | 55+ | [CURRENT] All pass |
| Frontend Vitest | TBD | [FUTURE] |
| Playwright E2E | 1 spec (limit-orders.spec.ts) | [CURRENT] exists, needs runner |
| On-chain hybrid verification | Manual | [CURRENT] verified 3/28: txhash 25532C4A |
| Limit order manual E2E | Manual | [CURRENT] verified 4/1: place bid, indexer pickup |

## Appendix C: Open Gaps (Current -> Future)

| Gap | Current State | Future State | Blocked By | Updated |
|-----|--------------|--------------|-----------|---------|
| Frontend hybrid UI | Limit orders page exists; hybrid swap form pending | Full hybrid swap form with split controls | Dev building frontend integration | 4/1 |
| Hybrid-aware estimation | Pool-only simulation (L8) | Estimation that includes book depth | Needs new query or off-chain calculation | -- |
| E2E automated test | Manual + 1 Playwright spec | Full Playwright flow test | Browser on QA server or local runner | 4/1 |
| ~~ROUTER_ADDRESS auto-set~~ | ~~Manual step in indexer .env~~ | ~~Deploy script sets it~~ | ~~CLOSED~~ verified 4/1 | 4/1 |
| Book-side fee display | Not shown in frontend | Combined pool+book fee display | Frontend hybrid UI | -- |
| Order book visualization | No UI | Live book depth display | Frontend integration | -- |
| Indexer limit order HTTP endpoints | Verified working (placements pickup) | Full QA coverage of /limit-fills, /limit-placements, /limit-cancellations | Need test plan | 4/1 |
| Dark mode dropdown styling | White text on white bg (#44) | Dark-mode-aware dropdown | Dev fix needed | 4/1 |
| Limit orders mobile viewport | Pair dropdown overlaps form (#44) | Clean mobile layout | Dev fix needed | 4/1 |
| DEX QA scripts | make start-qa/stop-qa/status/qa-tunnel-help landed | Tested on VPS | First run 4/1, CORS workaround needed (port 3000) | 4/1 |

---

*This spec is a living document. Update after each session as frontend integration progresses and new automated tests are added.*
*v3 updated 2026-04-01 by @Brouie after full DEX QA session: limit orders verified, ROUTER_ADDRESS gap closed, release gate items checked, new UI bugs documented.*
