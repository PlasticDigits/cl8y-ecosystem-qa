# YieldOmega — TimeCurve Verification Spec
> Flow: TimeCurve Sale Lifecycle (Buy, Timer, Charms, Podium, WarBow PvP, Redemption)
> Author: @Brouie (AVE)
> Version: 2.1 — 2026-04-22 (live reactivity section 5d added + dev review fixes)
> Repo: yieldomega
> Reference: docs/product/primitives.md, skills/play-timecurve-doubloon, skills/play-timecurve-warbow
> Status legend: [CURRENT] = implemented and verified, [FUTURE] = not yet implemented

---

## 1. User-Visible Steps

### 1a. Sale Lifecycle

**Step 1: Sale starts**
- [CURRENT] Sale auto-starts at admin-set timestamp (no manual startSale call required)
- [CURRENT] SaleWillStart event emitted (startTimestamp, initialDeadline, totalTokensForSale)

**Step 2: Buy charms**
- [CURRENT] User specifies charmWad (1-10 CHARM in UI; 0.99 floor exists as revert protection buffer if min increases between selection and signing). Envelope scales ~20%/day
- [CURRENT] Per-CHARM price from linear schedule: basePrice + dailyIncrement x elapsed / 1 day
- [CURRENT] Gross spend: charmWad x priceWad / 1e18 routed through FeeRouter
- [CURRENT] CHARM weight accrues in WAD units (plus referral bonuses as CHARM)
- [CURRENT] Optional referral codeHash on buy
- [CURRENT] Timer extends by timerExtensionSec (canonical 120s) per buy, capped by timerCapSec (canonical 96h)
- [CURRENT] Hard reset: if remaining < 13min before buy, deadline resets to ~15min remaining
- [CURRENT] Buy event emits rich fields: timerHardReset, bpStreakBreakBonus, bpAmbushBonus, flagPlanted, actualSecondsAdded

**Step 3: WarBow PvP (during sale)**
- [CURRENT] Steal: burn 1 CL8Y, drain 10% victim BP (1% if guarded), requires victim >= 2x attacker BP
- [CURRENT] Per-victim UTC-day cap: 3 normal steals/day, 4th+ costs 50 CL8Y bypass burn
- [CURRENT] Revenge: burn 1 CL8Y, take 10% from any attacker (sortable list of attackers with wallet, time, amount -- not limited to last stealer)
- [CURRENT] Guard: burn 10 CL8Y, 6h guard reducing steal drain
- [CURRENT] Flag: after buy, 300s silence window, then claim 1000 BP. Penalty (2x) if another buys after silence STARTS (not elapsed). Silence only ends when creator claims the flag

**Step 4: Sale ends**
- [CURRENT] No further buys accepted once timer reaches zero. Any attempted buy triggers endSale automatically
- [CURRENT] endSale can only be triggered once. Once triggered OR timer at zero, no further buys accepted
- [CURRENT] SaleEnded event (endTimestamp, totalRaised, totalBuys)
- [CURRENT] WarBow steal/guard/flag blocked post-end

**Step 5: Redeem charms**
- [CURRENT] Each user calls redeemCharms() themselves after endSale has been called
- [CURRENT] On endSale, the rate of tokens per charm is fixed and stored
- [CURRENT] Transfers launched tokens pro-rata: totalTokensForSale * charmWeight / totalCharmWeight
- [CURRENT] CharmsRedeemed event emitted

**Step 6: Distribute prizes**
- [CURRENT] distributePrizes() pays reserve asset from PodiumPool to top-3 per category
- [CURRENT] Four categories: Last Buy (30%), WarBow (30%), Time Booster (20%), Defended Streak (20%)
- [CURRENT] Within each: 1st:2nd:3rd = 4:2:1 payout weights
- [CURRENT] PrizesDistributed event emitted

**EndSale asset distribution:**
- 35% burned
- 20% prizes (podium pool)
- 35% DOUB liquidity
- 10% Rabbit Treasury

