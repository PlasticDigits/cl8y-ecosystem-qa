# YieldOmega — TimeCurve Production Release Checklist

> Author: @Brouie (AVE)
> Version: 1.0 — 2026-04-10
> Source: launchplan-timecurve.md, contracts/PARAMETERS.md, specs/YO-TimeCurve-Verification-Spec.md v2.0, docs/testing/strategy.md
> Status: DRAFT — needs dev review

---

## 0. Pre-Release Discrepancies (MUST RESOLVE)

- [ ] **Podium categories mismatch:** PARAMETERS.md says 3 categories (last buy 50%, time booster 25%, defended streak 25%). Spec v2.0 and dev corrections (ecosystem-qa #4) say 4 categories (last buy 30%, WarBow 30%, time booster 20%, defended streak 20%). Which is canonical?
- [ ] **EndSale distribution:** Spec v2.0 says 35% burned, 20% prizes, 35% DOUB liquidity, 10% Rabbit Treasury. Launch plan fee routing says 25/35/20/0/20. Confirm which applies to endSale vs buy-time fee routing (these may be separate mechanisms).
- [ ] **FeeRouter weights:** Launch plan Section 5 says 25/35/20/0/20 (DoubLP/CL8YBurn/Podium/Team/Rabbit). PARAMETERS.md matches. Confirm these are final for production.

---

## 1. Contract Deployment

### 1a. Addresses (all TODO in PARAMETERS.md)

- [ ] Accepted asset (CL8Y) address finalized
- [ ] Launched token (DOUB) address finalized
- [ ] totalTokensForSale value set (450M per launch plan Section 4, or updated)
- [ ] DOUB pre-positioned in TimeCurve contract before startSale
- [ ] ReferralRegistry address (or 0 to disable)
- [ ] FeeRouter deployed with 5 sinks wired
- [ ] PodiumPool deployed
- [ ] RabbitTreasury deployed with correct parameters
- [ ] LinearCharmPrice deployed

### 1b. Governance (all TODO in PARAMETERS.md)

- [ ] DEFAULT_ADMIN_ROLE transferred to multisig (not deployer EOA)
- [ ] PARAMS role transferred to timelock
- [ ] PAUSER role assigned to narrow multisig
- [ ] NFT MINTER_ROLE assigned to authorized contract
- [ ] FEE_ROUTER role wired to FeeRouter contract

### 1c. Parameter Verification

- [ ] Initial minimum buy: 1 CL8Y (1e18)
- [ ] Daily growth fraction: 20% (growthRateWad = 182321556793954592)
- [ ] Purchase cap multiple: 10x min
- [ ] Timer extension: 120s per buy
- [ ] Initial countdown: 86400s (24h)
- [ ] Timer cap: 345600s (96h)
- [ ] Sale start timestamp set (auto-start, no manual call)
- [ ] WarBow parameters match PARAMETERS.md fixed values
- [ ] Fee split sums to 10000 bps
- [ ] Referral CHARM: 10% referrer + 10% referee

---

## 2. Testing Gates

### 2a. Stage 1 — Unit Tests

- [ ] forge test all green (currently 152/152)
- [ ] TimeCurve invariant/fuzz suites green
- [ ] RabbitTreasury invariant suite green
- [ ] Simulation unit tests green
- [ ] Indexer cargo test --lib green
- [ ] Frontend npx vitest run green
- [ ] cargo clippy --all-targets -- -D warnings clean

### 2b. Stage 2 — Integration

- [ ] Anvil E2E: buy, deposit, NFT read path
- [ ] Indexer: fresh DB, migrations, smoke events visible
- [ ] Indexer lag under threshold
- [ ] History consistency: indexer matches chain state
- [ ] Reorg handling exercised (rollback_after test)
- [ ] Bot scripts: seed-local passes (3 wallets, 5 buys, flag claim)
- [ ] Bot scripts: inspect reads full contract state correctly

### 2c. Stage 3 — Testnet

- [ ] Deploy to public testnet and verify contracts on explorer
- [ ] Soak: indexer + frontend stable for defined period
- [ ] Address registry published (canonical addresses + ABI hashes)
- [ ] Multi-player WarBow scenario tested (steal, revenge, guard, flag)
- [ ] Full sale lifecycle tested (start, buys, endSale, redeemCharms, distributePrizes)
- [ ] Simulation sweep run on release candidate (no regressions)

### 2d. QA Verification (from spec v2.0 open gaps)

- [ ] Self-referral prevention verified
- [ ] FeeRouter access control verified
- [ ] MEV resistance for last-buy podium documented/mitigated
- [ ] UTC day steal rollover edge case tested
- [ ] Flag 300s silence boundary tested
- [ ] Hard reset zone (remaining < 13min) behavior verified

---

## 3. Frontend

- [ ] VITE_* env vars set for production chain ID, RPC, contract addresses, indexer URL
- [ ] TimeCurve page: wallet connect, read sale state, buy, charm redemption all working
- [ ] Timer hero countdown renders correctly with urgency states
- [ ] Podium displays correct number of categories (resolve Section 0 discrepancy)
- [ ] WarBow stats display accurate
- [ ] Fee sink display matches FeeRouter config
- [ ] Non-TimeCurve routes show under construction
- [ ] Kumbaya/Sir show third-party DEX placeholder with links
- [ ] Mobile viewport audit (#27)

---

## 4. Indexer

- [ ] Fresh production Postgres with migrations applied
- [ ] FACTORY_ADDRESS, LCD URLs, CORS_ORIGINS configured
- [ ] Event decoding: buy, warbow, SaleWillStart, SaleEnded, CharmsRedeemed, PrizesDistributed
- [ ] API endpoints functional (10+ TimeCurve endpoints)
- [ ] Monitoring/alerting in place

---

## 5. Operations

- [ ] Deployment script or documented manual steps
- [ ] Rollback plan documented (contract migration path)
- [ ] Pause/resume runbook (who can pause, when, how)
- [ ] Incident response contacts
- [ ] Post-launch monitoring plan (timer, total raised, indexer lag, fee routing)

---

## 6. Go-Live Sequence

1. [ ] Deploy all contracts (TimeCurve, FeeRouter, sinks, RabbitTreasury, LinearCharmPrice)
2. [ ] Wire governance roles to multisig/timelock
3. [ ] Pre-position DOUB in TimeCurve (totalTokensForSale)
4. [ ] Set sale start timestamp
5. [ ] Deploy indexer with fresh DB
6. [ ] Deploy frontend with production env
7. [ ] Smoke test: connect wallet, verify sale state readable
8. [ ] Monitor first buy after sale auto-starts
9. [ ] Verify fee routing on first buy (check all 5 sinks received correct split)
10. [ ] Verify indexer picked up events

---

*Created 2026-04-10 by @Brouie. Based on launchplan-timecurve.md, PARAMETERS.md, spec v2.0, and testing/strategy.md.*