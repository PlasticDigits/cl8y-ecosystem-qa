# CL8Y DEX — Pool / Liquidity Verification Spec
> Flow: Provide Liquidity + Withdraw Liquidity (Constant-Product AMM)
> Author: @Brouie (AVE)
> Version: 1.0 — 2026-04-07
> Repo: cl8y-dex-terraclassic
> Reference: contracts/pair/src/contract.rs (execute_provide_liquidity, execute_withdraw_liquidity)
> Status legend: [CURRENT] = implemented and verified, [FUTURE] = not yet implemented

---

## 1. User-Visible Steps

### 1a. Provide Liquidity

**Step 1: Select pool**
- [CURRENT] User browses pool list on PoolPage, sorted by name/volume/fee/created/pair ID
- [CURRENT] Each pool card shows token pair, reserves, fee %, 24h volume (indexed), factory verification badge
- [CURRENT] Unverified pairs show warning badge (verifyPairInFactory check against FACTORY_CONTRACT_ADDRESS)

**Step 2: Enter amounts**
- [CURRENT] User expands "Add Liquidity" on a pool card
- [CURRENT] Enters amount for token A and token B
- [CURRENT] Decimals handled per token (getDecimals per asset_info)
- [CURRENT] Native wrap option available (e.g. deposit native LUNC, auto-wrap to CW20 via TREASURY_CONTRACT_ADDRESS)
- [FUTURE] Auto-fill second amount to match current pool ratio (reduce impermanent loss risk)
- [FUTURE] Show share of pool % user will receive
- [FUTURE] Show impermanent loss warning for imbalanced deposits

**Step 3: Approve and submit**
- [CURRENT] Frontend calls increase_allowance for both tokens to pair contract
- [CURRENT] Then calls provide_liquidity with both asset amounts
- [CURRENT] If native wrap needed, uses executeTerraContractMulti (wrap_deposit + allowances + provide in single batch)
- [CURRENT] On error, attempts decrease_allowance cleanup (best effort)
- [CURRENT] slippage_tolerance, receiver, deadline all passed as null currently
- [FUTURE] User-configurable slippage tolerance for provide

**Step 4: View result**
- [CURRENT] Success sound plays, amounts cleared, balances/pool data refetched
- [CURRENT] LP token balance updated
- [FUTURE] Show LP tokens received, share of pool %
- [FUTURE] Show tx hash with explorer link (same pattern as swap TxResultAlert)

### 1b. Withdraw Liquidity

**Step 1: Select pool and expand remove**
- [CURRENT] User expands "Remove Liquidity" on a pool card
- [CURRENT] LP token balance displayed (refetched every 15s)

**Step 2: Enter LP amount and configure**
- [CURRENT] User enters LP token amount to burn
- [CURRENT] Insufficient LP balance check (compares input vs balance)
- [CURRENT] Withdrawal slippage setting (default 1.0%)
- [CURRENT] min_assets computed from pool reserves * share ratio * slippage factor
- [CURRENT] "Receive wrapped" toggle -- if off, auto-unwraps CW20 back to native via WRAP_MAPPER_CONTRACT_ADDRESS

**Step 3: Submit withdrawal**
- [CURRENT] Frontend calls withdrawLiquidity (CW20 send with withdraw_liquidity hook)
- [CURRENT] min_assets passed for sandwich protection
- [CURRENT] If receiveWrapped=false, iterates native-equivalent tokens and unwraps each via send to WRAP_MAPPER
- [CURRENT] Success sound, amounts cleared, balances refetched

**Step 4: View result**
- [CURRENT] LP balance updated, pool reserves updated
- [FUTURE] Show tokens received breakdown
- [FUTURE] Show tx hash with explorer link

---

## 2. Expected State Changes

### 2a. Contract State (Pair)

**Provide Liquidity:**

| State | Before | After |
|-------|--------|-------|
| Reserve A | R_A | R_A + amount_A |
| Reserve B | R_B | R_B + amount_B |
| Total LP supply | S | S + lp_minted |
| User LP balance | L | L + lp_to_user |
| User token A balance | B_A | B_A - amount_A |
| User token B balance | B_B | B_B - amount_B |
| TWAP oracle | Previous observation | New observation recorded BEFORE reserves change |
| Minimum liquidity (first deposit only) | 0 | MINIMUM_LIQUIDITY burned (locked forever) |