### 1b. Frontend (TimeCurvePage)

**Pre-buy display:**
- [CURRENT] Timer hero countdown (HH:MM:SS) with urgency states (yellow <1h, red+pulse <5min) -- MR !1 merged
- [CURRENT] Current min/max buy amounts, charm bounds, price per charm
- [CURRENT] Total raised, sale start/end status
- [CURRENT] User's charm weight, buy count, charmsRedeemed, totalEffectiveTimerSecAdded
- [CURRENT] Podium leaderboard display (3 categories)
- [CURRENT] WarBow stats: battlePoints, activeDefendedStreak, bestDefendedStreak, guardUntil, pending revenge/flag
- [CURRENT] Fee sink display (FeeRouter: 25% locked LP, 35% CL8Y burn, 20% podium, 0% team, 20% RabbitTreasury)
- [FUTURE] Impermanent cost/reward estimator
- [FUTURE] WarBow needs own priority section for WarBow players
- [FUTURE] Tabs on TimeCurvePage for each of the 4 prize categories
- [FUTURE] WarBow action buttons (currently via contract calls)

**Post-sale display:**
- [CURRENT] Ended status, final stats
- [CURRENT] Redeem charms button
- [FUTURE] Prize distribution UI
- [FUTURE] Historical buy/action timeline

---

## 2. Expected State Changes

### 2a. Contract State (TimeCurve)

**Buy:**

| State | Before | After |
|-------|--------|-------|
| deadline | D | D + timerExtensionSec (or hard reset to ~15min if remaining < 13min) |
| totalRaised | T | T + grossAmount |
| charmWeight[buyer] | W | W + charmWad (+ referral bonus) |
| totalCharmWeight | TW | TW + charmWad (+ referral bonus) |
| buyCount[buyer] | N | N + 1 |
| totalEffectiveTimerSecAdded[buyer] | S | S + actualSecondsAdded |
| battlePoints[buyer] | BP | BP + base(250) + resetBonus(500) + clutch(150) + streakBreak + ambush(200) |
| Last buyer tracking | Previous | Updated (last 3 for podium) |
| Defended streak | Previous holder | Broken if new wallet buys under 15min window |
| Flag | Previous | New flag planted for buyer |
| Accepted asset balance | B | B - grossAmount (routed through FeeRouter) |

**Steal:**

| State | Before | After |
|-------|--------|-------|
| battlePoints[attacker] | A_BP | A_BP + floor(victim_BP * 1000/10000) |
| battlePoints[victim] | V_BP | V_BP - floor(V_BP * 1000/10000) (or 100/10000 if guarded) |
| stealsReceivedOnDay[victim][dayId] | N | N + 1 |
| warbowPendingRevengeStealer[victim] | Previous | attacker |
| warbowPendingRevengeExpiry[victim] | Previous | block.timestamp + 24h |
| CL8Y burned | 0 | 1e18 (or +50e18 for bypass) |

**Revenge:**

| State | Before | After |
|-------|--------|-------|
| battlePoints[victim] | V_BP | V_BP + floor(stealer_BP * 1000/10000) |
| battlePoints[stealer] | S_BP | S_BP - floor(S_BP * 1000/10000) |
| pendingRevengeStealer[victim] | stealer | cleared |
| CL8Y burned | 0 | 1e18 |

**Guard:**

| State | Before | After |
|-------|--------|-------|
| warbowGuardUntil[player] | G | max(G, block.timestamp + 6h) |
| CL8Y burned | 0 | 10e18 |

**Redeem Charms:**

| State | Before | After |
|-------|--------|-------|
| charmsRedeemed[buyer] | 0 | charmWeight[buyer] |
| Launched token balance[buyer] | B | B + totalTokensForSale * charmWeight / totalCharmWeight |
| prizesDistributed | false | (unchanged, separate call) |

### 2b. Indexer State

