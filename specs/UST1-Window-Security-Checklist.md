# UST1 Window — Security Review Checklist

**Repo:** PlasticDigits/ust1-window
**Scope:** ust1-oracle + ust1-window CosmWasm contracts (Terra Classic) + ust1-oracle-service (off-chain, BSC-reading).
**Purpose:** Enumerate top-20 EVM and top-20 CosmWasm security issues, cross-mapped to every method on both sides of the window.
**Status:** DRAFT — pending review on cl8y-ecosystem-qa before individual issues are opened on ust1-window.

---

## Contract Surface

### ust1-oracle (CosmWasm, Terra Classic)
- **Execute:** `UpdateRate`, `SetOracleOperator`, `SetPaused`, `ProposeGovernance`, `AcceptGovernance`
- **Query:** `Config`, `State`
- **Lifecycle:** `instantiate`, `migrate`

### ust1-window (CosmWasm, Terra Classic)
- **Execute:** `Receive(Cw20ReceiveMsg)` (swap entry, dispatches vFDUSD→UST1 mint or UST1→vFDUSD burn), `SetLimits`, `SetPaused`, `SetFeeBps`, `ProposeGovernance`, `AcceptGovernance`
- **Query:** `Config`, `EffectiveSwap`
- **Lifecycle:** `instantiate`, `migrate`

### ust1-oracle-service (Rust, off-chain)
- Polls BSC `exchangeRateStored` on Venus vFDUSD vToken (read-only EVM call)
- Applies same INV-ORACLE-THROTTLE / DAILY / MONO policy as on-chain
- Broadcasts `UpdateRate` txs to Terra oracle contract

---

## CosmWasm Top 20 Security Issues

Each issue below is mapped to every method where it applies.

### CW-01 — Missing authorization / broken access control
- [ ] `UpdateRate`: only `oracle_operator` can call; non-operator returns `Unauthorized`
- [ ] `SetOracleOperator`: only current governance can call
- [ ] `SetPaused` (oracle): only governance
- [ ] `ProposeGovernance` (oracle): only current governance
- [ ] `AcceptGovernance` (oracle): only the proposed address
- [ ] `SetLimits` (window): only governance
- [ ] `SetPaused` (window): only governance
- [ ] `SetFeeBps` (window): only governance
- [ ] `ProposeGovernance` (window): only current governance
- [ ] `AcceptGovernance` (window): only the proposed address
- [ ] `Receive`: only the registered vFDUSD cw20 or UST1 cw20 may call (`info.sender` check against configured token addresses)

### CW-02 — Reply/submsg handling (reply ordering, error propagation, reply_id collisions)
- [ ] `Receive`: if swap dispatches cw20 transfers/mints via submsg, reply_id values do not collide across vFDUSD and UST1 paths
- [ ] `Receive`: reply handler returns proper error (not silent success) on submsg failure
- [ ] No `reply_on=Never` where state mutation must be rolled back on submsg error
- [ ] `instantiate` does not start a submsg that can fail and leave contract half-initialized

### CW-03 — Integer overflow / underflow / truncation in fixed-point math
- [ ] `UpdateRate`: new_rate bounds checked before store (no silent u128 overflow on multiplication in ust1-common math)
- [ ] `Receive` vFDUSD→UST1: mint amount calculation uses `checked_mul` / `checked_div`, no `as u128` truncation
- [ ] `Receive` UST1→vFDUSD: burn→return amount uses same checked math
- [ ] Fee bps application (max 10_000) doesn't overflow on max-limit input
- [ ] Rolling 24h volume accumulator cannot wrap or truncate under max daily throughput

### CW-04 — Rounding direction favoring user (loss-of-value to protocol)
- [ ] `Receive`: both swap legs round against the user (protocol never loses dust)
- [ ] Fee calculation truncates fee down only if the remainder is returned to protocol, never to user
- [ ] Rate application never rounds in a way that lets a repeated 1-wei swap drain value

### CW-05 — Price oracle manipulation / stale rate
- [ ] `EffectiveSwap` query rejects or flags rate older than the 4h staleness bound
- [ ] `Receive` refuses to swap when oracle is paused
- [ ] `Receive` refuses to swap when `last_updated` would make the rate stale per INV-ORACLE-THROTTLE-001
- [ ] No fallback to a secondary rate source that isn't also bound-checked