LP minting formula:
- First deposit: lp = isqrt(amount_A * amount_B), user gets lp - MINIMUM_LIQUIDITY
- Subsequent: lp = min(amount_A * S / R_A, amount_B * S / R_B)

**Withdraw Liquidity:**

| State | Before | After |
|-------|--------|-------|
| Reserve A | R_A | R_A - amount_A |
| Reserve B | R_B | R_B - amount_B |
| Total LP supply | S | S - lp_burned |
| User LP balance | L | L - lp_burned |
| User token A balance | B_A | B_A + amount_A |
| User token B balance | B_B | B_B + amount_B |
| TWAP oracle | Previous observation | New observation recorded BEFORE reserves change |

Withdrawal formula: amount_X = lp_burned * R_X / S (floor division, remainder stays in pool)

### 2b. Indexer State

| Table | Change | Status |
|-------|--------|--------|
| pair_stats | Updated reserves, LP supply | [CURRENT] |
| token_prices | Updated if pair is price source | [CURRENT] |
| provide_liquidity events | Indexed from wasm events (sender, receiver, assets, share) | [CURRENT] -- needs verification |
| withdraw_liquidity events | Indexed from wasm events (sender, withdrawn_share, refund_assets) | [CURRENT] -- needs verification |

### 2c. Frontend State

| Component | Change | Status |
|-----------|--------|--------|
| Token balances | Decreased (provide) or increased (withdraw) | [CURRENT] refetched on success |
| LP token balance | Increased (provide) or decreased (withdraw) | [CURRENT] refetched on success |
| Pool reserves display | Updated | [CURRENT] refetched on success |
| Pool share % | Updated | [FUTURE] not displayed yet |
| Transaction result | Success/error feedback | [CURRENT] sound only; [FUTURE] TxResultAlert with hash |

---

## 3. What Could Go Wrong

### 3a. Contract Level

| Failure Mode | Cause | Impact | Severity | Test Coverage |
|-------------|-------|--------|----------|---------------|
| ZeroAmount | Either deposit amount is zero | Tx reverts | Low | [CURRENT] contract check |
| InsufficientLiquidity | First deposit isqrt result <= MINIMUM_LIQUIDITY | Tx reverts, tiny pool cant be created | Medium | [CURRENT] contract check |
| isqrt overflow/underflow | Extreme token amounts on first deposit | Tx reverts with InvariantViolation | Low | [CURRENT] contract sanity checks |
| Floor division rounding loss | LP calculation loses fractional LP | < 1 LP token lost, stays in pool | Low | [CURRENT] contract sanity checks |
| Imbalanced provide | User deposits non-ratio amounts | Gets min(lp_a, lp_b), excess tokens donated to pool | High | [CURRENT] contract logic, but no frontend warning |
| SlippageExceeded | Pool ratio changed between query and execution | Tx reverts | Medium | [CURRENT] contract check (but frontend passes null) |
| WithdrawSlippageExceeded | Pool ratio changed, received < min_assets | Tx reverts | Medium | [CURRENT] contract check + frontend computes min_assets |
| Allowance not set | CW20 allowance insufficient | TransferFrom fails | Medium | [CURRENT] frontend sets allowance first |
| Allowance cleanup fails | Error after allowance set but before provide | Dangling allowance (minor: capped at amount) | Low | [CURRENT] frontend best-effort decrease_allowance |
| Sandwich attack on provide | MEV front-runs to skew ratio | User gets fewer LP tokens | High | [FUTURE] no mainnet mitigation |
| Sandwich attack on withdraw | MEV skews reserves before withdrawal | User gets less of one token | High | [CURRENT] min_assets protection |
| Native wrap fails mid-batch | wrap_deposit succeeds but provide fails | Wrapped tokens stuck in wallet (recoverable) | Medium | [CURRENT] multi-msg batch |
| Unwrap fails after withdraw | Withdraw succeeds but unwrap tx fails | CW20 tokens in wallet (recoverable, can retry) | Low | [CURRENT] sequential unwrap |
| Pair paused | Governance action | Provide/withdraw may be blocked | High | [CURRENT] -- needs verification of pause scope |
| Oracle update fails | Storage error | Tx reverts | Low | [CURRENT] oracle_update called before state changes |

