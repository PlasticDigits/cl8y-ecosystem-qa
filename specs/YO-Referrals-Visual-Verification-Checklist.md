# YO Referrals — Visual Surface Verification Checklist

> Status: DRAFT (approved via yieldomega #59, scope approved 2026-04-24)
> Scope: post-launch frontend build with referral registry wired, dedicated session.
> Sister checklists: `YO-DOUB-Launch-UX-Flows.md`, `YO-TimeCurve-Verification-Spec.md`.
> Source: gaps documented at the close of yieldomega #43 (umbrella) plus the proposal in #59.

## Context

Referrals slice (`yieldomega@7ce2315` ReferralRegisterSection + `0f400e0` `REFERRAL_EACH_BPS = 500` canonicalization) was code-signed-off in YO #43 with 8/8 path-capture vitest, query-override-path, no-shadow on `/timecurve/arena|protocol`, `/home` preservation post-launch, and on-chain BPS consistency across contract / docs / tests / frontend fallback.

The visual surface of `/referrals` was **not** walked in that session — stack state could not satisfy both post-launch routing AND configured registry env var in one go. Per dev, leaderboard UI is out of scope for this checklist (not yet built). The remaining visual gaps are tracked here.

## Pre-conditions

- Frontend built post-launch: `VITE_LAUNCH_TIMESTAMP` resolves to a past timestamp (so `LaunchGate` does not redirect `/referrals` to the countdown page).
- `VITE_REFERRAL_REGISTRY_ADDRESS` configured to the deployed referral registry on the target stack (else the page falls back to TimeCurve `referralRegistry()` lookup — also acceptable, note which path is exercised).
- Local Anvil stack with referral registry fixture seeded; OR live network with registry already deployed.
- Test wallet funded for gas + holds `CL8Y` (registerCode requires CL8Y approval per current ReferralRegisterSection flow).

## Verification matrix

| # | Surface | Expected | Evidence required |
|---|---|---|---|
| R1 | Page renders post-launch | `/referrals` loads without console errors, no white-screen, no infinite spinner; arcade shell + hero + register panel structure visible | Console screenshot + page screenshot |
| R2 | Empty / unregistered state (connected) | Wallet-connected user with no registered code sees the register CTA + code input + on-chain `REFERRAL_EACH_BPS` rendered (5.00%) | Screenshot |
| R3 | Empty / disconnected state | No wallet → page renders read-only with connect prompt; no register form crash | Screenshot |
| R4 | Register flow E2E | Type code → CL8Y approval prompt → register tx submitted → success state shown → registered code visible on page → localStorage `yieldomega.ref.v1` updated | Screenshot of each step + tx hash |
| R5 | Wallet-connected post-register state | Page shows the registered code + a copy-able referral link in the format the app renders elsewhere (anchor URL pattern — confirm against `referralStorage` source) | Screenshot |
| R6 | Copy-to-clipboard / share-link UX | Click copy → toast or visual confirmation; mobile long-press / right-click do not break the page | Desktop + mobile screenshots |
| R7 | Path capture from `/?ref=…` end-to-end (visual) | Visit `/?ref=somecode` → `applyReferralUrlCapture` writes `yieldomega.ref.v1` → register flow uses captured code as default value (this was unit-tested in #43 but never visually walked) | Screenshot showing pre-fill |

## Out of scope

- Leaderboard UI — not yet built per dev (#43 comment 2026-04-23 08:05); cover when shipped
- Contract-level slug registry + restricted-word set — umbrella items in #43, separate verification track
- `kumbayaRoutes` / Buy CTA referral plumbing — code-signed in #43
- `REFERRAL_EACH_BPS = 500` invariant across docs / contract / tests / frontend fallback — already verified in #43

## Procedure

1. Bring up Anvil stack with referral registry fixture deployed, OR connect to a live network with the registry deployed.
2. Build frontend with `VITE_LAUNCH_TIMESTAMP` set to a past timestamp and `VITE_REFERRAL_REGISTRY_ADDRESS` pointing to the registry.
3. Walk R1 through R7 in order; capture screenshots at each step.
4. File any findings as sub-issues against `yieldomega` referencing this spec; reference back to the parent tracking issue.

## Acceptance

All 7 rows produce evidence (screenshot or tx hash) and either PASS or have a filed sub-issue.
