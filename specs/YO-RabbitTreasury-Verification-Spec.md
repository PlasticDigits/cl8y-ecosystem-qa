# YieldOmega — Rabbit Treasury Verification Spec
> Flow: Deposit, Epoch Finalization, Withdraw, Fee Routing, Reserve Health (Burrow)
> Author: @Brouie (AVE)
> Version: 1.0 — 2026-04-07
> Repo: yieldomega
> Reference: docs/product/rabbit-treasury.md, skills/play-rabbit-treasury/SKILL.md
> Status legend: [CURRENT] = implemented and verified, [FUTURE] = not yet implemented

---

## 1. User-Visible Steps

### 1a. Deposit

**Step 1: Connect wallet and check epoch**
- [CURRENT] User connects wallet, checks epoch is open (openFirstEpoch called by admin)
- [CURRENT] Contract is not paused

**Step 2: Deposit reserve asset (CL8Y)**
- [CURRENT] User specifies deposit amount
- [CURRENT] Contract pulls CL8Y, mints DOUB: doubOut = amount * WAD / eWad
- [CURRENT] redeemableBacking += amount
- [CURRENT] BurrowDeposited event emitted (user, reserveAsset, amount, doubOut, epochId, factionId)
- [CURRENT] BurrowReserveBuckets event emitted with updated balances
- [FUTURE] Frontend deposit form (currently under construction)

### 1b. Epoch Finalization

**Step 1: Epoch window elapses**
- [CURRENT] Epoch has defined startTimestamp and endTimestamp
- [CURRENT] finalizeEpoch() callable after epoch window

**Step 2: Repricing and health snapshot**
- [CURRENT] BurrowMath computes reserve health, repricing factor using total backing
- [CURRENT] BurrowHealthEpochFinalized event with reserveRatioWad, doubTotalSupply, repricingFactorWad, backingPerDoubloonWad, internalStateEWad
- [CURRENT] BurrowEpochReserveSnapshot emitted per asset
- [CURRENT] New epoch opens (BurrowEpochOpened)
- [CURRENT] eWad updated based on repricing formula (cStar, alpha, beta, mBounds, lambda, deltaMaxFrac)

### 1c. Withdraw

**Step 1: Check eligibility**
- [CURRENT] Epoch is open, contract not paused
- [CURRENT] Redemption cooldown satisfied (minimum epochs since last withdrawal)
- [CURRENT] User has DOUB balance

**Step 2: Preview withdrawal**
- [CURRENT] previewWithdraw(doubAmount) returns (userOut, feeToProtocol)
- [CURRENT] previewWithdrawFor(address, doubAmount) for indexers/tests
- [CURRENT] Formula: nominalOut -> proRataCap -> baseOut -> efficiency scaling -> fee deduction

**Step 3: Execute withdrawal**
- [CURRENT] User specifies doubAmount and factionId
- [CURRENT] DOUB burned, CL8Y transferred to user (after efficiency scaling and fee)
- [CURRENT] Withdrawal fee credited to protocolOwnedBacking
- [CURRENT] BurrowWithdrawn event emitted
- [CURRENT] BurrowWithdrawalFeeAccrued event emitted
- [CURRENT] BurrowReserveBuckets event updated
- [FUTURE] Frontend withdraw form (under construction)

### 1d. Fee Revenue (receiveFee)

- [CURRENT] FeeRouter calls receiveFee(amount) with FEE_ROUTER_ROLE
- [CURRENT] Configurable split: protocolRevenueBurnShareWad burned to dead address, remainder to protocolOwnedBacking
- [CURRENT] Does NOT mint DOUB or increase redeemableBacking
- [CURRENT] BurrowProtocolRevenueSplit event emitted
- [CURRENT] BurrowFeeAccrued event emitted

---

## 2. Expected State Changes

### 2a. Contract State

**Deposit:**

| State | Before | After |
|-------|--------|-------|
| redeemableBacking | R | R + amount |
| DOUB balance[user] | D | D + amount * WAD / eWad |
| DOUB totalSupply | S | S + amount * WAD / eWad |
| Reserve asset in vault | V | V + amount |

**Epoch Finalization:**

