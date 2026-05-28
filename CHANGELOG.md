# Changelog
All notable changes to the MDF specification and reference implementation will be documented here.
This project adheres to [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions.

---

## [Unreleased]

- On-chain x402 payment verification (stub → production) — blocked on trust model decision, see issue #3
- Lightning invoice verification for L402 (stub → production) — requires Lightning node availability
- Feed smoke tests for reference server
- Validator CLI enhancements — feed validation, WebSub hub reachability

### Added

- **CONCEPT.md — Human Presence Verification subsection** added to the Content Signals section.
  Covers passkeys (WebAuthn/FIDO2) as the recommended human-presence primitive for `human_only`
  content tiers, the proposed passkey-attested payment-and-token flow, the structural argument for
  why MDF's payment-upstream model eliminates the consumer-side fraud incentive present in
  per-stream royalty platforms, and two open questions for community input (direct vs delegated
  WebAuthn verification; section-level vs per-resource `human_only` granularity). Cross-references
  open questions 4 and 6.

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