| Table/Endpoint | Change | Status |
|-------|--------|--------|
| /v1/timecurve/buys | New row per buy with all BP fields, timer data. Frontend user data ONLY -- never authoritative for prizes or allocations | [CURRENT] verified 4/4 |
| /v1/timecurve/warbow/battle-feed | Steal/revenge/guard/flag events | [CURRENT] verified 4/4 |
| /v1/timecurve/warbow/leaderboard | Top BP rankings | [CURRENT] verified 4/4 |
| /v1/timecurve/warbow/steals-by-victim-day | Per-victim daily steal counts | [CURRENT] verified 4/4 |
| /v1/timecurve/warbow/guard-latest | Guard status per player | [CURRENT] verified 4/4 |
| /v1/timecurve/buyer-stats | Per-buyer aggregates | [CURRENT] |
| /v1/timecurve/charm-redemptions | Redemption records | [CURRENT] |
| /v1/timecurve/prize-distributions | Prize payout records | [CURRENT] |
| /v1/timecurve/prize-payouts | Individual payout details | [CURRENT] |

### 2c. Frontend State

| Component | Change | Status |
|-----------|--------|--------|
| Timer countdown | Updates every second, urgency colors | [CURRENT] MR !1 merged |
| Charm weight display | Updated on buy | [CURRENT] |
| Podium leaderboard | Updated from contract reads | [CURRENT] |
| WarBow stats | BP, streak, guard, revenge, flag | [CURRENT] |
| Buy count, total raised | Updated on buy | [CURRENT] |
| Fee sink display | From FeeRouter contract | [CURRENT] |

---

## 3. What Could Go Wrong

### 3a. Contract Level

| Failure Mode | Cause | Impact | Severity | Test Coverage |
|-------------|-------|--------|----------|---------------|
| Buy outside charm band | charmWad < min or > max | Tx reverts | Low | [CURRENT] 58/58 tests |
| Timer overflow | Extension beyond timerCapSec | Capped by contract | Low | [CURRENT] tested |
| Hard reset edge case | Remaining exactly at 13min boundary | Off-by-one | Medium | [CURRENT] tested |
| isqrt/mulDiv rounding | Extreme charm or price values | Dust loss | Low | [CURRENT] tested |
| Steal 2x rule bypass | Attacker BP changes mid-tx | Checked at call time | Medium | [CURRENT] tested |
| UTC day boundary steal cap | Steal at day rollover | dayId shifts, cap resets | Low | [CURRENT] tested |
| Flag penalty timing | Buy exactly at plantAt + 300s | Edge case for penalty vs no-penalty | Medium | [CURRENT] tested |
| Revenge after new steal | Second steal overwrites pending revenge target | Victim loses revenge on first stealer | Medium | [CURRENT] by design |
| Guard stacking | Multiple guard calls | max(existing, now+6h), no stacking | Low | [CURRENT] tested |
| Redeem before endSale | Premature redemption | Blocked by ended check | Low | [CURRENT] tested |
| distributePrizes before endSale | Premature distribution | Blocked by ended check | Low | [CURRENT] tested |
| Double redemption | redeemCharms called twice | Second call gets 0 (charmsRedeemed already set) | Low | [CURRENT] tested |
| FeeRouter misconfiguration | Wrong sink weights | Funds misallocated | High | [CURRENT] verified on deployment |
| Referral bonus abuse | Self-referral or circular | Contract rules apply (verify deployment) | Medium | Needs verification |
| Post-sale WarBow actions | steal/guard/flag after ended | Blocked by !ended gate | Low | [CURRENT] tested |
| MEV front-running buys | Sandwich on timer extension | Attacker gets last-buy podium slot | High | [FUTURE] mainnet concern |

### 3b. Indexer Level

