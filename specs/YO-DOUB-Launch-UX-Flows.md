# YieldOmega — DOUB Launch UX Flows & Verification Checklists

**Scope:** Frontend UX verification for the TimeCurve / DOUB launch on MegaETH devnet → mainnet.
**Status:** DRAFT — pending review on cl8y-ecosystem-qa, to be handed to second QA dev once approved.
**References:** `launchplan-timecurve.md`, `docs/product/primitives.md`, `docs/onchain/fee-routing-and-governance.md`, `frontend/src/app/LaunchGate.tsx`, `frontend/src/pages/LaunchCountdownPage.tsx`, `frontend/src/pages/TimeCurvePage.tsx`.

---

## Flow index

1. **F-01** — Pre-launch gate (countdown active, all routes locked except home)
2. **F-02** — Launch moment (countdown hits zero, routes unlock without reload)
3. **F-03** — First-time visitor, sale live (cold wallet, no prior state)
4. **F-04** — Wallet connect during live sale (MetaMask / WalletConnect / RainbowKit)
5. **F-05** — Buy charms (CL8Y → TimeCurve)
6. **F-06** — Timer-extension buy (late-stage pressure UX)
7. **F-07** — WarBow PvP flow (steal / guard / revenge / flag)
8. **F-08** — Podium standings read (Last Buy / WarBow / Defended Streak / Time Booster)
9. **F-09** — Post-sale redeem charms → DOUB
10. **F-10** — Presale vesting UX (DoubPresaleVesting: 30% + 180-day linear)
11. **F-11** — Under-construction routes (Rabbit / Collection / Referrals)
12. **F-12** — Third-party DEX pages (Kumbaya / Sir) with / without env vars set
13. **F-13** — Mobile layout (390x844 viewport) — every flow
14. **F-14** — Error states (RPC down, indexer stale, wrong chain, wallet mismatch)
15. **F-15** — Accessibility / keyboard / screen-reader

---

## F-01 — Pre-launch gate

**Trigger:** `VITE_LAUNCH_TIMESTAMP` is set and in the future.

- [ ] Root `/` renders `LaunchCountdownPage`, not `HomePage`
- [ ] `/timecurve`, `/rabbit-treasury`, `/collection`, `/referrals`, `/kumbaya`, `/sir` all redirect to or render `LaunchCountdownPage` (no bypass by typing URL)
- [ ] Countdown shows days/hours/minutes/seconds, updating every second
- [ ] Countdown survives a full page refresh (no flicker back to pre-launch content)
- [ ] Primary nav is hidden or disabled during gate (per `launch-countdown.spec.ts`)
- [ ] Social / support links still work if present
- [ ] Wallet connect button hidden or disabled (no accidental connects before launch)
- [ ] No console errors on gated routes

## F-02 — Launch moment

**Trigger:** countdown reaches 0.

- [ ] Gate lifts without requiring a manual reload (timer tick flips `isLaunched` state)
- [ ] `/` starts serving `TimeCurvePage`; `/home` serves `HomePage` (per `launch-countdown.spec.ts:46`)
- [ ] Nav appears
- [ ] Wallet connect becomes available
- [ ] No double-render or hydration warning in console at the flip
- [ ] If a user was idle at the gate for hours, the page flips correctly and doesn't show stale countdown ("-00:00:03")

## F-03 — First-time visitor, sale live

**State:** no wallet connected.

- [ ] Hero renders with timer, live buys feed, status pills (Live round / Pre-start / Sale ended)
- [ ] "What matters now" panel visible
- [ ] Podiums visible but show placeholder / empty states (no buys yet means empty podium rows are acceptable, but the category explainer stays)
- [ ] WarBow section shows the rules + placeholder (not an empty table with no context)
- [ ] "Buy charms" surface shows a clear "Connect wallet" prompt, not a broken form
- [ ] Minimum buy / podium pool / total raised read correctly from chain even without a connected wallet
- [ ] No "Latest buys from indexer" aside collapse; indexerNote shows if indexer not configured

## F-04 — Wallet connect during live sale

**Trigger:** user clicks Connect on live TimeCurve page.

- [ ] RainbowKit / wagmi modal opens on first click (no double-click bug)
- [ ] Supported wallets: MetaMask, WalletConnect, Coinbase Wallet, Rainbow (per `wagmi-config.ts`)
- [ ] Wrong chain: modal prompts chain switch, does not silently fail
- [ ] After connect, wallet address appears in header, CL8Y balance reads, charm weight for wallet populates
- [ ] Disconnect returns UI to F-03 state without reload
- [ ] Connect/disconnect doesn't blow away the live buys feed or timer

## F-05 — Buy charms (CL8Y → TimeCurve)

- [ ] Amount input accepts decimals, rejects non-numeric, handles paste
- [ ] MIN / MAX buttons populate the correct value in wei with correct decimals (no 10^18 truncation)
- [ ] "You spend" and "charm weight preview" update live as user types
- [ ] Fee preview shows the 30/40/20/0/10 split (or at minimum the LP / burn / podium / rabbit lines per `fee-routing-and-governance.md`)
- [ ] Approve CL8Y step appears if allowance insufficient; skipped if already approved
- [ ] Approve tx shows in wallet with correct spender address
- [ ] Buy tx shows correct method signature and value
- [ ] On tx confirm: toast / inline success, balance updates, charm weight updates, live buys feed shows the new buy
- [ ] On tx reject: clean cancel state, no hung loading spinner
- [ ] On tx revert: error surfaces with an actionable message (not "Internal JSON-RPC error")
- [ ] Below-MIN: button disabled AND visible reason (tooltip or inline text) — this mirrors bridge #113, apply the same UX standard here

## F-06 — Timer-extension buy