### CW-06 — Governance takeover via two-step transfer abuse
- [ ] `AcceptGovernance`: only callable by exact proposed address, else `Unauthorized`
- [ ] `ProposeGovernance` overwrites any prior pending proposal (no stuck-proposal griefing)
- [ ] After `AcceptGovernance`, the `pending_governance` field is cleared (not re-accepted)
- [ ] `ProposeGovernance` to zero/invalid address rejected

### CW-07 — Migrate privilege escalation
- [ ] `migrate` entry point is admin-gated at chain level (instantiate sets `admin` correctly)
- [ ] `migrate` validates the old code_id if state shape changed
- [ ] `migrate` does not re-run `instantiate`-level defaults that would wipe governance or pause state

### CW-08 — Reentrancy via submsg → external cw20 → back into contract
- [ ] `Receive` swap path: state mutations (rolling volume, pause check) happen BEFORE submsg dispatch, not after
- [ ] No path where external cw20 callback can re-enter `Receive` and double-spend the same cw20 deposit

### CW-09 — Unbounded loop / gas-grief DoS
- [ ] No `Vec<_>` iteration over user-controlled length in any execute/query
- [ ] Rolling 24h volume state uses fixed-size accumulator (not a growing log)
- [ ] No unbounded `Map` scan in `Config` or `EffectiveSwap` queries

### CW-10 — Panic / unwrap on untrusted input
- [ ] No `.unwrap()` / `.expect()` on deserialized message fields
- [ ] No `.unwrap()` on `Addr::validate` or cw20 token address parsing
- [ ] `oracle_policy.rs` math returns `Result`, never panics

### CW-11 — Replay / double-spend across submsg boundaries
- [ ] `Receive` cw20 hook cannot be replayed by a malicious cw20 that emits duplicate `Receive` callbacks
- [ ] Rolling volume counter is incremented exactly once per swap

### CW-12 — Pause bypass
- [ ] `SetPaused { paused: true }` blocks ALL value-moving execute paths on both contracts (not only `Receive`)
- [ ] `UpdateRate` blocked when oracle paused
- [ ] Admin/governance actions (Set*, Propose/Accept) still permitted during pause for recovery

### CW-13 — Limit bypass via rolling-window boundary math
- [ ] `rolling_24h_ust1_limit` enforced as a strict inequality; equal-to-limit swap is handled consistently
- [ ] Per-tx limit evaluated BEFORE rolling-limit so a single mega-tx can't slip through with rolling=0
- [ ] Rolling-window eviction of expired entries happens before check, not after

### CW-14 — Fee configuration bypass / fee_bps > BPS_MAX
- [ ] `SetFeeBps` enforces `fee_bps <= 10_000` (same as instantiate per invariant)
- [ ] `fee_bps = 10_000` handled (zero output, no divide-by-zero path)
- [ ] Fee applies only on UST1 leg as spec says, not silently on vFDUSD leg

### CW-15 — Oracle update policy bypass (daily cap, monotonic, throttle)
- [ ] INV-ORACLE-THROTTLE-001: second `UpdateRate` within 4h rejected
- [ ] INV-ORACLE-DAILY-001: cumulative UTC-day increase >2% rejected
- [ ] INV-ORACLE-MONO-001: strictly monotonic (rate never decreases)
- [ ] Daily-cap accumulator resets at UTC midnight boundary, not 24h rolling

### CW-16 — Event / attribute injection
- [ ] All user-controlled strings (governance proposed addresses, etc.) are validated via `Addr` before emission
- [ ] No f-string-like concatenation that would let a caller forge delimiters in attributes

### CW-17 — cw20 token address spoofing
- [ ] Contract stores vFDUSD and UST1 addresses at instantiate and only trusts `Receive` from those exact addresses
- [ ] No code path accepts arbitrary cw20 as swap input (would let an attacker mint UST1 with a fake token)