| Failure Mode | Cause | Impact | Status |
|-------------|-------|--------|--------|
| Missing BP breakdown fields | Indexer doesnt decode all Buy event fields | Incomplete battle feed | [CURRENT] verified 4/4 |
| Stale leaderboard | Indexer lag | UX shows old rankings | [CURRENT] acceptable with refetch |
| UTC day mismatch | Indexer uses different timezone | Wrong steal counts shown | Needs verification |
| Ambush/streak-break misattribution | Indexer infers instead of reading event fields | Wrong BP display | [CURRENT] uses event fields |

### 3c. Frontend Level

| Failure Mode | Cause | Impact | Status |
|-------------|-------|--------|--------|
| Timer drift | Client clock vs block.timestamp | Countdown inaccurate by seconds | Low -- acceptable |
| Urgency colors wrong | Threshold check off | Visual only | [CURRENT] tested in MR !1 |
| Podium shows wrong winners | Frontend reads stale data | Misleading leaderboard | [CURRENT] uses contract reads |
| WarBow actions not on page | No steal/guard/revenge UI buttons | Users need direct contract calls | [FUTURE] |
| Fee sink labels mismatch | FeeRouter changed but labels hardcoded | Confusing display | [CURRENT] flagged in #11 |
| Charm bounds display wrong | Frontend math diverges from contract | User tries invalid buy | [CURRENT] timeCurveMath.ts verified |
| RabbitTreasury test failures | Contract refactor rounding | Incorrect yield display | [CURRENT] fixed #15, 152/152 |

---

## 4. Frontend Must Show (User Safety)

### 4a. Pre-Buy

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| Timer countdown with urgency | Core game mechanic visibility | P0 | [CURRENT] MR !1 |
| Current charm price | Cost transparency | P0 | [CURRENT] |
| Min/max charm bounds | Prevent reverts | P0 | [CURRENT] |
| Total raised | Market context | P1 | [CURRENT] |
| Fee routing breakdown | Where money goes | P0 | [CURRENT] |
| Referral code input | Bonus opportunity | P1 | [CURRENT] |
| Hard reset zone indicator | Timing strategy awareness | P1 | [FUTURE] explicit visual |
| Estimated DOUB from charms | Expected outcome | P1 | [FUTURE] |

### 4b. WarBow Display

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| Battle points | PvP standing | P0 | [CURRENT] |
| Defended streak (active + best) | Podium tracking | P0 | [CURRENT] |
| Guard status/expiry | Defense awareness | P0 | [CURRENT] |
| Pending revenge target + expiry | Action window | P0 | [CURRENT] |
| Flag status | Claim opportunity | P0 | [CURRENT] |
| Steals received today | Daily cap awareness | P1 | [CURRENT] |
| WarBow action buttons | Direct PvP interaction | P0 | [FUTURE] |
| CL8Y burn cost display | Cost transparency for actions | P1 | [FUTURE] |

### 4c. Post-Sale

| Element | Why | Priority | Status |
|---------|-----|----------|--------|
| Redeem charms button | Token claim | P0 | [CURRENT] |
| Tokens to receive estimate | Expected outcome | P0 | [FUTURE] |
| Podium results | Prize visibility | P0 | [CURRENT] leaderboard |
| Prize distribution status | Payout tracking | P1 | [FUTURE] |
| WarBow final standings | PvP outcome | P1 | [CURRENT] leaderboard |

### 4d. Error States

| State | Display | Status |
|-------|---------|--------|
| Sale not started | Disabled buy, show start time | [CURRENT] |
| Sale ended | Disabled buy, show redeem | [CURRENT] |
| Charm outside bounds | Show valid range | [CURRENT] |
| Insufficient balance | Show warning | [CURRENT] |
| Steal 2x rule fail | Show requirement | [FUTURE] |
| Daily steal cap hit | Show remaining or bypass cost | [FUTURE] |
| Revenge expired | Show expiry | [FUTURE] |
| Guard already active | Show existing expiry | [FUTURE] |

---

## 5. Automation vs Manual QA

### 5a. Automate First (Highest ROI)

