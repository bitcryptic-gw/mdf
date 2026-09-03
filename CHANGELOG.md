# Changelog
All notable changes to the MDF specification and reference implementation will be documented here.
This project adheres to [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions.

---

## [Unreleased]

### Added — spec
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