| State | Before | After |
|-------|--------|-------|
| currentEpochId | N | N + 1 |
| eWad | E_old | E_new (repriced based on BurrowMath) |
| Epoch boundaries | Previous window | New startTimestamp/endTimestamp |

**Withdraw:**

| State | Before | After |
|-------|--------|-------|
| DOUB balance[user] | D | D - doubAmount |
| DOUB totalSupply | S | S - doubAmount |
| redeemableBacking | R | R - grossFromRedeemable |
| protocolOwnedBacking | P | P + withdrawalFee |
| Reserve asset to user | 0 | grossFromRedeemable - fee |
| lastWithdrawEpoch[user] | Old | currentEpochId |

**receiveFee:**

| State | Before | After |
|-------|--------|-------|
| protocolOwnedBacking | P | P + (amount - burnAmount) |
| cumulativeBurned | B | B + burnAmount |
| Reserve asset burned | 0 | amount * protocolRevenueBurnShareWad / WAD |

### 2b. Indexer State

| Event | Data | Status |
|-------|------|--------|
| BurrowDeposited | user, amount, doubOut, epochId, factionId | [CURRENT] |
| BurrowWithdrawn | user, amount, doubIn, epochId, factionId | [CURRENT] |
| BurrowHealthEpochFinalized | reserveRatioWad, doubTotalSupply, repricing, eWad | [CURRENT] |
| BurrowEpochReserveSnapshot | epochId, reserveAsset, balance | [CURRENT] |
| BurrowReserveBuckets | redeemable, protocolOwned, total | [CURRENT] |
| BurrowProtocolRevenueSplit | grossAmount, toProtocol, burned | [CURRENT] |
| BurrowWithdrawalFeeAccrued | feeAmount, cumulative | [CURRENT] |
| BurrowRepricingApplied | factor, priorPrice, newPrice | [CURRENT] |
| BurrowFeeAccrued | asset, amount, cumulative, epochId | [CURRENT] |

### 2c. Frontend State

| Component | Status |
|-----------|--------|
| RabbitTreasuryPage | [FUTURE] Under construction placeholder |
| Deposit form | [FUTURE] |
| Withdraw form with preview | [FUTURE] |
| Reserve health dashboard | [FUTURE] |
| Epoch timeline/history | [FUTURE] |
| Fee routing display | [FUTURE] |

---

## 3. What Could Go Wrong

### 3a. Contract Level

| Failure Mode | Cause | Impact | Severity | Test Coverage |
|-------------|-------|--------|----------|---------------|
| Deposit zero | amount = 0 | Tx reverts | Low | [CURRENT] test_deposit_zero_reverts |
| Deposit no epoch | No epoch opened | Tx reverts | Low | [CURRENT] test_deposit_no_epoch_reverts |
| Withdraw more than balance | doubAmount > user DOUB | Tx reverts | Low | [CURRENT] test_withdraw_more_than_balance_reverts |
| Redemption cooldown | Consecutive withdrawals too fast | Tx reverts | Medium | [CURRENT] test_redemptionCooldown_blocks_consecutive_withdraws |
| Finalize too early | Epoch not elapsed | Tx reverts | Low | [CURRENT] test_finalizeEpoch_too_early_reverts |
| Double open epoch | openFirstEpoch twice | Tx reverts | Low | [CURRENT] test_openFirstEpoch_reverts_twice |
| receiveFee unauthorized | Caller lacks FEE_ROUTER_ROLE | Tx reverts | Medium | [CURRENT] test_receiveFee_unauthorized_reverts |
| receiveFee zero | amount = 0 | Tx reverts | Low | [CURRENT] test_receiveFee_zero_reverts |
| Params unauthorized | Caller lacks PARAMS_ROLE | Tx reverts | Medium | [CURRENT] test_params_update_unauthorized_reverts |
| Invalid mBounds | mMin > mMax | Tx reverts | Low | [CURRENT] test_setMBounds_invalid_reverts |
| Protocol bucket extraction | Ordinary withdraw drains protocol bucket | Should not happen | High | [CURRENT] test_protocolOwned_notExtracted_viaOrdinaryWithdraw |
| Repricing raises liability | eWad change affects redemption | Efficiency scaling adjusts | Medium | [CURRENT] test_repricingRaisesLiability_redemptionBelowNominal |
| Mass exit stress | Many users withdraw same epoch | Protocol bucket untouched | High | [CURRENT] test_stress_manyUsersExit_protocolBucketUntouched |
| Reserve balance mismatch | Accounting diverges from actual token balance | Funds stuck or overdrawn | Critical | [CURRENT] invariant_rabbitTreasury_reservesMatchTokenBalance (256 runs) |
| receiveFee mints DOUB | Fee inflow incorrectly mints | DOUB inflation | Critical | [CURRENT] test_receiveFee_doesNotMintDoub |
| Burn share zero | All fee to protocol, none burned | Valid config path | Low | [CURRENT] test_burn_share_zero_sends_all_to_protocol_bucket |
| previewWithdraw accuracy | Preview diverges from actual | User gets different amount | Medium | [CURRENT] test_previewWithdrawFor_agrees_with_withdraw_fuzz |
| Rounding in withdraw formula | Multiple division steps | Dust loss (wei-level) | Low | [CURRENT] fuzz tests cover |
| Paused contract | Admin pauses | Deposits/withdrawals blocked | Medium | [CURRENT] test_pause_blocks_deposit, test_unpause_allows_deposit |