| What | How | Status |
|------|-----|--------|
| Buy within charm bounds | Contract unit test | [CURRENT] 58/58 TimeCurve tests |
| Buy outside bounds reverts | Contract unit test | [CURRENT] |
| Timer extension (normal + hard reset) | Contract unit test | [CURRENT] |
| Defended streak increment/break/clear | Contract unit test | [CURRENT] |
| WarBow steal (normal, guarded, bypass) | Contract unit test | [CURRENT] |
| WarBow revenge within/outside window | Contract unit test | [CURRENT] |
| WarBow guard activation/stacking | Contract unit test | [CURRENT] |
| Flag claim/penalty/invalidation | Contract unit test | [CURRENT] |
| Redeem charms pro-rata | Contract unit test | [CURRENT] |
| distributePrizes payout weights | Contract unit test | [CURRENT] |
| Sale lifecycle (start, buy, end, redeem, distribute) | Contract integration test | [CURRENT] |
| BP calculation (base + reset + clutch + streak-break + ambush) | Contract unit test | [CURRENT] |
| Podium top-3 tracking and tie-break | Contract unit test | [CURRENT] |
| Indexer buy event decoding | Indexer unit test | [CURRENT] decoder tests |
| Indexer WarBow event decoding | Indexer unit test | [CURRENT] decoder tests |
| Frontend timer formatting | Vitest | [CURRENT] MR !1 |

### 5b. Automate Next (Medium Effort)

| What | How | Blocked By |
|------|-----|-----------|
| Full sale E2E (start -> buys -> end -> redeem -> distribute) | Forge script or Playwright | Nothing -- can build now |
| WarBow multi-player scenario | Forge test with 3+ actors | Nothing -- can build now |
| UTC day boundary steal cap rollover | Forge test with warp | Nothing -- can build now |
| Flag timing edge cases (exactly at 300s) | Forge test with warp | Nothing -- can build now |
| Indexer API response accuracy vs contract reads | Integration test | Needs stack running |
| Frontend charm bounds vs contract bounds | Vitest unit test | Nothing -- can build now |
| Frontend timer urgency thresholds | Vitest unit test | Nothing -- can build now |
| Referral bonus accounting | Forge test | Needs referral contract review |

### 5c. Manual QA (Keep Manual)

| What | Why Manual |
|------|-----------|
| Timer UX feel (countdown, urgency colors, pulse) | Subjective experience |
| WarBow PvP game feel | Multi-player interaction quality |
| Podium leaderboard readability | Visual layout assessment |
| Fee sink label accuracy | Cross-reference with FeeRouter deployment |
| Mobile viewport TimeCurvePage | Device-specific layout |
| Dark mode theming | Color contrast in arcade theme |
| First-time user comprehension | Cognitive UX testing |
| MEV scenario testing (mainnet) | Requires real conditions |

### 5d. Live Reactivity Verification (Bot-Driven)

Run bot scripts (seed-local or custom strategies) while watching the frontend. Verify real-time updates:

| What to Watch | Expected Behavior | How to Verify |
|---------------|-------------------|---------------|
| Buy feed | New buys appear in feed within seconds of on-chain confirmation | Run seed-local, watch TimeCurvePage buy feed |
| Price ticker | Linear price = price per charm, min/max = amount of charm. Updates every 30ms by simulating between blocks. | Compare displayed price to contract state via inspect |
| Timer reset | If less than 13 min remaining, resets to 15 min. Otherwise +2 min up to 96 hour cap. | Buy near timer expiry, confirm reset in UI |
| WarBow points | Points update when flag is claimed or defended | Run multi-wallet scenario with flag claims |
| Podium / leaderboard | Rankings shift as new buys change standings | Watch podium cards during bot buys across wallets |
| Envelope progress | Envelope scales visually as time progresses (~20%/day) | Check envelope display matches contract envelope state |
| Charm accumulation | Charm count increments per buy | Buy multiple times from same wallet, verify charm count |
| Battle feed | Attack/defend events appear in WarBow section | Run flag claim + defend sequence via bots |
| Streak defense | Defended streak counter updates when holder defends flag against attackers | Run multi-wallet flag attack + defend sequence via bots |
| EndSale trigger | Sale ends when timer hits zero + buy attempted or just hits zero | Let timer expire during bot run |