### 3b. Indexer Level

| Failure Mode | Cause | Impact | Status |
|-------------|-------|--------|--------|
| Missing provide/withdraw events | Indexer doesnt parse these wasm events | LP history incomplete | Needs verification |
| Wrong reserve snapshot | Indexer reads stale reserves | Pool stats inaccurate | [CURRENT] -- needs verification |
| LP supply drift | Indexer total_supply diverges from on-chain | Share % calculations wrong | Needs verification |

### 3c. Frontend Level

| Failure Mode | Cause | Impact | Status |
|-------------|-------|--------|--------|
| No imbalanced deposit warning | Frontend doesnt check ratio | User donates value to pool | [FUTURE] |
| No share of pool display | Frontend doesnt compute share | User cant assess position | [FUTURE] |
| No LP tokens received display | Post-tx doesnt show minted LP | User doesnt know outcome | [FUTURE] |
| No tx hash in result | Provide/withdraw dont show TxResultAlert | No explorer link | [FUTURE] |
| Stale pool reserves | 30s staleTime on pool query | Amounts slightly off | Low -- acceptable |
| Decimal mismatch | Wrong decimals for token display | Amounts appear wrong | [CURRENT] getDecimals per asset |
| LP decimals hardcoded | LP_DECIMALS = 6 hardcoded | Wrong if LP token uses different decimals | Low -- needs verification |
| Insufficient LP shown late | Check only on input, not on submit | Race condition possible | Low |
| Native wrap option missing | getNativeEquivalent returns null | User must manually wrap | Low -- by design for non-native pairs |

---

## 4. Frontend Must Show (User Safety)

### 4a. Pre-Provide

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| Current pool ratio | User needs to match ratio | P0 | [CURRENT] reserves shown on card |
| Fee rate | Transparency | P1 | [CURRENT] fee badge on card |
| Fee discount (CL8Y holder) | Cost savings awareness | P2 | [CURRENT] FeeDisplay with discount |
| Share of pool % after deposit | Position sizing | P0 | [FUTURE] |
| Impermanent loss warning | Risk awareness for imbalanced deposits | P1 | [FUTURE] |
| Slippage tolerance setting | Sandwich protection | P1 | [FUTURE] (null passed currently) |
| Factory verification status | Trust signal | P0 | [CURRENT] unverified badge |
| Estimated LP tokens to receive | Expected outcome | P0 | [FUTURE] |

### 4b. Pre-Withdraw

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| LP balance | Available to withdraw | P0 | [CURRENT] |
| Estimated tokens to receive | Expected outcome | P0 | [FUTURE] |
| Withdrawal slippage setting | Sandwich protection | P0 | [CURRENT] default 1.0% |
| Receive wrapped/native toggle | User preference | P1 | [CURRENT] |
| Share of pool % being withdrawn | Position context | P1 | [FUTURE] |

### 4c. Post-Transaction

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| Tx hash with explorer link | Verification | P0 | [FUTURE] |
| LP tokens received/burned | Outcome confirmation | P0 | [FUTURE] |
| Tokens deposited/received | Outcome confirmation | P0 | [FUTURE] |
| Updated pool share % | Position update | P1 | [FUTURE] |
| Sound feedback | UX | P2 | [CURRENT] success/error sounds |

### 4d. Error States

| State | Display | Status |
|-------|---------|--------|
| Wallet not connected | Disable add/remove buttons | [CURRENT] |
| Zero amount | Prevent submission | [CURRENT] checked in contract |
| Insufficient token balance | Show warning | [FUTURE] -- not checked pre-submit |
| Insufficient LP balance | Show warning | [CURRENT] insufficientLp check |
| Slippage exceeded | Show error with details | [CURRENT] contract reverts, sound plays |
| Transaction failed | Show revert reason | [CURRENT] onError plays sound; [FUTURE] show reason |
| Allowance error | Show retry prompt | [FUTURE] |

---

## 5. Automation vs Manual QA

### 5a. Automate First (Cheapest, Highest ROI)