### 3b. Indexer Level

| Failure Mode | Cause | Impact | Status |
|-------------|-------|--------|--------|
| Missing Burrow events | Indexer doesnt decode new events | Dashboard incomplete | Needs verification |
| Reserve bucket mismatch | Indexer computes vs event values | Wrong health display | Should use event values only |
| Epoch boundary confusion | Indexer timezone vs block.timestamp | Wrong epoch attribution | Needs verification |

### 3c. Frontend Level

| Failure Mode | Cause | Impact | Status |
|-------------|-------|--------|--------|
| No UI exists | Under construction | Users cant interact via frontend | [FUTURE] blocked on TimeCurve devnet |
| previewWithdraw not shown | No withdraw form | Users cant estimate output | [FUTURE] |
| Reserve health not charted | No dashboard | Users cant assess health | [FUTURE] |

---

## 4. Frontend Must Show (User Safety)

### 4a. Pre-Deposit

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| Current epoch state | Deposit requires open epoch | P0 | [FUTURE] |
| eWad (internal price) | Affects DOUB received | P0 | [FUTURE] |
| Reserve health ratio | Risk transparency | P0 | [FUTURE] |
| Fee routing split | Where inflows go | P1 | [FUTURE] |
| "Not a bank deposit" disclaimer | Honest sustainability | P0 | [FUTURE] |

### 4b. Pre-Withdraw

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| previewWithdraw output | Expected CL8Y return | P0 | [FUTURE] |
| Redemption efficiency | Health-dependent scaling | P0 | [FUTURE] |
| Withdrawal fee | Cost transparency | P0 | [FUTURE] |
| Cooldown status | Eligibility check | P0 | [FUTURE] |
| Redeemable vs protocol backing | What is actually available | P1 | [FUTURE] |

### 4c. Dashboard

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| Reserve ratio chart (epoch history) | Health trend | P0 | [FUTURE] |
| DOUB supply chart | Inflation/deflation tracking | P1 | [FUTURE] |
| Backing per DOUB chart | Value tracking | P0 | [FUTURE] |
| Epoch timeline | Finalization history | P1 | [FUTURE] |
| Protocol vs redeemable buckets | Transparency | P1 | [FUTURE] |
| Cumulative burned | Burn sink tracking | P2 | [FUTURE] |

### 4d. Error States

| State | Display | Status |
|-------|---------|--------|
| No epoch open | Disable deposit/withdraw | [FUTURE] |
| Contract paused | Show pause notice | [FUTURE] |
| Cooldown active | Show remaining epochs | [FUTURE] |
| Insufficient DOUB | Disable withdraw | [FUTURE] |
| Zero deposit | Disable button | [FUTURE] |

---

## 5. Automation vs Manual QA

### 5a. Automate First (Highest ROI)

