# CL8Y Bridge — End-to-End UX Verification Checklist

> Flow: Cross-chain bridge user experience — chain+token selection, approvals, transfer submission, progress tracking, history, verify, settings, error handling, responsive layout
> Author: @Brouie (AVE)
> Version: 1.0 — 2026-04-22
> Repo: cl8y-bridge-monorepo
> Surface: https://bridge.cl8y.com/
> Status: Draft for dev review

## 1. Purpose & Scope

This checklist covers visual / manual UX verification of the CL8Y bridge frontend across all primary user flows spanning 4 chains (Terra Classic, BSC, opBNB, Solana). It complements automated E2E matrix testing (Playwright, operator integration, multichain-rs tests) by covering what those don't catch: pre-transaction UX, progressive disclosure, error-state clarity, multi-wallet flows, responsive layout, and accessibility.

### In-scope flows
- A. Chain + token selection
- B. Amount input + validation (inline + tooltip per #113)
- C. Recipient address (manual, autofill, validation)
- D. Wallet connection per chain (Terra, EVM, Solana)
- E. Token approval (EVM chains)
- F. Transfer submission + progress stepper
- G. Transfer history page
- H. Verify page
- I. Settings
- J. Error, loading, and empty states
- K. Responsive layout (mobile / tablet / desktop)
- L. Accessibility basics
- M. Cross-browser smoke

### Out-of-scope
- Operator + canceler backend correctness (covered by backend tests / security reviews)
- Contract-level security (covered by security audits + ust1-window-style sweeps)
- Onchain matrix verification (covered by \`verify-qa-onchain.sh\` + mainnet E2E matrix)
- Explorer integration correctness (assume block explorer is ground truth)

### Required evidence per item
- Screenshot or short recording
- Viewport / browser noted per capture
- \`xchainhashid\` for any on-chain transfer executed
- Wallet used noted (Station, Keplr, Leap, MetaMask, Backpack, Phantom, Solflare)

---

## 2. Prerequisites

- bridge.cl8y.com reachable and current bundle matches expected deploy
- 4-chain test wallet coverage: Terra (Station + at least one other), BSC or opBNB EVM (MetaMask + one other), Solana (Backpack + Phantom)
- Test funds on each chain: native gas + at least 2 bridgeable tokens
- Registered token mappings on the bridge for test tokens
- Operator + canceler online for the target environment
- Block explorer URLs bookmarked for each chain

---

## 3. A. Chain + Token Selection

### A1. Source chain selector
- All 4 chains selectable (Terra Classic, BSC, opBNB, Solana)
- Active source chain visually distinguished
- Chain icons visible
- Selection persists sensibly across navigation

### A2. Destination chain selector
- All valid destination chains shown
- Same-chain option NOT offered (cannot bridge to self)
- Unsupported source→destination combos filtered out before user tries (prevents dead routes)
- Swap-direction arrow button works and updates both selectors

### A3. Token selector
- Tokens filtered by selected source chain
- Only tokens with a mapping to the destination chain appear
- Unsupported tokens do not show (e.g. CL8Y→Solana correctly absent from current config)
- Token symbol + icon visible
- Disabled tokens (e.g. \`is_active: false\` in registry) either filtered out or clearly marked

### A4. Route validity
- Invalid combos caught at selector layer (strongest UX per #113 close)
- No dead-route attempts reach the amount/submit stage
- Error tooltip or copy if somehow a dead route is reached (defensive)

---

## 4. B. Amount Input + Validation

### B1. Amount input mechanics
- Decimal input accepts token's actual decimals (18 for EVM ERC20, varies for Solana SPL)
- MIN / MAX buttons populate respective bounds
- Balance and MIN+MAX shown in the input header
- Enter key does not accidentally submit form mid-input

### B2. Below-minimum state (verified on #113 closed today)
- Inline rose copy below amount field: 'Amount is below the minimum transfer amount (X token)'
- Tooltip on disabled Bridge button (via parent span wrap): 'Amount below minimum (X token)'
- Button styled as disabled, not primary-action
- MIN value displayed matches on-chain minimum

### B3. Above-maximum state (verified on #113 closed today)
- Inline rose copy: 'Amount exceeds the maximum (X token)'
- Tooltip: same message
- MAX reflects either per-tx cap OR wallet balance, whichever is lower, with clear labeling

### B4. Invalid amount (0, empty, non-numeric)
- 0: falls into below-min behavior correctly
- Empty: disabled state with 'Enter amount' style copy
- Non-numeric: rejected at input level or validated with clear message

### B5. Token with insufficient balance
- If user selects token they don't hold: amount field still accepts but validation blocks submit
- Clear 'insufficient balance' message vs the pre-tx generic validation

### B6. Rate-limit awareness
- If per-chain or per-token rate limits approach, user sees an advance warning BEFORE submitting
- 'MAX: X · 01:37:24' timer visible (as observed on production) — helps user understand throttle

---

## 5. C. Recipient Address

### C1. Manual entry
- Recipient field accepts chain-appropriate format (\`terra1...\`, \`0x...\`, Solana base58)
- Format validation: rejects mismatched prefix for destination chain
- Short or malformed addresses blocked from submit

### C2. Autofill with connected wallet
- 'Autofill with connected wallet' link/button visible when appropriate
- Fills correct destination-chain wallet if user has one connected
- Hides or disables if no compatible wallet is connected

### C3. Address display
- Filled address shown in full or with clear truncation
- Copy / clear action available
- Warning if recipient address equals sender (same-wallet cross-chain is valid but worth acknowledging)

### C4. Cross-format protection
- Pasting a Terra address into an EVM recipient field: caught and rejected with clear message
- Inverse: pasting 0x into Terra recipient: caught
- Solana base58 → EVM: caught

---

## 6. D. Wallet Connection

### D1. Terra wallet
- 'Connect TC' button visible when no Terra wallet connected
- Button switches to connected-state UI (address truncated, click for details) when connected
- Supported wallets at minimum: Station. If Keplr / Leap supported: both should work with no quirks
- Disconnect returns cleanly to pre-connect state

### D2. EVM wallet
- 'Connect EVM' button for BSC + opBNB
- Network switch prompt if wallet is on wrong network
- Chain icons clearly indicate which EVM chain is active
- If source = BSC and wallet is on opBNB, UI prompts to switch before allowing approve/submit

### D3. Solana wallet
- 'Connect SOL' button
- Supports Backpack, Phantom, Solflare (per meeting notes Solflare still pending — flag if present)
- Each wallet's deep-link on mobile / browser-extension on desktop works

### D4. Multiple wallets connected
- User can have Terra + EVM + Solana connected simultaneously
- Wallet display in header shows all three state indicators
- Disconnecting one does not disconnect others

### D5. Wallet mismatch (iPhone Keplr — ref bridge #5 longstanding)
- iPhone Keplr switching chain connect order should not cause wrong-address binding
- This is an edge case from existing #5 bug — spec should check for regression

---

## 7. E. Token Approval (EVM chains)

### E1. Approval prompt
- For ERC20 on BSC / opBNB, approve step happens before bridge submit
- User sees clear 'Approve X token' prompt with amount requested
- Unlimited vs exact-amount approval: tell user which is being requested

### E2. Existing allowance
- If user already has sufficient allowance, approve step is skipped
- No redundant approval prompts

### E3. Approval rejection
- User rejects approval: UI returns to pre-approval state cleanly, no stuck spinner
- Error message explains that approval is needed to proceed

### E4. Gas + native balance check (pre-approval)
- If wallet lacks native gas to submit approval, warn before prompt
- Shows gas balance vs estimated approval gas cost

---

## 8. F. Transfer Submission + Progress Stepper

### F1. Submit mechanics
- Bridge button becomes primary-styled once all validation passes
- Wallet prompt with readable transaction preview (not raw calldata)
- Source-chain tx hash captured and displayed immediately on broadcast

### F2. 4-step progress stepper
- Step 1: Source tx submitted + confirmed
- Step 2: Source tx validated by operator
- Step 3: Destination approve-transaction submitted (if Solana inbound) OR destination tx executed directly (other routes)
- Step 4: Destination withdraw-executed / tokens received

Per-step:
- Visual indicator of current step
- Timestamp per completed step
- Tx hash clickable to appropriate chain explorer
- Estimated time remaining based on typical operator latency

### F3. Partial progress persistence
- User navigates away and back: stepper state restored from history
- Browser refresh during in-flight transfer: state recovered from indexer

### F4. Failure at a step
- Clear 'Failed at step N' state with reason (operator rejection, chain error, etc.)
- Retry path surfaced where applicable (e.g. destination tx needs user action for Solana withdraw_execute)
- Contact / support affordance if stuck (Telegram link, docs reference)

### F5. Solana inbound withdraw flow (per #111 closure today)
- User bridging TO Solana must call \`withdraw_execute\` themselves (not operator auto-executed)
- UI must clearly prompt user for this action after operator approves
- 'Execute withdrawal' button or equivalent that triggers the Solana tx
- Sufficient Solana native gas to execute

### F6. Completion state
- Success banner with \`xchainhashid\` for traceability
- Both source + destination tx hashes visible
- Links to both chain explorers
- 'Bridge another' CTA to reset form

---

## 9. G. Transfer History Page

### G1. History list
- Tab or page accessible from main nav
- Shows user's recent transfers across all chains
- Each row: source chain → destination chain, token, amount, status, timestamp
- Click-through to per-transfer detail view

### G2. Status filtering
- Filter by status (all / in-progress / completed / failed)
- Sort by newest / oldest

### G3. Per-transfer detail
- Full 4-step stepper for any past transfer
- All tx hashes with explorer links
- \`xchainhashid\` prominent
- Resumable: if transfer is stuck at a step user can action, the detail page surfaces the action

### G4. Empty state
- First-time user with no transfers: clear empty state with 'Bridge your first transfer' CTA

### G5. Post-deploy history
- After a new bundle deploys, history from prior deploys should still be visible (indexer-backed, not frontend-local)

---

## 10. H. Verify Page

### H1. Verify layout
- Per-chain verification status visible
- For each chain: operator last-seen block / height, bridge contract reachable, chain registered status
- T2022 verification surface (per recent bridge #97 work) present and checkable

### H2. Verify drill-down
- Click into a chain to see per-token verification (token mappings, allowances, registered status)
- 24/24 pattern from prior T2022 verification runs matches expected token count

### H3. Verify errors
- If a chain RPC is down / degraded, verify page shows a clear indicator, not a blank result
- Indexer lag or gap detected: flagged

---

## 11. I. Settings

### I1. Network selection
- If bridge supports multiple environments (mainnet / testnet), selector is present
- Current environment prominently displayed

### I2. Slippage / tolerances
- Any user-configurable tolerances accessible from settings

### I3. RPC preferences
- Per-chain RPC URL override (for power users) — may be out of scope depending on product direction

### I4. Theme
- Light / dark toggle accessible and persistent

---

## 12. J. Error, Loading, and Empty States

### J1. Loading
- Chain balance fetch: spinner or skeleton per chain, not a blank
- Token mapping fetch: cached and doesn't block UI
- Indexer lag acknowledged if >10s behind

### J2. Errors
- RPC down (one chain): isolated, other chains still usable
- All RPCs down for a chain: clear message, no spinner hang
- Operator offline: warn user before they submit; do not let them broadcast a tx that will get stuck
- Rate-limited by wallet extension: backoff message, not a raw error

### J3. Empty states
- No connected wallet: clear CTA (verified #113 pattern for Terra)
- No history: clear empty state
- No available routes: if all tokens are disabled (maintenance mode), clear global banner

### J4. First-time visitor
- Incognito: landing usable without prior state
- No stale wallet prompts
- Clear intro to what the bridge does

---

## 13. K. Responsive Layout

### K1. Desktop (≥1280px)
- All primary surfaces fit without horizontal scroll
- Wallet-connect buttons in header have space for all 3 chains
- History table renders fully, no truncation

### K2. Tablet (768-1279px)
- Header adapts (wallets may collapse to a single 'Wallets' dropdown)
- Form stays single-column, thumb-reachable

### K3. Mobile (320-767px)
- Bottom-nav or hamburger for main nav
- Wallet deep-link flows work for mobile Station, Keplr, Phantom, Backpack
- 4-step stepper readable on narrow screens

### K4. Safe-area / notch
- iOS safe-area padding respected

---

## 14. L. Accessibility Basics

### L1. Keyboard
- All interactive elements Tab-reachable
- Focus indicators visible
- Modals trap focus and restore on close

### L2. Screen reader smoke
- Landmarks present
- Wallet connect buttons labeled
- 4-step stepper progression announced via aria-live
- Tx hash copy action has accessible label

### L3. Color contrast
- Rose error text on dark background: verify ≥4.5:1
- Primary CTA button: verify legibility

### L4. Motion
- \`prefers-reduced-motion\` respected for progress animations

---

## 15. M. Cross-Browser Smoke

### M1. Desktop browsers (minimum)
- Chrome (latest): full flow
- Firefox (latest): full flow — historically flakier for wallet extensions
- Safari (latest): full flow + wallet compat check

### M2. Mobile browsers
- iOS Safari: wallet deep-link flows (Station, Phantom, Backpack)
- Chrome Android: same
- DuckDuckGo / Brave: if time allows

---

## 16. Execution Guidelines

### 16a. Test environments
- Pre-mainnet (required): local bridge stack via \`make start-qa\` with operator + canceler + LocalTerra + Anvil + test Solana validator
- Mainnet smoke (required): bridge.cl8y.com against small-value real transfers
- Mobile physical (recommended): real iOS + real Android for wallet deep-link flows

### 16b. Capture standard
- Full-page screenshots preferred for form states
- Screen recording (≤30s) for multi-step transfer flow
- Naming: \`<section>-<step>-<viewport>-<browser>.png\`
- Include \`xchainhashid\` in any transfer-related capture

### 16c. Sign-off rules
- Each section (A-M) needs ≥1 green pass before a frontend deployment
- Transfer flow (F) requires at least one end-to-end real mainnet pass per bundle
- Broken validation flows (B) block deploy
- A11y or mobile regressions (L / K): non-blocking, filed as backlog

---

## 17. Open Questions for Your Review

- **Wallet scope finalization:** which Terra wallets beyond Station are officially supported? Same for EVM (MetaMask only, or Rabby / Trust Wallet / Coinbase Wallet too?) and Solana (Backpack + Phantom definite, Solflare pending per meeting).
- **Solflare status:** still pending from prior sessions — if it's going to ship, spec should include it
- **T2022 verification surface:** how should the Verify page display T2022 status vs regular SPL tokens? Should this be a separate tab?
- **History storage:** backend-indexed or browser-local? Impacts spec for 'history across deploys' item
- **Mobile wallet strategy:** WalletConnect QR, mobile-wallet deep-links, or both?
- **Rate-limit surface:** how should \"per-chain rate limit approaching\" be warned pre-submit vs post-submit?

## 18. References

- Bridge frontend: \`packages/frontend/\` in cl8y-bridge-monorepo
- Operator: \`packages/operator/\` + security review #115
- Canceler: \`packages/canceler/\` + security review #114
- Bridge #113 (validation UX fix, closed today) — reference for B2/B3
- Bridge #109 (RPC fallback, closed today) — reference for J2
- Bridge #111 (post-upgrade matrix, closed today) — reference for F5 Solana withdraw flow
- Bridge #5 (iPhone Keplr, longstanding) — reference for D5
- Mainnet endpoint: https://bridge.cl8y.com/
- Sister specs: UST1-Window-Security-Checklist.md, YO-DOUB-Launch-UX-Flows.md, YO-TimeCurve-Verification-Spec.md, DEX Visual UX Checklist (ecosystem-qa #10)