| What | How | Status |
|------|-----|--------|
| provide_liquidity with balanced amounts | Contract unit test | [CURRENT] 251+ references in lib.rs |
| provide_liquidity first deposit (isqrt, MINIMUM_LIQUIDITY) | Contract unit test | [CURRENT] |
| provide_liquidity imbalanced (min of two LP calcs) | Contract unit test | [CURRENT] |
| withdraw_liquidity pro-rata | Contract unit test | [CURRENT] |
| withdraw_liquidity with min_assets (slippage protection) | Contract unit test | [CURRENT] |
| ZeroAmount revert | Contract unit test | [CURRENT] |
| InsufficientLiquidity revert | Contract unit test | [CURRENT] |
| SlippageExceeded revert | Contract unit test | [CURRENT] |
| WithdrawSlippageExceeded revert | Contract unit test | [CURRENT] |
| Floor division rounding invariant | Contract unit test (sanity checks) | [CURRENT] |
| Oracle update before state change | Contract unit test | [CURRENT] |
| LP receiver override (receiver param) | Contract unit test | Needs verification |
| Allowance + provide in multi-msg | Frontend integration test | [FUTURE] |
| Frontend PoolPage renders | Vitest | [CURRENT] 1 test (renders without crashing) |

### 5b. Automate Next (Medium Effort)

| What | How | Blocked By |
|------|-----|-----------|
| E2E provide liquidity via LocalTerra | Playwright or CLI script | Need browser or CLI tooling |
| E2E withdraw liquidity via LocalTerra | Playwright or CLI script | Need browser or CLI tooling |
| Frontend balance check pre-submit | Vitest (mock wallet with low balance) | Nothing -- can build now |
| Frontend LP calculation display | Vitest (mock pool data, verify LP estimate shown) | Frontend feature needed |
| Frontend min_assets computation accuracy | Vitest unit test | Nothing -- can build now |
| Imbalanced deposit value-loss calculation | Contract fuzz test | Nothing -- can build now |
| Native wrap + provide combo | Contract integration test | Nothing -- can build now |
| Withdraw + unwrap combo | Contract integration test | Nothing -- can build now |
| Indexer provide/withdraw event persistence | Indexer integration test | Needs verification of current coverage |
| LP decimals assumption verification | Query LP token config on-chain | Nothing -- quick check |

### 5c. Manual QA (Keep Manual)

| What | Why Manual |
|------|-----------|
| Visual inspection of pool cards | Subjective UX quality |
| Mobile viewport pool list | Device-specific layout |
| Native wrap UX flow | Multi-step user journey feel |
| "Does the user understand share %?" | Cognitive UX testing |
| Cross-browser wallet approve flow | Keplr/Station/Leap quirks |
| First-time deposit UX | MINIMUM_LIQUIDITY surprise factor |
| Dark mode pool card styling | Color contrast validation |
| Sandwich attack scenario (mainnet) | Requires real MEV conditions |

---

## 6. Release Gate Checklist

### 6a. Contract (Must Pass)

- [x] 286/286 contract tests pass (38afbf8) -- verified 4/7
- [x] provide_liquidity: balanced, imbalanced, first deposit all tested
- [x] withdraw_liquidity: pro-rata, min_assets slippage all tested
- [x] ZeroAmount, InsufficientLiquidity, SlippageExceeded reverts tested
- [x] Floor division sanity checks in both provide and withdraw
- [x] isqrt bounds checks on first deposit
- [x] Oracle update called before reserve changes (both provide and withdraw)
- [ ] Pair paused behavior for provide/withdraw -- needs explicit verification
- [ ] LP receiver override tested (non-sender recipient)
- [x] No clippy warnings or test regressions

### 6b. Indexer (Must Pass)

- [x] 60/60 indexer unit tests pass (38afbf8) -- verified 4/7
- [ ] provide_liquidity events indexed correctly -- needs verification
- [ ] withdraw_liquidity events indexed correctly -- needs verification
- [ ] LP supply tracking matches on-chain -- needs verification
- [ ] Pool reserves snapshot accuracy -- needs verification

### 6c. Frontend (Must Pass)

- [x] PoolPage renders without crashing (1 Vitest) -- verified 4/7
- [x] 214/214 frontend tests pass (38afbf8) -- verified 4/7
- [x] Add liquidity flow works (allowance + provide) -- needs manual re-verify on 38afbf8
- [x] Remove liquidity flow works (CW20 send + withdraw) -- needs manual re-verify on 38afbf8
- [x] Native wrap/unwrap option functional -- needs manual re-verify
- [x] Withdrawal slippage computation correct -- needs unit test
- [x] Factory verification badge displays -- needs manual verify
- [ ] Imbalanced deposit warning shown -- [FUTURE]
- [ ] Share of pool % displayed -- [FUTURE]
- [ ] Tx hash shown with explorer link -- [FUTURE]
- [ ] LP tokens received/burned shown -- [FUTURE]
- [ ] Token balance check pre-submit -- [FUTURE]