| What | How | Status |
|------|-----|--------|
| Deposit basic | Contract unit test | [CURRENT] test_deposit_basic |
| Withdraw basic | Contract unit test | [CURRENT] test_withdraw_basic |
| Deposit/withdraw fuzz | Contract fuzz test | [CURRENT] test_deposit_withdraw_fuzz |
| previewWithdraw accuracy fuzz | Contract fuzz test | [CURRENT] test_previewWithdrawFor_agrees_with_withdraw_fuzz |
| Epoch finalization repricing | Contract unit test | [CURRENT] test_finalizeEpoch_repricing |
| Epoch health metrics match formula | Contract unit test | [CURRENT] test_finalizeEpoch_emittedHealthMetrics_matchBurrowFormula |
| Reserve invariant (balance = accounting) | Contract invariant test | [CURRENT] invariant_rabbitTreasury_reservesMatchTokenBalance (256 runs, 6400 calls) |
| receiveFee doesnt mint DOUB | Contract unit test | [CURRENT] |
| Protocol bucket isolation | Contract unit test | [CURRENT] test_protocolOwned_notExtracted |
| Mass exit stress | Contract unit test | [CURRENT] test_stress_manyUsersExit |
| Pause/unpause | Contract unit test | [CURRENT] |
| All access control reverts | Contract unit tests | [CURRENT] |
| Cooldown enforcement | Contract unit test | [CURRENT] |
| Parameter bounds | Contract unit test | [CURRENT] test_setMBounds_invalid_reverts |

### 5b. Automate Next (Medium Effort)

| What | How | Blocked By |
|------|-----|-----------|
| Multi-epoch lifecycle E2E | Forge script (deposit -> finalize -> deposit -> withdraw -> finalize) | Nothing -- can build now |
| Fee inflow -> repricing -> withdraw chain | Forge test | Nothing -- can build now |
| Extreme repricing scenarios | Forge fuzz with adversarial parameters | Nothing -- can build now |
| Indexer Burrow event decoding | Indexer integration test | Needs indexer Burrow support verification |
| Frontend deposit/withdraw form | Vitest + Playwright | Frontend feature needed |
| previewWithdraw display accuracy | Vitest (mock contract, verify UI matches) | Frontend feature needed |
| Reserve health chart accuracy | Indexer integration vs contract reads | Needs stack running |

### 5c. Manual QA (Keep Manual)

| What | Why Manual |
|------|-----------|
| Reserve health dashboard UX | Subjective data visualization quality |
| "Not a bank" messaging review | Regulatory/communications judgment |
| Multi-user scenario game feel | Social dynamics |
| Epoch timing edge cases (real blocks) | Hard to simulate precisely |
| Fee routing end-to-end (TimeCurve -> FeeRouter -> RabbitTreasury) | Cross-contract integration |

---

## 6. Release Gate Checklist

### 6a. Contract (Must Pass)

- [x] 28/28 RabbitTreasury tests pass (5d01bb4) -- verified 4/7
- [x] 152/152 total contract tests pass -- verified 4/7
- [x] Invariant fuzz: reserves match token balance (256 runs, 6400 calls)
- [x] previewWithdraw agrees with actual withdraw (fuzz)
- [x] Deposit/withdraw fuzz passing
- [x] Protocol bucket isolation verified
- [x] Mass exit stress test passing
- [x] receiveFee does not mint DOUB
- [x] Pause/unpause tested
- [x] Access control (FEE_ROUTER_ROLE, PARAMS_ROLE, PAUSER_ROLE, DEFAULT_ADMIN_ROLE)
- [x] Cooldown enforcement tested
- [x] Repricing health metrics match BurrowMath formula
- [ ] Multi-epoch lifecycle E2E (deposit -> finalize -> withdraw across epochs) -- can build
- [ ] Fee inflow -> repricing chain -- can build
- [ ] Extreme parameter edge cases (cStar, alpha, beta near bounds) -- can build

### 6b. Indexer (Must Pass)

- [ ] Burrow event decoding implemented -- needs verification
- [ ] All canonical events indexed (12 event types per rabbit-treasury.md) -- needs verification
- [ ] Reserve health chart data accurate -- needs verification
- [ ] Epoch boundary handling correct -- needs verification