- [ ] Timer urgency class switches tone as deadline approaches (warning → critical) per `timerUrgencyClass` logic
- [ ] A buy visibly bumps the timer forward
- [ ] `TimerHeroParticles` animation doesn't tank performance on mid-range mobile
- [ ] Timer label switches from "Starts In" → "Time left" → "Sale ended" at the right transitions
- [ ] Live buys feed scrolls / animates without layout shift

## F-07 — WarBow PvP

- [ ] Steal cap visible (3 per victim per UTC day)
- [ ] Bypass burn / Guard burn numbers read from contract (not hardcoded)
- [ ] Guard button: active only when user has a guardable position
- [ ] Steal button: active only if under-cap and user has BP weight
- [ ] Revenge button: appears only when revenge window is open
- [ ] Flag claim: appears only when room goes quiet per contract state
- [ ] Every action produces a rivalry feed row when it confirms
- [ ] Acting on self is blocked (no self-steal self-guard self-revenge)

## F-08 — Podium standings

For each of the four categories:

- [ ] **Last Buy** — 40% slice, shows final buyer + 2 prior
- [ ] **WarBow** — 25% slice, top 3 by BP
- [ ] **Defended Streak** — 20% slice, best under-15-min streak per wallet
- [ ] **Time Booster** — 15% slice, wallets who added the most real seconds

Per category:
- [ ] 1st / 2nd / 3rd show wallet, amount, decimal + abbreviated formats
- [ ] Empty state renders a "Largest reserve slice in category" placeholder, not a broken row
- [ ] Total prize pool = sum of all 4 slices matches `podium pool` header value

## F-09 — Post-sale redeem charms → DOUB

- [ ] `endSale` transitions UI to redemption mode: buy form disappears, redeem form appears
- [ ] Redeem shows: user's charm weight, total charm weight, DOUB claimable pro-rata
- [ ] Double-claim blocked (matches `test_double_claim_reverts`)
- [ ] Redeem tx succeeds → DOUB appears in wallet balance
- [ ] Post-redeem: charm weight shows as zero / claimed state
- [ ] Podium payouts clearly separated from charm redemption (DOUB is charm payout; CL8Y is podium payout, per launchplan §5)

## F-10 — Presale vesting UX

**Contract:** `DoubPresaleVesting.sol` (added 4/16).

- [ ] Connected beneficiary sees: vested total, claimable now, next unlock time
- [ ] 30% available at `startVesting()`; linear remainder over configured duration (default 180 days)
- [ ] Claim button: disabled when claimable = 0
- [ ] Claim tx: transfers correct amount, updates vested state, emits event
- [ ] Non-beneficiary sees clear "not eligible" state (not an empty form)
- [ ] Clock shows in user's local time zone AND UTC to avoid confusion

## F-11 — Under-construction routes

- [ ] `/rabbit-treasury`, `/collection`, `/referrals` render `UnderConstruction.tsx` with feature description
- [ ] No broken links to real pages
- [ ] Copy explains what the feature WILL be, per launchplan
- [ ] Consistent branded shell (per `surface-shells.spec.ts`)

## F-12 — Third-party DEX pages

**With `VITE_KUMBAYA_DEX_URL` / `VITE_SIR_DEX_URL` set:**
- [ ] `/kumbaya` / `/sir` show third-party disclaimer
- [ ] Placeholder LP readout visible (not real LP data yet — spec says placeholder at launch)
- [ ] Outbound link opens in new tab with `rel="noopener noreferrer"`

**Without env vars set:**
- [ ] Same disclaimer still renders
- [ ] No outbound link button appears (not a dead button)
- [ ] No console errors from undefined env

## F-13 — Mobile layout (390x844)

Every flow F-01 through F-12 should:
- [ ] Fit 390px width without horizontal scroll
- [ ] Primary CTAs (Connect / Buy / Claim / Redeem) reachable without zoom
- [ ] Timer + buy surface visible above fold on TimeCurve page
- [ ] Tap targets ≥ 44x44 px
- [ ] Modals don't clip
- [ ] Per `timecurve.spec.ts` mobile variant: "Buy charms", "What matters now", "WarBow moves and rivalry" headings visible

## F-14 — Error states

- [ ] RPC down: banner surfaces, no white screen; contract reads show loading then error with retry
- [ ] Indexer stale / disconnected: `IndexerStatusBar` shows warning state; live buys feed shows "Set the indexer URL or wait for indexed buys"
- [ ] Wrong chain in wallet: prompt chain switch, contract reads gracefully fail
- [ ] Wallet locked / disconnected mid-session: UI returns to F-03 state, doesn't crash
- [ ] Tx in flight → user closes tab → reopens: pending state recovers from localStorage-free approach (session-only) without leaving zombie UI
- [ ] 4337 / user-rejected: clean message, not "unknown error"

## F-15 — Accessibility

- [ ] All interactive elements reachable by Tab
- [ ] `aria-label`s on icon-only buttons
- [ ] Countdown has `aria-live="polite"` so SR announces at meaningful intervals (not every second)
- [ ] Color contrast on status pills (critical / warning / info) passes WCAG AA
- [ ] Podium category headings use correct heading hierarchy
- [ ] Form inputs have associated labels

---

## Hand-off notes for second QA dev

- Verify on your local laptop clone of yieldomega with `npm run dev` pointing to devnet, not server preview
- Playwright UI specs cover ~8/15 flows (F-01, F-02, F-03 partial, F-13); rest are manual
- Cross-reference with `docs/qa/YO-TimeCurve-QA-Checklist.md` and `docs/qa/QA-onboarding-gitlab-issue-body.md` so we don't duplicate
- Use my YO #3 / #4 / #5 verification approach as template: comment with evidence + metrics + screenshots per flow
- Log findings as new YO issues, tag @Brouie for review before @PlasticDigits