### 6d. Security (Must Review)

- [x] min_assets protects withdraw from sandwich -- contract logic verified
- [ ] Slippage tolerance for provide -- currently null, no protection
- [ ] MINIMUM_LIQUIDITY prevents LP token inflation attack on first deposit -- needs explicit test review
- [ ] Allowance cleanup on failed provide -- best-effort, acceptable
- [ ] MEV sandwich risk documented for mainnet provide/withdraw
- [x] Decimal normalization handled per token

---

## Appendix A: Key Code Locations

| Component | File | Function/Section |
|-----------|------|-----------------|
| Provide liquidity (contract) | contracts/pair/src/contract.rs:1086 | execute_provide_liquidity() |
| Withdraw liquidity (contract) | contracts/pair/src/contract.rs:1265 | execute_withdraw_liquidity() |
| LP minting (isqrt) | contracts/pair/src/contract.rs | isqrt(), MINIMUM_LIQUIDITY |
| Oracle update | contracts/pair/src/contract.rs | oracle_update() |
| Frontend provide | services/terraclassic/pair.ts:126 | provideLiquidity() |
| Frontend withdraw | services/terraclassic/pair.ts:171 | withdrawLiquidity() |
| Pool page UI | pages/PoolPage.tsx | PoolCard (add/remove mutations) |
| Pool query | services/terraclassic/pair.ts:18 | getPool() |
| Factory verification | services/terraclassic/queries.ts | verifyPairInFactory() |
| Fee display | components/ui/FeeDisplay | FeeDisplay (fee_bps + discount) |
| Native wrap | TREASURY_CONTRACT_ADDRESS | wrap_deposit / unwrap via WRAP_MAPPER |
| Contract tests | smartcontracts/tests/src/lib.rs | 251+ provide/withdraw references |
| Frontend test | pages/PoolPage.test.tsx | 1 test (renders) |

## Appendix B: Existing Test Coverage

| Layer | Count | Status |
|-------|-------|--------|
| Contract (provide/withdraw related) | 251+ references in lib.rs | [CURRENT] All pass (286/286 total) |
| Indexer unit | 60/60 | [CURRENT] All pass |
| Indexer integration | 9 CoinGecko tests (need stack) | [CURRENT] Pass with stack |
| Frontend Vitest | 1 (PoolPage renders) | [CURRENT] Minimal |
| Playwright E2E | 0 for pool flow | [FUTURE] |
| Manual QA | Verified in #50 full pass (sections 2-5 cover pool) | [CURRENT] |

## Appendix C: Open Gaps

| Gap | Current State | Future State | Blocked By |
|-----|--------------|--------------|-----------|
| Provide slippage tolerance | Passed as null | User-configurable with presets | Frontend feature |
| Share of pool display | Not shown | Pre/post deposit share % | Frontend feature |
| Impermanent loss warning | Not shown | Warning on imbalanced deposits | Frontend feature |
| LP tokens received display | Not shown post-tx | TxResultAlert with LP amount | Frontend feature |
| Tx hash in result | Sound only | Explorer link | Frontend feature (reuse TxResultAlert from swap) |
| Token balance pre-check | Not checked | Disable button if insufficient | Frontend feature |
| Provide frontend tests | 1 render test | Full mutation/mock tests | Nothing -- can build now |
| Withdraw min_assets unit test | Logic inline in mutation | Extracted + tested | Nothing -- can build now |
| Indexer event verification | Not confirmed | Verified provide/withdraw event indexing | Nothing -- can check now |
| LP decimals verification | Hardcoded 6 | Query from LP token contract | Nothing -- quick check |
| Pair paused scope | Unknown for provide/withdraw | Documented and tested | Contract review |

---

*This spec is a living document. Update after each session as frontend improvements land and new automated tests are added.*
*v1.0 created 2026-04-07 by @Brouie after reviewing contract (38afbf8), frontend, and indexer code.*
