# CL8Y DEX Terra Classic — Visual UX Verification Checklist

> Flow: End-to-end DEX user experience — Charting, Swaps (pool + hybrid), Liquidity Provision, Limit Orders, and supporting surfaces
> Author: @Brouie (AVE)
> Version: 1.0 — 2026-04-22
> Repo: cl8y-dex-terraclassic
> Status: Draft for dev review

## 1. Purpose & Scope

This checklist covers visual / manual UX verification of the CL8Y DEX frontend-dapp across all primary user flows that a mainnet user will execute. It is meant to be run before each deployment to mainnet, after significant frontend or indexer changes, and as part of release-gate QA.

Automated E2E coverage (Playwright, Vitest, contract tests, indexer tests) covers correctness of values, state, and happy-path flows. This spec focuses on what those tests don't catch: visual correctness, progressive disclosure, error-state clarity, responsive layout, and accessibility.

### In-scope flows
- A. Charting (price, volume, pair info)
- B. Swap (pool-only)
- C. Swap (hybrid: pool + on-chain limit book)
- D. Liquidity provision (add / remove)
- E. Limit orders (place / view / cancel)
- F. Pair selector + global navigation
- G. Wallet connection + account state
- H. Error, loading, and empty states
- I. Responsive layout (mobile / tablet / desktop)
- J. Accessibility basics

### Out-of-scope
- Contract-level correctness (covered by Foundry / cargo test suites)
- Indexer API correctness (covered by indexer integration tests)
- Automated Playwright E2E coverage (separate from this checklist)
- Cross-chain flows (bridge UX is a separate spec)

