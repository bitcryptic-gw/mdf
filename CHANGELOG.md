# Changelog
All notable changes to the MDF specification and reference implementation will be documented here.
This project adheres to [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions.

---

## [Unreleased]

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
