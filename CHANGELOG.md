# Changelog
All notable changes to the MDF specification and reference implementation will be documented here.
This project adheres to [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions.

---

## [Unreleased]

### Added
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

### Changed
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
