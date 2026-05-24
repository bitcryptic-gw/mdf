# Changelog

All notable changes to the MDF specification and reference implementation will be documented here.

This project adheres to [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions.

---

## [Unreleased]

- `mdf.schema.json` validator CLI tool
- MDF feed XML namespace definition (`xmlns:mdf`)

---

## [0.1.0-draft] - 2026-05-24

### Added
- CONCEPT.md — full architecture proposal and specification
- mdf.schema.json — JSON Schema (Draft 2020-12) for /mdf.json capability document, strict with additionalProperties: false throughout
- README.md — problem statement, architecture summary, status
- Reference implementation (mdf-reference-server) — Bun-based HTTP server implementing the full MDF architecture
  - Config loader with Zod validation and Docker secret resolution
  - RFC 7231 Accept header parsing and content negotiation
  - Markdown serving with dynamic HTML rendering via marked
  - Auto-generated /mdf.json and /llms.txt from mdf.yaml
  - x402 payment stub with structural validation and audit logging
  - Bearer token issuance and validation for auth-via-payment tier
  - Standard HTTP ETag and conditional GET support
  - Internal dashboard on separate port
- Live demo deployment at https://mdf-demo.bitcryptic.com
- Docker image and Compose configuration for self-hosted deployment
- 90 tests across all modules passing

### Status
Spec: v0.1.0-draft — published, seeking community feedback
Reference implementation: deployed and publicly accessible
Payment verification: stubbed — on-chain x402 verification is the next milestone

---

## [0.1.0-draft] — 2026-05-23

Initial public draft.

### Added
- `CONCEPT.md` — full proposal covering problem statement, existing partial solutions, MDF philosophy, architecture, payment spectrum, auth-via-payment model, content freshness and agent subscriptions (RSS/Atom + WebSub), content signals, open questions, and reference implementation plan
- `README.md` — project overview and status
- `mdf.schema.json` — JSON Schema (Draft 2020-12) for the `/mdf.json` capability document, covering pricing, payment, auth, content signals, format capabilities, feed/WebSub subscription configuration, and llms.txt linkage

### Authors
Gary Walker / BitCryptic™ · Graham Hall / Slepner