**Method:** Start YO Anvil stack, deploy contracts, run seed-local bot, open TimeCurvePage in browser via SSH tunnel. All items above should feel lively and responsive -- no stale data, no manual refresh needed.

**Pass criteria:** All 10 items update within 5 seconds of on-chain event without page refresh.

---

## 6. Release Gate Checklist

### 6a. Contract (Must Pass)

- [x] 58/58 TimeCurve tests pass (5d01bb4) -- verified 4/7
- [x] 152/152 total contract tests pass -- verified 4/7
- [x] Buy within/outside charm bounds tested
- [x] Timer extension + hard reset tested
- [x] Defended streak lifecycle tested
- [x] WarBow steal/revenge/guard/flag tested
- [x] BP calculation all components tested
- [x] Podium tracking and tie-break tested
- [x] Redeem charms pro-rata tested
- [x] distributePrizes payout weights tested
- [x] LinearCharmPrice 3/3 tests passing -- verified 4/4
- [ ] Referral bonus edge cases -- needs explicit review
- [ ] Post-sale WarBow blocking -- needs explicit verification
- [ ] FeeRouter sink weights match documented defaults -- needs deployment verification

### 6b. Indexer (Must Pass)

- [x] Buy event decoding correct -- verified 4/4
- [x] WarBow event decoding correct -- verified 4/4
- [x] All API endpoints responding -- verified 4/4 (battle-feed, leaderboard, steals-by-victim-day, guard-latest, buyer-stats, charm-redemptions, prize-distributions, prize-payouts)
- [ ] UTC day boundary handling -- needs verification
- [ ] Ambush/streak-break attribution from event fields only -- needs verification
- [ ] 4 new DB migrations applied -- verified 4/4

### 6c. Frontend (Must Pass)