### 6c. Frontend (Must Pass -- all FUTURE)

- [ ] Deposit form with DOUB preview
- [ ] Withdraw form with previewWithdraw
- [ ] Reserve health dashboard (ratio, backing per DOUB, supply)
- [ ] Epoch timeline
- [ ] Protocol vs redeemable bucket display
- [ ] Cooldown status indicator
- [ ] Pause notice
- [ ] "Not a bank deposit" disclaimer

### 6d. Security (Must Review)

- [x] Reserve invariant holds under fuzz
- [x] Protocol bucket not drainable via ordinary withdraw
- [x] receiveFee cannot inflate DOUB supply
- [x] Access control on all admin/params/fee functions
- [ ] Reentrancy review on deposit/withdraw paths -- verify nonReentrant or checks-effects-interactions
- [ ] FeeRouter integration access control -- verify only authorized callers
- [ ] Parameter manipulation risk (governance sets params that drain reserves) -- document governance trust model
- [ ] Flash loan attack on deposit -> finalize -> withdraw in same block -- needs analysis

---

## Appendix A: Key Code Locations

| Component | File | Function/Section |
|-----------|------|-----------------|
| RabbitTreasury contract | contracts/src/RabbitTreasury.sol | Full treasury logic |
| Deposit | RabbitTreasury.sol:332 | deposit(amount, factionId) |
| Withdraw | RabbitTreasury.sol:350 | withdraw(doubAmount, factionId) |
| Withdraw preview | RabbitTreasury.sol:233 | previewWithdraw() / previewWithdrawFor() |
| Withdraw formula | RabbitTreasury.sol:246 | _previewWithdraw() |
| Epoch finalization | RabbitTreasury.sol:288 | finalizeEpoch() |
| Fee revenue | RabbitTreasury.sol:388 | receiveFee(amount) |
| Reserve views | RabbitTreasury.sol:206 | totalReserves(), totalBacking(), redemptionHealthWad() |
| Parameter setters | RabbitTreasury.sol:423+ | setCStarWad, setAlphaWad, etc. |
| Contract tests | contracts/test/RabbitTreasury.t.sol | 28 tests + 2 invariant fuzz |
| Product spec | docs/product/rabbit-treasury.md | Authoritative requirements |
| Participant skill | skills/play-rabbit-treasury/SKILL.md | User guide |
| Frontend (placeholder) | frontend/src/pages/RabbitTreasuryPage.tsx | 15 lines, under construction |

## Appendix B: Existing Test Coverage

| Layer | Count | Status |
|-------|-------|--------|
| RabbitTreasury unit tests | 28/28 | [CURRENT] All pass (was 23/28, #15 fixed) |
| Invariant fuzz | 2 tests (256 runs each, 6400 calls) | [CURRENT] All pass |
| Total contract | 152/152 | [CURRENT] All pass |
| Indexer Burrow events | Unknown | Needs verification |
| Frontend | 0 (placeholder page) | [FUTURE] |
| Playwright E2E | 0 | [FUTURE] |

## Appendix C: Open Gaps

| Gap | Current State | Future State | Blocked By |
|-----|--------------|--------------|-----------|
| Frontend UI | Under construction placeholder | Full deposit/withdraw/dashboard | TimeCurve devnet stabilization |
| Multi-epoch E2E test | Not explicitly tested as chain | Forge script covering full lifecycle | Nothing -- can build now |
| Fee -> repricing chain test | Separate unit tests | Integrated flow test | Nothing -- can build now |
| Indexer Burrow support | Unknown coverage | All 12 canonical events decoded | Needs investigation |
| Reserve health chart | No frontend | Epoch-by-epoch chart from events | Frontend + indexer |
| Flash loan analysis | Not documented | Security assessment documented | Needs review |
| Governance trust model | Not documented | Parameter risk documentation | Needs review |
| Reentrancy audit | Likely covered by OpenZeppelin | Explicit verification | Quick check |

---

*This spec is a living document. Update when Rabbit Treasury frontend lands and indexer Burrow support is verified.*
*v1.0 created 2026-04-07 by @Brouie after reviewing contract (5d01bb4), product docs, and skill guides.*
