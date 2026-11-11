# Changelog
All notable changes to the MDF specification and reference implementation will be documented here.
This project adheres to [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions.

---

## [Unreleased]

## [0.3.1] - 2026-11-11 — **non-breaking**

A rail whose `scheme` is not `exact` can now be declared. The change only loosens the schemas: every 0.3.0-conformant document and 402 body is still conformant, and nothing 0.3.0 accepted is now rejected. Vikunja #68 (spec) and #69 (validator).

Written against the ProofLines case (`mdf-57-prooflines-mdf-json-draft-2026-11-11`): a real x402 v2 site selling a native-MON rail under its own scheme. Under 0.3.0 that rail was inexpressible — the eip155 branch forced `scheme: exact` and a `0x…` asset — so no conformant `/mdf.json` could describe what the site actually offered, and the one-to-one rule made the omission a divergence. Decision 26 resolves it.

### Changed — specification

- **The eip155 `asset` rule applies to `exact` only.** `mdf.schema.json#/$defs/price_rail`'s eip155 conditional now fires only when `network` matches `^eip155:` **and** `scheme` is `"exact"`; there it still requires a 0x address. The "eip155 forces `scheme: exact`" constraint is removed, so a non-`exact` scheme may name a rail on an eip155 network.
- **A non-`exact` scheme defines its own asset identifier.** For any scheme other than `exact`, `asset` is an opaque, bounded string (`^[A-Za-z0-9:._/-]{1,128}$`) that MDF does not interpret; for `exact` the previous forms are unchanged (a 0x address on eip155, `BTC` on lnbtc, or an uppercase symbol). No new field is added — `scheme` and `asset` are read together.
- **`mdf-402.schema.json` follows the same rule**, because an `accepts[]` entry is where a rail is first offered: its eip155 conditional and its base `asset` rule are scoped to `exact`, and so is the CAIP-2 `network` requirement. A non-`exact` entry may name its network with a bounded opaque identifier (`^[A-Za-z0-9:._/-]{1,64}$`) — the shape a real third-party 402 uses, e.g. ProofLines' `"monad-testnet"` plus `chainId` — while an `exact` entry still requires CAIP-2. `/mdf.json` continues to require CAIP-2 for every rail, and the alias normalisation in the one-to-one rule is 402-side only. `amount` stays an atomic integer string in both documents.
- **CONCEPT.md: the one-to-one rule compares `(scheme, network, asset, amount)`** on a normalised network. A 402 SHOULD use CAIP-2; a consumer MAY normalise an alias to CAIP-2 from a `chainId` field on the entry or from a known alias table. The subtraction-only divergence clause is unchanged — no new exception is introduced.
- **CONCEPT.md carries a short non-normative native-asset example**, and the Rails text now says a non-`exact` scheme defines its own asset identifier, carried in `/mdf.json` exactly as the 402 carries it.
- **#67, examples:** the fabricated `0x1111…` asset in CONCEPT.md's `/mdf.json` snippet and in `mdf.schema.json`'s embedded examples is replaced with the canonical Base mainnet USDC contract (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`, "USD Coin" v2), from upstream `defaultAssets.ts` at `513dd66` — the same table #66 used for the example files.

### Added — specification

- `examples/mdf-native-asset-rail.json` — the faithful two-rail ProofLines draft (USDC `exact` plus `monad-native-exact`/`native` on testnet and mainnet), schema-valid from this version. It is the worked example of decision 26.

## [0.3.0] - 2026-11-08 — **BREAKING**

The 402 becomes an x402 v2 `PaymentRequired`. There is no v1 acceptance window and no dual output: 0.3.0 is a hard cut. Validators SHOULD still read v1 on third-party sites, but an MDF 0.3.0 server neither emits nor accepts v1.

Drafted against `x402-foundation/x402` at commit `513dd66d2b3eb2388065f9923d81aa496e626082` (2026-11-06): `specs/x402-specification-v2.md` §5.1 and §5.1.2, `specs/transports-v2/http.md`, `specs/schemes/exact/scheme_exact_evm.md`, `specs/schemes/exact/scheme_exact_lnbtc.md`.

### Breaking — specification

- **The 402 body is an x402 v2 `PaymentRequired`.** `x402Version` is `2`; `resource` is an object; `accepts[]` carries one entry per rail; `extensions` carries MDF's fields. The same object MUST be carried base64-encoded in the `PAYMENT-REQUIRED` header, and body and header MUST agree field for field. 402s MUST be `Cache-Control: no-store` and MUST still carry `X-MDF-Version`. The "superset of x402 v1 `PaymentRequirements`" relationship is removed.
- **MDF's own fields move into `extensions.mdf`.** The extension entry uses the structure x402 v2 defines for every extension — `info` plus `schema` — with snake_case members inside `info`: `version` and `price_summary` (required, the latter derived from and required to agree with `accepts[]`), `expires_at` (SHOULD), and optional `source_bytes`, `savings`, `auth_endpoint`, `token_estimate` / `token_estimate_note`. The extension never restates `amount`, `payTo` or `network`.
- **CAIP-2 network ids replace chain names on the wire.** `base` → `eip155:8453`, `base_sepolia` → `eip155:84532`, `lightning` → `lnbtc:000000000019d6689c085ae165831e93`.
- **Amounts are atomic integer strings.** `"0.01" USDC` becomes `"10000"` micro-USDC; Lightning amounts are millisatoshis.
- **Lightning is x402 `exact` on `lnbtc`, not a bespoke L402 envelope.** One `accepts[]` entry, `asset: "BTC"`, `payTo` as the receiver's compressed secp256k1 public key, and `extra` carrying the invoice plus the scheme's request-binding fields. Invoice, binding and replay rules are the scheme spec's, not MDF's.
- **Multi-rail is `accepts[]`.** One entry per configured rail; a degraded rail drops only its own entry. If no rail can be offered, the response is an error with `Retry-After`, not a 402 with an empty `accepts`.
- **`PAYMENT-RESPONSE` is required on every paid 200, on every rail.** For `exact`/lnbtc, `transaction` is the invoice payment hash and `payer` is omitted. Paid 200s remain `Cache-Control: private, no-store`.
- **Client payments use `PAYMENT-SIGNATURE`.** `X-PAYMENT` is not accepted.
- **L402 is demoted to an optional compatibility challenge** (non-normative). A server MAY emit `WWW-Authenticate: L402` on Lightning-priced routes for BLIP-0026 clients; it is outside the x402 rules and does not affect `accepts[]`.
- **`/mdf.json` prices are per rail, and one key is renamed.** A price entry is now `{ "rails": [{ scheme, network, asset, amount }], "access": "per_fetch" | "token" }` — a list, one entry per rail, each with its own price in that rail's own units. `pricing.*.chain` is renamed `network`, because it now holds a CAIP-2 identifier. `pricing.*.currency` is gone; the asset is per rail.
- **`auth.price_threshold` is replaced by a per-section `access` flag.** `access: "token"` on a price entry means payment there issues a bearer token (named by `auth.endpoint`, lasting `auth.token_ttl_seconds`) instead of delivering content per fetch; `access: "per_fetch"` is the default. Token access is a publisher decision per section, and with per-rail prices and no exchange rate a price threshold cannot be evaluated. A `token` entry MUST have at least one rail.
- **The `/mdf.json` `payment` object is removed.** `payment.accepted_networks` and `payment.accepted_currencies` are the union of `pricing.rails`; `payment.wallet` is redundant with, and could contradict, `accepts[].payTo` in the live offer. A client derives a site's capability from the rails it declares. `payment.endpoint` folds into `auth.endpoint`, since credential issuance was the only flow that needed a separate location. A site priced entirely per fetch now needs no `payment` or `auth` block at all.
- **The root conditional is now about tokens, not prices.** "Any non-zero price requires `payment`" is gone. In its place: if any price entry has `access: "token"`, `auth.endpoint` is required.
- **No exchange rate.** Each rail's price is set by the publisher. There is no canonical price and no conversion between rails anywhere in the specification.
- **The 402 must agree with `/mdf.json`.** The `accepts[]` entries a server emits for a resource MUST correspond one-to-one to the rails declared for that resource's path, with identical scheme, network, asset and amount, minus any rail that is degraded.
- **`expires_at` is optional (SHOULD).** `maxTimeoutSeconds`, and on the lnbtc rail the BOLT11 invoice expiry that must equal it, already bound when an offer can be paid.
- **`X-MDF-Version` stays `1`.** It marks the protocol family; the precise spec version is `extensions.mdf.version` and `mdf_version`, and a 402 identifies its payment version through `x402Version: 2`.
- **Examples correction, no version bump.** Two fixes to the examples, both from the upstream asset table (`defaultAssets.ts` at x402 `513dd66`): (1) the mainnet examples (`eip155:8453`) set `extra.name` to `"USD Coin"`, the token's EIP-712 domain name on Base mainnet, instead of `"USDC"` — Base Sepolia keeps `"USDC"`; a wrong name is not cosmetic, because EIP-3009 signatures are bound to the EIP-712 domain, so they fail verification. (2) the examples now use the real public USDC contract addresses (`0x8335…2913` on `eip155:8453`, `0x036C…CF7e` on `eip155:84532`) instead of fabricated ones, so a copy of an example is verifiable rather than merely illustrative. Every other identifier in the examples stays obviously fake and labelled as such. No spec text, schema or version change.

### Added — specification

- `mdf-402.schema.json` is rewritten for the v2 shape: `x402Version` pinned to `2`, CAIP-2 pattern on `network`, `amount` as an atomic integer string, `resource` as an object, conditionals for the two defined rails, and `$defs.mdfExtension` / `$defs.mdfExtensionInfo` for the extension.
- `mdf.schema.json`: per-rail pricing (`pricing.*.rails`), the `chain`→`network` rename, the per-section `access` flag, the removal of the `payment` object, the token-requires-`auth.endpoint` root conditional, and a `mdf_version` pattern that accepts a patch component.
- `examples/` — a USDC-only 402, a dual-rail 402, a dual-rail `/mdf.json` whose `/micropayment/*` rails match that 402 entry for entry, a token-tier `/mdf.json`, and a paid 200 `PAYMENT-RESPONSE` for each rail, with the validation procedure and recorded output.

### Unchanged

- Negotiation, `mdf.json`, `llms.txt` discovery, tiers, content signals, feeds and the auth-token concept.
- `X-MDF-Version` keeps its value (`1`): it identifies the MDF protocol family, not this specification's release number. The precise spec version is `extensions.mdf.version` and `mdf_version`, and a 402 identifies its payment version through `x402Version: 2`.
- The reference server, validator, WordPress plugin and deployments are out of scope for this release; they follow in #64, #58–#60.

### Open questions carried by this release

None. The two raised by per-rail pricing (`auth.price_threshold`, `accepted_*` redundancy) are resolved by the `access` flag and by removing the derivable fields. One implementation question is open in the PR only — whether folding `payment.endpoint` into `auth.endpoint` is right — and it is a confirmation, not a design gap: the branch implements the fold.

### Migrating from 0.2.x

| 0.2.x | 0.3.0 |
|---|---|
| `payment` object | one `accepts[]` entry per rail |
| `payment.chain: "base"` | `accepts[].network: "eip155:8453"` |
| `payment.chain: "base_sepolia"` | `accepts[].network: "eip155:84532"` |
| `payment.chain: "lightning"` | `accepts[].network: "lnbtc:000000000019d6689c085ae165831e93"` |
| `payment.amount: "0.01"` (decimal) | `accepts[].amount: "10000"` (atomic integer) |
| `payment.currency: "USDC"` | `accepts[].asset: "<USDC contract on that network>"` |
| `payment.pay_to` | `accepts[].payTo` |
| `payment.scheme: "exact"` | `accepts[].scheme: "exact"` |
| `payment.max_timeout_seconds` | `accepts[].maxTimeoutSeconds` |
| `payment.extra` | `accepts[].extra` |
| `payment.rail` | removed — the network identifies the rail |
| `payment.accepted_chains` (402) | removed; the offer is `accepts[]` alone |
| `payment.session_nonce` | removed |
| `payment.expires_at` | `extensions.mdf.info.expires_at` (now SHOULD, not required) |
| `payment.invoice` (L402) | `accepts[].extra.invoice` (on the `lnbtc` entry) |
| `payment.macaroon` (L402) | only on the optional L402 compatibility path |
| `resource: "https://…"` (string) | `resource: { "url": "https://…" }` |
| `source_bytes` | `extensions.mdf.info.source_bytes` |
| `savings` | `extensions.mdf.info.savings` |
| `auth_endpoint` | `extensions.mdf.info.auth_endpoint` |
| `error` + `reason` | `error` (one human-readable string; the short machine label is gone) |
| `mdf_version` (body) | `extensions.mdf.info.version` |
| `X-PAYMENT` (client) | `PAYMENT-SIGNATURE` |
| — | `PAYMENT-REQUIRED` (server, base64 of the same body) |

Changed, renamed or removed in `/mdf.json`:

| 0.2.x | 0.3.0 |
|---|---|
| `pricing.*.chain` | `pricing.*.rails[].network` |
| `pricing.*.currency` | `pricing.*.rails[].asset` |
| `pricing.*.amount` (decimal) | `pricing.*.rails[].amount` (atomic integer) |
| `auth.price_threshold` | per-section `access: "token"` on the price entry |
| `payment.accepted_chains` | removed — derive from the union of `pricing.rails` |
| `payment.accepted_currencies` | removed — same |
| `payment.wallet` | removed — the authoritative recipient is `accepts[].payTo` in the 402 |
| `payment.endpoint` | `auth.endpoint` (proposed; see the 0.3.0 draft PR) |
| `payment` (object) | removed — only the token flow needed any of it, and that is `auth` |

A price entry is now a list of rails rather than a single price, so a section that was `{ "amount": "0.0001", "currency": "USDC", "chain": "base" }` becomes `{ "rails": [{ "scheme": "exact", "network": "eip155:8453", "asset": "<USDC contract>", "amount": "100" }] }`. An unpriced section is `{ "rails": [] }`. Add `"access": "token"` to a priced entry to issue a bearer token instead of delivering per fetch, and declare `auth.endpoint` when any entry does. There is no exchange rate: each rail's amount is the publisher's own price in that rail's units.

Related: the schemas' `mdf_version` pattern now also accepts a three-component version, so a document can declare `0.3.0`; the previous pattern accepted only `MAJOR.MINOR`.

## [0.2.9] - 2026-11-11 — **security**

Server-only release. No spec change; `VERSION` stays `0.3.1`. Fixes the token-tier payment bypass found during #64 Stage A.

### Fixed — reference server

- **`POST /mdf/auth` issued a bearer token with no payment at all (security).** Since the endpoint was introduced, `handleAuthRequest()` minted a 24-hour token for **any** path supplied in the request body, without verifying a payment. `/mdf.json` publishes that endpoint as `auth.endpoint`, so the token-gated tier (`/private/**`, 0.10 USDC, **Base mainnet, real money**) was free to anyone who read `/mdf.json`: mint a token for the section, then present it as `Authorization: Bearer`. The endpoint now issues a token **only** after a valid payment for the token-access section in the same request. `<auth.endpoint>` and `/mdf/pay` share one handler that requires `X-PAYMENT`, runs the ordinary `verifyPayment()` → facilitator `/verify` → `/settle` path (including the #52 replay hardening, unchanged), and refuses a token for a path that is not a token-access section, before any facilitator call. The token's scope is derived from the paid path, so it authorises exactly that section. The payer and transaction recorded against the token now come from the verified settlement, never from the request body; `txHash`/`from` sent by a client are ignored. `handleAuthRequest()` is removed, so no other route can mint. Bad, missing or replayed payment → `402` with the normal offer and no token; facilitator failure → `503` and no token. Token comparison remains timing-safe (`timingSafeEqual`); nothing about issuance, scope or TTL semantics changed otherwise.

### Changed — reference server

- **Token issuance is limited to token-access sections.** A payment presented to a token endpoint for a per-fetch section is refused with `400` and is never sent to the facilitator, so the endpoint cannot be used as a general-purpose pay relay.
- **Known limitation, deferred to 0.3.0 (#64): the token store is per-process.** Behind a round-robin pool (the demo runs two instances) a token may only be accepted by the instance that issued it, and a restart drops all tokens. Unchanged by this release and stated here so it is not mistaken for a regression; the 0.3.0 rewrite moves the store to shared storage.

### Added — reference server

- **`src/auth/auth-pay.test.ts`** (13 tests): unpaid `POST /mdf/auth` → `402` with the normal offer and no token; unpaid `/mdf/pay` likewise; `GET` → `405`; a paid request mints a token scoped to the paid section and serves it end to end; a token does **not** authorise another token section (both `validateToken` and a live `402` through the router); a replayed (already-settled) payment → `402`, no token, never reaching `/settle`; a facilitator failure → `503`, no token; a per-fetch section → `400` with no facilitator call; missing `resource` → `400`; an oversized body → `413`; a client-asserted `txHash`/`from` is ignored in favour of the verified settlement; wrong or malformed token secrets are rejected. Shown to fail against the 0.2.8 code (8 of 13) before the fix. Server-only; no spec change, `VERSION` unchanged.

## [0.2.8] - 2026-10-02

Server-only release. No spec change; `VERSION` stays `0.2.0`. Vikunja #52.

### Fixed — reference server
- **The x402 `/verify` on-chain settlement fallback is removed (security).** When the facilitator's `/verify` did not return `isValid: true`, `verifyPayment()` called `confirmSettlementOnChain()` and approved the request if the authorization's `(from, nonce)` had settled on-chain — without re-checking `validBefore`, the amount against the current offer, or the resource. Because `transferWithAuthorization` calldata is public, anyone could rebuild an `X-PAYMENT` from any settled payment to the site's `pay_to` and replay it indefinitely to unlock that route (observed live on Base Sepolia, 2026-10-02). A `/verify` that rejects a payment now returns `402` with a fresh offer and never approves on the strength of a prior settlement. The accepted trade-off is that a client that loses a *successful* response must pay again. Server-only fix; no spec change, `VERSION` unchanged. Vikunja #52.

### Changed — reference server
- **`/verify` outcomes are classified as `valid | invalid | error`.** A structured `{"isValid":false}` body is a payment denial → `402`, whatever the HTTP status — x402-rs answers a used nonce and an invalid signature with HTTP 500 but still carries the verdict, while an expired or under-paid authorization arrives as HTTP 400. A response with no structured verdict (unreachable, timeout, unparseable, or a non-200 without `isValid:false`) is a facilitator-side failure → the existing `503`. This makes a used or expired nonce always `402`, never a `5xx` or a `200`.
- **The `/settle`-error on-chain recovery is retained, but bound to the verified authorization.** The only remaining on-chain approval runs on a `/settle` error after `/verify` returned `valid` in the same request, and checks the exact `(from, nonce)` `/verify` accepted (passed as a typed value, not re-read from the request). A `/settle` error that is not recovered on-chain is a facilitator-side failure → `503`, not a payment rejection. The accepted trade-off therefore covers only a lost *client* response; a lost *facilitator* `/settle` response is still recovered within the same request. Residual risk noted: a settle transaction visible in the mempool could in principle be replayed before it is mined — Base's sequencer mempool is not public, so this was not observed.

### Added — reference server
- **`src/payment/x402-verify.test.ts`** (14 tests): used / expired / under-amount / wrong-recipient / bad-signature → `402` with no `/settle` and no on-chain lookup; an unstructured `500` and a transport failure → `503`; the happy path (`verify` ok → `settle` ok → `200`); the `/settle`-error recovery using the verified `(from, nonce)` (with a calldata assertion); `/settle` error not recovered on-chain → `503`; on-chain lookup failure → `503`; and the approval invariant that the on-chain check is unreachable unless `/verify` succeeded. Server-only; no spec change, `VERSION` unchanged. Vikunja #52.

## [0.2.7] - 2026-09-21

Server-only release. No spec change; `VERSION` stays `0.2.0`. Vikunja #43, #44.

### Fixed — reference server
- **The L402 fail-open is closed.** `verifyL402()` returned `stub_approved` — approval on a structural check alone, with no verification — whenever no `[lightning]` block was configured. A minimal or misconfigured deployment that priced a route on `chain: lightning` but omitted `[lightning]` therefore served that route to any well-formed-looking `L402` header. The loader now **refuses to start** if any non-zero-priced route is `chain: lightning` and no `[lightning]` block is configured, naming the offending section and printing no secret material; the `stub_approved` status and the router branches that consumed it are removed, so the runtime path fails closed (the L402 branch rejects when lightning is not configured). A `[lightning]` block whose secrets cannot be resolved still fails startup exactly as before. Server-only fix.
- **A BTC-denominated lightning price is no longer read at the USD rate.** `usdToSats()` applied the fixed 1000 sats/USD reference rate to every price, including BTC. A BTC price is now converted at 1 BTC = 100,000,000 sats, and USD/USDC prices keep the fixed rate. Any other currency on the lightning rail is an explicit **load-time rejection**, not a silent misread. `/micropayment/**` (0.00000001 BTC) is unchanged at 1 sat; `0.000001` BTC now correctly yields 100 sat (previously 1, a 100x undercharge). Server-only fix.

### Changed — reference server
- **An L402 challenge is attached only to offers on the lightning rail.** `build402Response()` previously attached a `WWW-Authenticate: L402` header and a Bitcoin invoice to *every* 402 whenever `[lightning]` was configured — including x402/USDC-only offers, which advertise USDC only. Advertised rails now match what the response can fulfil, and an x402 offer no longer burns an Alby invoice per 402. This is a deliberate single-rail-per-route position for now; offering every configured rail for every priced resource is future work. Server-only change.

### Added — reference server
- **A structured failure surface for lightning invoicing, backend-agnostic.** When invoice creation fails, `createL402Challenge()` now returns a typed failure with a category (`rejected` | `auth` | `unreachable` | `unknown`), the upstream HTTP status (if any) and a sanitised, truncated upstream message — retained for the structured log only. A circuit breaker (in-memory, per-process) opens on failure, stops calling the backend on every subsequent 402, and retries on a timer with exponential backoff, a cap and jitter, so a transient fault recovers with no inbound traffic (one probe in flight at a time; timers cleared on shutdown). Tunables `lightning.breaker_initial_backoff_seconds` (default 5) and `lightning.breaker_max_backoff_seconds` (default 300) are config-driven and validated; defaults mean no `mdf.yaml` change is required.
- **`/health` gains an optional `lightning` block** — `{ "status": "degraded", "since", "category", "next_retry" }` (coarse category and timestamps only; never the upstream message) — while the top-level `status` stays `"ok"` and the HTTP code stays `200`, since x402 and free routes are unaffected and a non-200 would pull the instance out of a Caddy/Docker pool. Healthy responses are unchanged and carry no `lightning` block.
- **A degraded lightning-only route returns `503` with `Retry-After`** (rather than a 402 advertising a rail that cannot be fulfilled). A 402/503 that would have offered lightning carries `payment.lightning_unavailable: true` plus the coarse category. This is a server-emitted, optional field; the vendored `mdf-402.schema.json` permits it (`additionalProperties: true`), so no schema change is required.

## [0.2.6] - 2026-09-20

### Fixed — reference server
- **Lightning invoices were issued 1000x too small, and the sub-satoshi demo tier was unpayable.** Alby Hub's invoice API takes `amount` in millisatoshis, but the server passed its satoshi value through unchanged: `/premium` (1.0000 USDC) was invoiced as 1 sat instead of 1000, and `/micropayment` (0.00000001 BTC = 1 sat) asked Alby for 1 msat = 0.001 sat, which Alby rejected with HTTP 500 — so the L402 route returned a 402 with no challenge at all. `usdToSats()` now returns the exact (possibly fractional) satoshi value and a new `satsToMsat()` rounds up to a whole satoshi (1-sat floor) and converts to millisatoshis, so the invoice matches the advertised amount and the publisher is never under-charged. Server-only fix; no spec change, `VERSION` unchanged. Vikunja #34.
- **L402 macaroon path scope over-matched.** `verifyL402()` used a bare string prefix, so a credential scoped to `/premium` also authorised `/premiumx/…` and `/premium-other/…`. It now requires a path-segment boundary. Server-only fix; no spec change, `VERSION` unchanged. Vikunja #42.
- **Settled-record preimage comparison is now constant-time** (`crypto.timingSafeEqual`); the macaroon HMAC and preimage-hash comparisons already were. Server-only hardening; no spec change, `VERSION` unchanged. Vikunja #42.

### Changed — reference server
- **Negotiated content now sends `Vary: Accept` and uses per-representation ETags.** Previously no `Vary` was sent and markdown and HTML shared one ETag derived from the raw markdown source, so a shared cache could revalidate one representation against the other's ETag and receive a 304. Free 200s, 304s, paid 200s and negotiated 404s now declare `Vary: Accept`, and each representation's ETag is derived from the bytes actually served. Free `no-cache` behaviour, paid `private, no-store`, and `x-mdf-source-bytes` are unchanged. Server-only change; no spec change, `VERSION` unchanged. Vikunja #41.

### Added — reference server
- **Test coverage for the L402 rail.** `src/payment/l402-verify.test.ts` exercises `verifyL402()` (macaroon HMAC, scope, preimage, Alby settlement) with a mocked Alby, and `src/payment/l402-invoice.test.ts` covers the invoice unit conversion. The prior absence of any L402 verifier test is how the 0.2.5 stub bypass survived. Server-only; no spec change, `VERSION` unchanged. Vikunja #34, #42.

## [0.2.5] - 2026-09-20

### Fixed — reference server
- **Paid 200 responses are explicitly uncacheable, and a paywall bypass on the L402 routes is closed.** `verifyPayment()` approved any lightning-priced (L402) path *before* inspecting the `X-PAYMENT` header, so any non-empty `X-PAYMENT` value won a paid 200 — and, with a matching `If-None-Match`, a 304 — without payment. It now rejects, so such a request receives a proper 402 L402 challenge. A paid 200 now carries `Cache-Control: private, no-store` with no `ETag`/`Last-Modified` and is never answered from a conditional request; free 200s keep `no-cache` with validators, unchanged. Server-only fix; no spec change, `VERSION` unchanged. Vikunja #40.

### Added — reference server
- **`Cache-Control: no-store` on every 402 and every payment-failure response.** Set in the single 402 builder (both payment rails, every priced route, both `Accept` variants) as well as the payment-failure and `/mdf/pay` token responses, so an L402 invoice or x402 offer cannot be stored and replayed by a shared cache. Regression coverage added to the handler and router suites. Server-only change; no spec change, `VERSION` unchanged. Vikunja #40.
- **Bun toolchain pinned.** The Docker base image moves from the floating `oven/bun:1-alpine` (which had resolved to Bun 1.4.2 against a 1.3.14 host toolchain) to `oven/bun:1.3.14-alpine` by explicit tag and multi-arch manifest-list digest, and the `bun-types` devDependency is pinned to `1.3.14` to match. Server-only change; no spec change, `VERSION` unchanged. Vikunja #33.

## [0.2.4] - 2026-09-19

### Added — reference server
- **`payment.wallet` is now validated as a strict EIP-55 checksummed address** whenever any pricing is non-zero. The resolved wallet (after `/run/secrets/wallet_address` / `MDF_WALLET` resolution) must be exactly its own EIP-55 checksum form: `0x` + 40 hex digits, mixed-case matching its keccak-256 checksum, and not the zero address. All-lowercase, all-uppercase, wrong-length, missing-`0x`, non-hex, and zero-address values refuse startup with a descriptive error naming the field (never echoing more than the first 6 characters); a malformed wallet on an entirely free site logs a single warning instead. Uses the audited, zero-dependency `@noble/hashes` for keccak-256 (no viem/ethers) and adds a config-loader regression suite. Server-only change; no spec change, `VERSION` unchanged. Vikunja #9.

### Changed — reference server
- **Dependencies refreshed:** `js-yaml` `4.1.1 → 4.3.2` and `marked` `18.0.5 → 18.0.13`, clearing all `bun audit` advisories (including the four `js-yaml` quadratic-CPU/merge-key DoS advisories); the transitive `gray-matter › js-yaml` is pinned to `3.15.2` via a scoped override. `x-mdf-source-bytes` verified byte-identical for every free content page before/after (`/` = 1241, `/docs/getting-started` = 1003). Server-only change; no spec change, `VERSION` unchanged. Vikunja #16.
- **`[lightning].api_token` and `[lightning].token_secret` are now optional** in the config schema. They remain inert when present (never read or logged); the loader's secret-file/env resolution is the single source of truth and still refuses startup when a `[lightning]` block is configured but neither source resolves. Existing `mdf.yaml` files carrying inline placeholders continue to parse. Server-only change; no spec change, `VERSION` unchanged. Vikunja #27.

## [0.2.3] - 2026-09-18

### Added — reference server
- `/health` now returns a small JSON body `{ "status": "ok" | "unavailable", "version": "<release>" }` instead of the plain-text `OK`/`UNAVAILABLE`, exposing the server's **release** version distinct from the MDF **protocol** version (`mdf_version` / `X-MDF-Version`). The version is read once from `package.json` at startup and cached. HTTP 200/503 semantics are unchanged, and no monitoring config depends on the body (Caddy `health_uri` and the Docker `HEALTHCHECK` are status-only), so this is additive. Regression test `src/health.test.ts` pins the field to `package.json`. Server-only change; no spec change, `VERSION` unchanged. Vikunja #31.

## [0.2.2] - 2026-09-18

### Fixed — reference server
- Requests to a path with no content under a non-zero-priced section now return `404`, not a `402` payment offer. The router verified payment before resolving the requested resource, so the pricing default (0.0001 USDC on the demo) was advertised as a payable resource for any unknown path; only unknown paths under a `$0` section reached the content handler's real `404`. The request router is extracted into `src/router.ts` and gained a single content-existence gate before payment verification, so the 200 and 402 paths share one resolver. Regression suite `src/router.test.ts`. Server-only fix; no spec change, `VERSION` unchanged. Vikunja #29.

## [0.2.1] - 2026-09-16

### Changed — reference server
- `source_bytes` on both the 200 header (`X-MDF-Source-Bytes`) and the 402 body now reflects the rendered-HTML byte count as specified (CONCEPT.md §253, commit `648562c`), rather than the served-markdown / on-disk markdown file size it had drifted to. Server-only fix; no spec change, `VERSION` unchanged.

## [0.2.0] - 2026-09-12

### Added — spec
- **`mdf-402.schema.json` — the x402 payment offer is now a strict superset of x402's `PaymentRequirements`.** Adds `pay_to`, `asset`, `scheme`, `max_timeout_seconds` and `extra` to the `payment` object, conditionally required when `rail: "x402"` via `allOf`/`if`/`then`, so a standard x402 facilitator's `/verify` and `/settle` endpoints can be called on these fields without a translation layer. `l402` and `mpp` offers are unaffected. Accompanied by a new CONCEPT.md "Facilitator Configuration" subsection, an x402-delegation rewrite of the Authentication via Payment flow, and open question 2 narrowed to L402 only (not renumbered).
- **CONCEPT.md — Human Presence Verification subsection** added to the Content Signals section.
  Covers passkeys (WebAuthn/FIDO2) as the recommended human-presence primitive for `human_only`
  content tiers, the proposed passkey-attested payment-and-token flow, the structural argument for
  why MDF's payment-upstream model eliminates the consumer-side fraud incentive present in
  per-stream royalty platforms, and two open questions for community input (direct vs delegated
  WebAuthn verification; section-level vs per-resource `human_only` granularity). Cross-references
  open questions 4 and 6.

- **CONCEPT.md — `/mdf.json` scope clarification** added to the Discovery section. Codifies the
  capability-not-coverage principle: `/mdf.json` declares that a site supports markdown negotiation
  and describes the payment mechanism (accepted rails, payment endpoint), but does not state which
  specific URLs have markdown available, what fraction of the site is covered, or what any individual
  resource costs. Coverage and per-URL price are discovered at request time via the actual response
  (200, 402, or HTML fallthrough). This avoids requiring continuous rewrites of a static document to
  track dynamic per-resource state, and aligns with how x402/L402 already use the 402 response as
  the price-discovery mechanism.

- **CONCEPT.md — Open Question #9** (broker/alternate content URL extension) added to the Open
  Questions section. Whether `/mdf.json` should support declaring an alternate host for third-party
  markdown serving, and if so how content integrity is verified (pre-declared pubkey with attested
  signing vs content-hash pinning). The extension has not been built.

- Response Value Signalling: optional `savings` object in 402 (and optionally 200) markdown responses, reporting byte-size reduction between source HTML and served markdown, giving agents a concrete efficiency signal alongside price.
- Response Value Signalling refinement: decoupled `source_bytes` as a standalone, conversion-independent size signal from the `savings` object, which remains specific to servers that perform markdown conversion.

- **`MCP-GATEWAY.md`** — concept document for an MDF reference client: an MCP gateway providing
  discovery, negotiation, 402 evaluation and budgeted payment for MCP-capable agent runtimes.
  Covers the token-arbitrage pay decision built on `source_bytes`, a signed and mirrorable index
  treated as an optional accelerator rather than a dependency, signer-sidecar payment key custody,
  and the argument that the first thing worth testing is whether agents will select an MDF-aware
  fetch tool at all. Concept stage; nothing built. Acknowledges 402index.io as prior art for the
  discovery layer.

- **`mdf-402.schema.json`** — JSON Schema (Draft 2020-12) for the `402 Payment Required` response
  body, plus a corresponding **CONCEPT.md "The 402 Response Body" subsection**. Previously the 402
  shape was described in prose only, which was tenable while MDF was supply-side but is not once a
  consumer may spend money on the basis of it. Describes server output; does not constrain
  consumers. Notable choices: decimal amounts as strings rather than JSON numbers, bounded numeric
  fields throughout, a closed `payment.rail` enumeration, and a SHOULD that payment endpoints be
  same-origin with the priced resource.

- **CONCEPT.md — Open Question #10** (client conformance and tool selection). Whether MDF should
  define a normative client profile at all. Records the position that a conformance profile authored
  by the party shipping the only client is how a community proposal becomes a vendor specification,
  and the empirical unknown beneath it — whether agent runtimes will select an MDF-aware fetch tool
  over their built-in fetch. Deliberately unresolved.

- **CONCEPT.md — Open Question #11** (spend policy scope). Explicit statement that budgets, caps,
  rate limits, human confirmation thresholds and payment key custody are implementation and
  deployment concerns, not specification concerns, so that the reference client's design is not read
  as a specification extension.

- **CONCEPT.md — "The compensation problem" subsection**, promoted from a single sentence
  previously buried as a "secondary problem". Argues creator compensation as a leg of the proposal
  independent of efficiency: it applies to every page regardless of how well that page converts, and
  does not depend on markdown being smaller than HTML. Frames payment as an alternative to
  enclosure — stay open and discoverable and be paid at the point of machine consumption, rather
  than retreating behind a login and leaving the open web.

### Changed — spec
- **CONCEPT.md — efficiency claim rescoped.** The Problem section previously asserted a flat 5–10×
  token overhead. That holds for agents feeding raw HTML into context, but most agent runtimes
  already perform client-side HTML-to-markdown extraction, against which the saving is
  content-dependent: substantial on boilerplate-heavy pages, substantial-but-different on
  JS-rendered or table-dense pages where extraction fails silently, and near zero on already-clean
  documentation. Reframes the universal benefit as determinism rather than compression. README
  updated to match, including the micropayment row of the price table.

- **CONCEPT.md — Response Value Signalling prohibition narrowed to servers.** The rule that
  `source_bytes` and `savings` "must not be used to influence or justify price" now states
  explicitly that it binds servers only. Consuming these fields to judge whether a price is worth
  paying is their intended use, and the previous wording could be read as forbidding it.

- **CONCEPT.md — Open Question #3** (rate limiting) cross-references client-side per-origin rate
  caps as covering the compliant-agent case without a spec mechanism, narrowing the spec question.

- **CONCEPT.md — Open Question #4** (update gaming) gains a paragraph on client-ledger churn
  measurement: per-origin re-fetch frequency against payment frequency as a detection mechanism
  requiring no origin cooperation and no spec mechanism. Argues against over-engineering the
  spec-side mitigation before field data exists.

- **CONCEPT.md — `X-MDF-Tokens` removed** from the Content Serving example and replaced with
  `X-MDF-Source-Bytes`. The header presented an authoritative token count, contradicting the
  Response Value Signalling rule that token counts are tokenizer-dependent and cannot be
  authoritative for an arbitrary requesting agent.

- **CONCEPT.md — "Reference Implementation" pluralised** to "Reference Implementations", with a
  paragraph on the client at concept stage, and a new "What MDF Is Not" entry stating that MDF does
  not depend on any particular client.

- **`mdf-402.schema.json` corrected against emitted output.** The schema as first added described an
  assumed 402 shape rather than the shape the reference server emits, and the live demo body failed
  validation against it. Rewritten from the observed response: the invented top-level `price` object
  removed in favour of the implemented `payment.amount` / `.currency` / `.chain`; root `required`
  reduced to `payment` alone; `mdf_version` made optional and documented as header-borne
  (`x-mdf-version`) with the version pattern loosened to accept a bare major; `payment.rail` demoted
  from required to optional with chain-inference documented as the current fallback; `nonce` renamed
  `session_nonce`; and `error`, `reason`, `accepted_chains` and `accepted_currencies` schematised
  rather than passing silently through open `additionalProperties`. `resource` and
  `payment.expires_at` are retained as optional and marked not-yet-emitted, with rationale in
  CONCEPT.md. The schema description now notes that `format` is annotation-only in Draft 2020-12
  absent a registered format plugin, and that the paired `pattern` is the load-bearing constraint.

- **CONCEPT.md — "The 402 Response Body" subsection corrected** to match. Adds a note that the
  `payment` object mixes resource-scoped offer fields with site-scoped capability fields, and that
  `accepted_chains` must not be read as rails available for the resource at hand.

- **`mdf-402.schema.json` and CONCEPT.md updated to reflect the deployed implementation.** The
  `resource`, `payment.rail` and `payment.expires_at` field descriptions no longer state that the
  reference server does not emit them, and the CONCEPT.md paragraphs on rail inference and
  not-yet-implemented fields have been rewritten accordingly. `payment.rail` remains optional in the
  schema: emitting it is encouraged, not required, since chain-to-rail inference remains workable for
  servers that do not. `mdf_version` is unchanged and is still carried as the `x-mdf-version` header
  rather than a body field.

### Added — reference server

- **402 response body completeness.** `build402Response` now emits three additional fields, all
  strictly additive — every previously emitted field retains its name, type and value.
  - `resource` — absolute request URL including query string, falling back to `site.url` plus path.
    The only field in a 402 a consumer cannot reconstruct once the response is held out of band.
  - `payment.expires_at` — RFC 3339, derived from the same `nonceExpiryMs` the `session_nonce` is
    already bound to (~3600 s as configured). Surfaces an existing validity window rather than
    introducing a new one.
  - `payment.rail` — via a new `railForChain()` mirroring verifier selection, so the declared rail
    cannot drift from the branch that actually verifies the payment. `base`/`ethereum` to `x402`,
    `lightning` to `l402`.

### Changed — reference server
- L402 payment verification: replaced stub with production implementation
  - Alby Hub REST API client for invoice creation and settlement verification
  - HMAC-bound macaroon signing with path scope, expiry, and nonce
  - Preimage verification: SHA-256 hash check + Alby Hub settlement confirmation
  - Invoice lookup via `/api/transactions` endpoint (Alby Hub experimental API)
  - End-to-end tested 2026-05-30 with real Lightning sats (Olympus by ZEUS LSP, LDK backend)
- New Docker secrets: `alby_api_token`, `lightning_token_secret` (alongside existing `wallet_address`)
- `mdf.yaml` lightning block: `api_url`, `invoice_expiry_seconds`, `api_token`, `token_secret`
- `src/config/schema.ts`: added `LightningSchema` and `lightning` field on `MdfConfigSchema`
- `src/config/loader.ts`: lightning secret resolution block
- `src/index.ts`: L402 branch before x402 in payment handler; `build402Response` awaited
- Docker image now built multi-arch (linux/amd64 + linux/arm64) via `docker buildx`


---

## [0.1.0-draft] — 2026-05-23 / updated 2026-05-28

### Added — 2026-05-28
- Reference implementation published to GitHub (`bitcryptic-gw/mdf-reference-server`) and Docker Hub (`bitcryptic/mdf-server:latest`)
- Feed XML namespace confirmed: `xmlns:mdf="https://github.com/bitcryptic-gw/mdf/ns/1.0"`
- Atom 1.0 feed at `/feed.xml` with `<mdf:change_type>` per entry, WebSub hub link, and persistent NDJSON event log — live at `https://mdf-demo.bitcryptic.com/feed.xml`
- Validator CLI published to GitHub (`bitcryptic-gw/mdf-validator`) — validates `/mdf.json` schema compliance and MDF response headers; 6/6 checks passing against live demo
- GitHub issue #3 opened: x402 receipt verification trust model — seeking community input

### Added — 2026-05-23
- `CONCEPT.md` — full proposal covering problem statement, existing partial solutions, MDF philosophy, architecture, payment spectrum, auth-via-payment model, content freshness and agent subscriptions (RSS/Atom + WebSub), content signals, open questions, and reference implementation plan
- `README.md` — project overview and status
- `mdf.schema.json` — JSON Schema (Draft 2020-12) for the `/mdf.json` capability document, covering pricing, payment, auth, content signals, format capabilities, feed/WebSub subscription configuration, and llms.txt linkage
- x402 payment verification stub (EVM/stablecoin rail)
- L402 payment verification stub (Bitcoin/Lightning rail)
- Demo site live at `https://mdf-demo.bitcryptic.com`

### Authors
Gary Walker / BitCryptic™ · Graham Hall / Slepner