- [x] TimeCurvePage renders -- verified
- [x] Timer hero with urgency states -- MR !1 merged
- [x] timeCurveMath.ts rendering on page -- verified 4/4
- [x] Charm bounds display -- verified
- [x] Podium leaderboard display -- verified
- [x] WarBow stats display -- verified
- [x] Fee sink display -- verified (mismatch flagged #11)
- [ ] WarBow action buttons (steal/guard/revenge/flag) -- [FUTURE]
- [ ] Estimated DOUB from charms -- [FUTURE]
- [ ] Hard reset zone visual indicator -- [FUTURE]
- [ ] CL8Y burn cost display for WarBow actions -- [FUTURE]
- [ ] Post-sale redeem/distribute UI polish -- [FUTURE]

### 6d. Security (Must Review)

- [x] Steal 2x rule prevents griefing small players
- [x] UTC-day steal cap limits drain rate
- [x] Guard reduces steal impact
- [x] Revenge is single-pending (no infinite loops)
- [ ] Self-referral prevention -- needs verification
- [ ] MEV resistance for last-buy podium -- mainnet concern, documented
- [ ] FeeRouter access control -- needs verification
- [x] endSale gates further buys and WarBow actions

---

## Appendix A: Key Code Locations

| Component | File | Function/Section |
|-----------|------|-----------------|
| TimeCurve contract | contracts/src/TimeCurve.sol | Full sale + WarBow logic |
| Buy | TimeCurve.sol:254 | buy(charmWad) / buy(charmWad, codeHash) |
| Timer math | TimeCurve.sol (internal) | extendDeadlineOrResetBelowThreshold |
| WarBow steal | TimeCurve.sol:417 | warbowSteal(victim, payBypassBurn) |
| WarBow revenge | TimeCurve.sol:467 | warbowRevenge(stealer) |
| WarBow guard | TimeCurve.sol:491 | warbowActivateGuard() |
| Flag claim | TimeCurve.sol:403 | claimWarBowFlag() |
| Redeem charms | TimeCurve.sol:556 | redeemCharms() |
| Distribute prizes | TimeCurve.sol:570 | distributePrizes() |
| Podium tracking | TimeCurve.sol:669 | _updateTopThreeMonotonic() |
| LinearCharmPrice | contracts/src/LinearCharmPrice.sol | ICharmPrice implementation |
| Contract tests | contracts/test/TimeCurve.t.sol | 58 tests + invariant fuzz |
| Indexer decoder | indexer/src/decoder.rs | Event decoding (buy, warbow events) |
| Indexer API | indexer/src/api.rs | 10+ TimeCurve endpoints |
| Frontend page | frontend/src/pages/TimeCurvePage.tsx | 1903 lines, full UI |
| Frontend math | frontend/src/lib/timeCurveMath.ts | Charm/price calculations |
| Podium math | frontend/src/lib/timeCurvePodiumMath.ts | Podium display helpers |
| Product spec | docs/product/primitives.md | Authoritative requirements |
| Doubloon skill | skills/play-timecurve-doubloon/SKILL.md | Participant guide |
| WarBow skill | skills/play-timecurve-warbow/SKILL.md | PvP participant guide |

## Appendix B: Existing Test Coverage

| Layer | Count | Status |
|-------|-------|--------|
| TimeCurve contract | 58/58 | [CURRENT] All pass |
| LinearCharmPrice | 3/3 | [CURRENT] All pass |
| RabbitTreasury | 28/28 (was 23/28) | [CURRENT] Fixed #15 |
| Total contract | 152/152 | [CURRENT] All pass |
| Indexer decoder | warbow_cl8y_burned + warbow_steal roundtrips | [CURRENT] |
| Indexer integration | 1/1 new migration test | [CURRENT] |
| Frontend timer | formatCountdown + timerUrgencyClass | [CURRENT] MR !1 |
| Playwright E2E | 0 for TimeCurve | [FUTURE] |

## Appendix C: Open Gaps

| Gap | Current State | Future State | Blocked By |
|-----|--------------|--------------|-----------|
| WarBow UI actions | No buttons on page | Steal/guard/revenge/flag buttons | Frontend feature |
| Hard reset zone indicator | No visual cue | Color/icon when remaining < 13min | Frontend feature |
| DOUB estimation | Not shown pre-buy | Show expected tokens from charms | Frontend feature |
| CL8Y burn costs | Not shown | Display burn cost per WarBow action | Frontend feature |
| Full sale E2E test | Manual only | Automated forge script | Nothing -- can build now |
| Multi-player WarBow test | Manual only | 3+ actor forge scenario | Nothing -- can build now |
| UTC day steal rollover test | Not explicitly tested | Forge test with warp | Nothing -- can build now |
| Flag 300s edge case test | May exist in 58 tests | Explicit boundary test | Nothing -- verify coverage |
| Referral bonus accounting | Not explicitly verified | Dedicated test | Needs referral contract review |
| Fee sink label sync | Mismatch flagged #11 | Auto-read from FeeRouter | Frontend feature |
| Post-sale UI polish | Basic redeem exists | Full prize/redemption dashboard | Frontend feature |

---

*This spec is a living document. Update after each session as WarBow UI and post-sale features land.*
*v1.0 created 2026-04-07 by @Brouie after reviewing contract (5d01bb4), indexer, frontend, and product docs.*
*v2.0 updated 2026-04-09 by @Brouie per dev review (ecosystem-qa #4): 4 prize categories (not 3), WarBow is prize category, 30/30/20/20 split, endSale distribution 35/20/35/10, auto-start sale, revenge sortable list, flag penalty on silence start, charm 1-10 UI, envelope 20%/day.*