### CW-18 — Instantiate parameter validation
- [ ] `instantiate` rejects zero address for governance / oracle_operator / vFDUSD / UST1
- [ ] `instantiate` rejects `fee_bps > 10_000`
- [ ] `instantiate` rejects zero or nonsensical swap limits (or treats as "no limit" explicitly, not silently)
- [ ] `instantiate` sets `paused=false` intentionally (or per-product default, not undefined)

### CW-19 — Funds (uluna/IBC) attached to cw20 calls
- [ ] `Receive` hook rejects attached funds (cw20 hooks should not carry native coins)
- [ ] Governance/admin execute paths reject attached funds unless required

### CW-20 — Dependency / version hygiene
- [ ] `cosmwasm-std` version aligned across all crates, no yanked versions
- [ ] `cw20`, `cw-storage-plus`, `cw-controllers` versions pinned, no git deps with unknown commit
- [ ] `cargo audit` clean on committed Cargo.lock

---

## EVM Top 20 Security Issues (applied to oracle-service's BSC interactions)

This project has no EVM contracts owned by us — the BSC side is a read-only `exchangeRateStored()` query on Venus vFDUSD. The checklist below applies to the oracle-service's RPC interaction and the trust assumptions it places on BSC.

### EVM-01 — RPC provider trust / single point of failure
- [ ] `BSC_RPC_URLS` accepts multiple URLs; service rotates on failure
- [ ] No single compromised RPC can forge `exchangeRateStored()` result (cross-check with ≥2 providers before broadcasting UpdateRate)
- [ ] Service fails closed (does not broadcast) if all RPCs disagree

### EVM-02 — Stale block / reorg susceptibility
- [ ] Service reads `exchangeRateStored` at a confirmed block height (≥ N confirmations), not at `latest`
- [ ] Service treats BSC reorg by re-fetching after N confirmations rather than trusting a pending read

### EVM-03 — Venus vToken address spoofing
- [ ] `VENUS_VTOKEN_ADDRESS` validated against the canonical BSC Venus deployment at startup (e.g. hardcoded allow-list or checksum check)
- [ ] Service refuses to poll if the address does not match the expected bytecode / storage layout

### EVM-04 — Exchange rate decimals / scaling mismatch
- [ ] Service converts Venus's `exchangeRateStored` (Venus-specific decimals) to the on-chain Rate format correctly, no silent precision loss
- [ ] Conversion reviewed against Venus's published decimals spec

### EVM-05 — Integer overflow in Rust client math
- [ ] No `as u128` / `as u64` truncation on exchange rate conversion
- [ ] All multiplications use `checked_*`

### EVM-06 — Policy drift between off-chain and on-chain
- [ ] Off-chain service applies identical throttle/daily-cap/monotonic rules as ust1-oracle (same ust1-common crate, not re-implemented)
- [ ] Unit tests assert the two implementations agree on edge cases

### EVM-07 — Private key / signing key handling
- [ ] Oracle signing key not logged, not in git, not in Docker image, sourced from env or keystore at runtime
- [ ] .gitleaks config catches accidental commits

### EVM-08 — Unauthenticated RPC (TLS, MITM)
- [ ] All BSC RPC URLs are HTTPS; service rejects HTTP
- [ ] Terra LCD URL is HTTPS

### EVM-09 — DoS on oracle service
- [ ] Service has retry + backoff, not tight-loop retry
- [ ] RPC rate limit aware, rotates providers

### EVM-10 — Liveness gap creating staleness on-chain
- [ ] Service alerts if no successful broadcast in >4h (before staleness hits production swaps)
- [ ] Service restarts cleanly (no partial broadcast state that would double-submit)

### EVM-11 — Replay of broadcast UpdateRate tx
- [ ] Terra nonce/sequence tracked so a retry doesn't double-submit
- [ ] Idempotent in practice: submitting same rate twice within 4h is rejected by on-chain throttle

### EVM-12 — Malicious UpdateRate injection
- [ ] Only the oracle operator key can broadcast; service does not expose an RPC that takes rate as a parameter
- [ ] Even if service is compromised, on-chain caps (daily +2%, monotonic, 4h throttle) bound the blast radius