### Required evidence per item
- Screenshot or short screen recording
- Viewport / browser noted per capture (e.g. \`Desktop / Chrome\`, \`Mobile / Safari 375px\`)
- Transaction hash for any on-chain action (for traceability)

---

## 2. Prerequisites

- DEX deployed to target environment (LocalTerra for dev, Columbus-5 for mainnet verification)
- Indexer online and caught up
- At least 3 seeded pairs with non-trivial liquidity and recent swap history
- Test wallet with sufficient uluna + at least 2 test tokens
- Wallet extension installed: Station (primary). Others if supported: Keplr, Leap
- Clean cache / incognito session for the 'first-time visitor' checks

---

## 3. A. Charting

### A1. Price chart renders
- Chart renders within ~2 seconds on broadband
- Candles / line visible with ≥24h of data (if pair has history)
- Current price prominent, matches latest on-chain swap
- Y and X axis labels readable, reasonable tick density

### A2. Timeframe selection
- Timeframe selector (1h / 4h / 1d / 7d / 30d / all)
- Each timeframe loads without flicker or stale data
- Active timeframe visually distinguished
- Selection persists sensibly across pair changes

### A3. Volume chart
- Volume bars visible below or alongside price chart
- Volume scale readable
- Volume correlates with swap events from indexer

### A4. Pair metadata
- Token pair symbols (e.g. EMBER / JADE)
- Pair contract address accessible (link or copy)
- Liquidity depth (total reserves, USD-equivalent if applicable)
- 24h volume, 24h price change, 24h high/low
- Fee tier / pool type if relevant

### A5. Chart interaction
- Hover / tap shows OHLCV tooltip
- Tooltip doesn't obscure the candle
- Dismisses cleanly when pointer leaves

### A6. Pair with no recent activity
- Empty state renders gracefully, not a broken chart
- Empty-state copy is clear

---

## 4. B. Swap — Pool-Only

### B1. Quote display
- Output amount quoted within ~1 second
- Quote updates as input changes without flicker
- Price impact shown in percent
- Minimum received (after slippage) shown
- Fee breakdown visible (protocol + LP fee)

### B2. Slippage control
- Preset values + custom input
- Changing slippage updates min-received live
- High slippage (>5%) shows warning

### B3. Price impact warnings
- <1%: informational
- 1-3%: visible warning
- 3-5%: stronger warning
- \`>\`5%: requires explicit confirmation

### B4. Route visibility
- Swap route displayed (direct or multi-hop)
- Intermediate tokens labeled correctly

### B5. Execute
- Wallet prompts with clear tx preview
- Loading state during broadcast + confirmation
- Success state shows tx hash + explorer link
- Failure shows readable error, not raw revert

### B6. Post-swap UX
- Balance updates shortly after confirmation
- Swap appears in transaction history
- Chart reflects new price

---

## 5. C. Swap — Hybrid (Pool + On-Chain Limit Book)

### C1. Hybrid mode discovery
- UI indicates hybrid is in use when book improves the quote (toggle, badge, inline label)
- Hybrid vs pool-only toggle (if exposed) is clear

### C2. Hybrid quote decomposition
- Quote breakdown shows pool leg vs book leg amounts
- Effective price blends both correctly vs pool-only
- Fee breakdown separates pool LP fee from limit maker/taker fees

### C3. Hybrid-specific warnings
- Thin book depth → informed user
- All book orders consumed → remaining falls through to pool cleanly

### C4. Execute hybrid
- Single wallet prompt for the hybrid operation
- Tx preview shows both pool + book interaction
- Success state shows both legs in the receipt

### C5. Post-hybrid UX
- Limit book visually updates to reflect filled orders
- Recent swaps shows the hybrid fill with labeling

---

## 6. D. Liquidity Provision

### D1. Add LP — single-pair flow
- Reachable from nav or pair page
- Two token input fields with symbol + balance
- Auto-balancing on single-side input
- Estimated LP tokens received shown
- Your share of pool (%) after deposit
- Current ratio + price displayed

### D2. Add LP warnings
- Thin pool (significant relative liquidity) → warning
- Price moved since load (stale quote) → warning
- Token approval step clear and separate from deposit

### D3. Add LP execute
- Approve button per non-native token
- Existing sufficient allowance is reused
- Final Supply / Add Liquidity button with sensible tx preview
- Success state shows LP tokens received + tx hash

### D4. Remove LP flow
- Accessible from pair page or LP positions list
- Percentage slider or amount input
- Estimated token outputs in real time
- Slippage protection on output estimates
- Execute → success with tx hash

### D5. LP positions list
- Reachable from nav / account
- Each position shows pair, LP token balance, underlying amounts, current value
- Empty state renders cleanly

### D6. LP metadata
- Pool APR / fee yield indicator if available
- Historical earnings or link to that info

---

## 7. E. Limit Orders

### E1. Order form
- Reachable from pair page
- Inputs: side, amount, target price
- Expected output computed live
- Validity / expiry control if supported
- Fee structure for limit orders displayed

### E2. Order validation
- Below minimum: inline error + disabled submit + tooltip (mirror bridge #113 pattern)
- Above balance: inline error
- Price at or worse than current spot: warning or gated confirm
- Price unreasonably far from spot: stronger warning

### E3. Place order execute
- Wallet prompt with tx preview
- Success shows order ID + tx hash
- Order appears in open orders list within ~1 second

### E4. Open orders list
- Shows side, amount, price, filled, remaining, status
- Sort by recent, price, expiry
- Filter by pair

### E5. Cancel order
- Cancel button per open order
- Success → order moves to cancelled or is removed
- Cancel tx hash available

### E6. Fill visibility
- Partial fill updates filled/remaining
- Full fill moves order to filled with received amount

### E7. Order book display
- Aggregated ladder on pair page
- User's own orders highlighted
- Book updates in ~real time

---

## 8. F. Pair Selector + Global Nav

### F1. Pair selector
- Accessible from all top-level pages
- Search by symbol works
- Recently used pairs surface
- Low-liquidity / suspicious pairs flagged

### F2. Global nav
- Swap / Liquidity / Limit Orders / Chart / Account reachable
- Active section highlighted
- Collapses cleanly on narrow viewports

### F3. Theme toggle
- Light / dark toggle accessible and persistent
- Contrast meets WCAG AA in both modes
- No unstyled flicker on first load

---

## 9. G. Wallet Connection + Account

### G1. Initial connect
- Connect button visible on every page when disconnected
- Wallet options listed (Station primary, Keplr/Leap if supported)
- Install link if extension not detected
- Auto-reconnect works

### G2. Account display
- Connected address shown (truncated)
- Click-to-copy
- Explorer link
- Relevant token balances visible

### G3. Disconnect
- Reachable within 1 click
- UI returns to disconnected state cleanly

### G4. Network mismatch
- Wrong-network prompt + Switch Network action
- Triggers wallet-side network change if supported

---

## 10. H. Error, Loading, and Empty States

### H1. Loading
- Every async fetch shows indicator
- Loading doesn't leak into final state
- Slow network still surfaces a sensible state within ~5 seconds

### H2. Errors
- Indexer down → clear error + retry
- LCD timeout → clear message
- Tx simulation failure → human-readable
- Tx broadcast failure → retry affordance
- Rate limited → backoff message

### H3. Empty states
- No liquidity → empty state + add-liquidity CTA
- No trading history → empty state
- No LP positions → onboarding CTA
- No open limit orders → empty state

### H4. First-time visitor
- Incognito → landing is understandable without prior context
- No stale wallet prompts

---

## 11. I. Responsive Layout

### I1. Desktop (≥1280px)
- Primary actions above the fold
- Chart and form don't overlap
- Modals center and size sensibly

### I2. Tablet (768-1279px)
- Nav adapts (inline vs hamburger)
- Chart and form stack or scroll cleanly
- Touch targets ≥44px

### I3. Mobile (320-767px)
- Bottom-nav or hamburger
- Swap form thumb-reachable, no horizontal scroll
- Chart renders or gracefully simplifies
- Wallet connect works on mobile wallet deep links

### I4. Orientation
- Portrait + landscape without overflow
- Safe-area (notch) respected on iOS

---

## 12. J. Accessibility Basics

### J1. Keyboard
- All interactive elements reachable via Tab
- Focus indicators visible
- Enter / Space activate buttons and links
- Modals trap focus and restore on close

### J2. Screen reader smoke
- Landmarks present (nav, main, complementary)
- Form fields labeled
- Decorative icons aria-hidden
- Dynamic content announced via aria-live

### J3. Color contrast
- Body text ≥4.5:1
- Large text ≥3:1
- Interactive elements have a state not relying on color alone

### J4. Motion
- \`prefers-reduced-motion\` respected
- No auto-playing unpausable animation

---

## 13. Execution Guidelines

### Test environments
- Pre-mainnet (required): LocalTerra with full deploy-dex-local.sh stack + indexer + laptop-frontend
- Mainnet smoke (required): Columbus-5 production deploy with read-only or small-value wallet
- Mobile physical (recommended): at least one real iOS + one real Android

### Browser coverage (minimum)
- Chrome (latest)
- Firefox (latest)
- Safari (latest) — especially mobile Safari

### Capture standard
- Full-page screenshots preferred
- Short recordings (≤15s) for multi-step flows
- Naming: \`<section>-<step>-<viewport>-<browser>.png\`

### Sign-off
- Each section (A-J) needs ≥1 green pass before deployment
- Filed issues linked back to checklist execution
- Broken flows / missing error states = blocking
- Polish / minor UX / a11y improvements = backlog

---

## 14. Open Questions for Your Review

- **Wallet scope:** Station only, or also Keplr / Leap?
- **Hybrid UI:** explicit 'use hybrid' toggle, or automatic based on book depth?
- **LP positions page:** what historical data (earned fees, impermanent loss) surfaces vs defer?
- **Limit order expiry:** GTC-only, or user-selectable?
- **Mobile wallet flow:** deep-link to Station mobile, or WalletConnect QR?
- **Chart library:** TradingView widget, recharts, custom? (affects a11y attainability)

## 15. References

- Frontend source: \`frontend-dapp/\` in cl8y-dex-terraclassic
- Contracts: \`smartcontracts/\` — pair, router, factory, limit-book
- Indexer API: \`docs/integrators.md\`
- ADR 0001 (hybrid): \`docs/adr/0001-hybrid-quoting-and-routing.md\`
- Closed superseded: \`#50 Full QA Pass v3\`
- Sister specs: UST1-Window-Security-Checklist.md, YO-DOUB-Launch-UX-Flows.md, YO-TimeCurve-Verification-Spec.md