### EVM-13 — Venus vFDUSD deprecation / pause
- [ ] Service handles `exchangeRateStored` reverting (Venus paused) as "do not update" rather than propagating zero rate
- [ ] Configurable behavior: error-alert vs silent-hold

### EVM-14 — Wrong-chain attack on BSC RPC
- [ ] Service verifies BSC `chainId = 56` on every connection
- [ ] Refuses to read from opBNB, testnet, or any other chain accidentally configured

### EVM-15 — Front-running by operator
- [ ] Operator cannot time `UpdateRate` broadcasts to exploit swap windows (throttle + daily cap limit this structurally, but call out: operator key rotation + multi-sig on governance roles recommended)

### EVM-16 — Read-write confusion
- [ ] Service performs only `call` (read) on BSC, no `sendTransaction`
- [ ] Service performs `broadcast` (write) only on Terra to the oracle contract, not to arbitrary contracts

### EVM-17 — Config file injection
- [ ] Env-based config validated at startup (addresses match expected format, URLs parse, RPC list nonempty)
- [ ] Service refuses to start with empty / malformed config rather than falling back to unsafe defaults

### EVM-18 — Logging of sensitive state
- [ ] Oracle signing key never logged
- [ ] User cw20 balances / governance addresses logged only at debug, not info

### EVM-19 — Dependency supply-chain
- [ ] `cargo audit` clean
- [ ] `requirements-dev.txt` pins exact versions for Python deploy helpers

### EVM-20 — CI / deploy pipeline integrity
- [ ] Gitleaks action present and runs on every push
- [ ] Pre-commit hooks (cargo fmt, clippy -D warnings, shellcheck, compileall) active
- [ ] Contracts built via workspace-optimizer Docker image, not host toolchain (reproducible bytecode)

---

## Method × Issue coverage matrix

Cells indicate whether the checklist issue applies to the method (✓ apply) or is N/A.

### ust1-oracle

| Method | CW-01 | CW-02 | CW-03 | CW-07 | CW-10 | CW-12 | CW-15 | CW-16 | CW-19 | CW-20 |
|---|---|---|---|---|---|---|---|---|---|---|
| instantiate | — | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ |
| UpdateRate | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| SetOracleOperator | ✓ | — | — | — | ✓ | ✓ | — | ✓ | ✓ | — |
| SetPaused | ✓ | — | — | — | ✓ | ✓ | — | ✓ | ✓ | — |
| ProposeGovernance | ✓ | — | — | — | ✓ | — | — | ✓ | ✓ | — |
| AcceptGovernance | ✓ (CW-06) | — | — | — | ✓ | — | — | ✓ | ✓ | — |
| migrate | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ |
| Config / State | — | — | — | — | ✓ | — | — | — | — | — |

### ust1-window

| Method | CW-01 | CW-02 | CW-03 | CW-04 | CW-05 | CW-08 | CW-10 | CW-11 | CW-12 | CW-13 | CW-14 | CW-17 | CW-19 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| instantiate (CW-18) | — | ✓ | ✓ | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — |
| Receive | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| SetLimits | ✓ | — | — | — | — | — | ✓ | — | — | ✓ | — | — | ✓ |
| SetPaused | ✓ | — | — | — | — | — | ✓ | — | ✓ | — | — | — | ✓ |
| SetFeeBps | ✓ | — | ✓ | — | — | — | ✓ | — | — | — | ✓ | — | ✓ |
| ProposeGovernance | ✓ | — | — | — | — | — | ✓ | — | — | — | — | — | ✓ |
| AcceptGovernance | ✓ (CW-06) | — | — | — | — | — | ✓ | — | — | — | — | — | ✓ |
| migrate | ✓ | ✓ | — | — | — | — | ✓ | — | — | — | — | — | — |

### ust1-oracle-service

All EVM-01 through EVM-20 apply to the single service lifecycle (BSC read → policy → Terra broadcast). No method-level breakdown needed.

---

## Next steps

1. Dev review of this checklist in cl8y-ecosystem-qa.
2. Once approved, open one issue per category on ust1-window (CW-01 through CW-20 + EVM-01 through EVM-20 where applicable) for structured verification.
3. Work through verification, document evidence per method, file findings as sub-issues.

