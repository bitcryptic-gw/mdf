# MDF — Markdown First

> A proposal for a web content architecture where markdown is the source of truth, agents are first-class citizens, and access policy is expressed through price.

**Status:** Draft · Seeking community feedback  
**Authors:** Gary Walker / [BitCryptic™](https://bitcryptic.com) · Graham Hall / [Slepner](https://slepner.com.au)

---

## The problem in one paragraph

AI agents are now among the most frequent consumers of web content, yet the web serves them HTML — a format built for human eyes. Agents must strip navigation, ads, scripts, and layout markup to reach the content underneath, wasting 5–10× the tokens actually needed. MDF proposes a simple, open architecture to fix this: markdown as the canonical source, HTTP content negotiation for delivery, and an optional payment layer that doubles as access policy.

## What MDF proposes

- **Markdown-first authoring** — markdown is the source of truth; HTML is rendered from it for browsers, not the other way around
- **Native agent serving** — `Accept: text/markdown` returns clean markdown at the same URL, no conversion middleware required
- **Structured discovery** — `/mdf.json` advertises capabilities, pricing, and content signals in a machine-readable format that agents can query before fetching
- **Price as access policy** — a single price field unifies open access, micropayment, and private/authenticated access into one continuous spectrum, using the x402 (EVM/stablecoin) and L402 (Bitcoin/Lightning) payment standards

## How the price spectrum works

| Price | What it means |
|-------|--------------|
| `$0.00` | Open — serve immediately, no payment required |
| `$0.0001` | Micropayment — small per-fetch fee offsets creator costs; cheaper for AI operators than fetching and parsing HTML |
| `$1.00+` | Premium — meaningful payment for gated content |
| `$100.00+` | Private — payment triggers an auth token issuance rather than immediate delivery |

## Read the full proposal

→ [CONCEPT.md](./CONCEPT.md)

The concept document covers the full architecture, existing partial solutions, open questions, and the reference implementation plan.

## Current status

- [x] Concept document published
- [x] `mdf.schema.json` — JSON Schema for `/mdf.json`
- [x] Reference implementation — `bitcryptic/mdf-server` on Docker Hub (`bitcryptic-gw/mdf-reference-server`)
- [x] Demo site — https://mdf-demo.bitcryptic.com — live end-to-end demonstration of all three payment tiers
- [x] x402 payment verification stub (EVM/stablecoin rail)
- [x] L402 payment verification stub (Bitcoin/Lightning rail)
- [x] Atom feed with `mdf:change_type` namespace — live at https://mdf-demo.bitcryptic.com/feed.xml
- [x] Validator CLI — `bitcryptic-gw/mdf-validator`
- [ ] On-chain x402 payment verification (stub → production)
- [ ] Lightning invoice verification for L402 (stub → production)

## Live Demo

A reference implementation is publicly deployed at **https://mdf-demo.bitcryptic.com**

Try it now:

```bash
# Discover the site's MDF capabilities
curl https://mdf-demo.bitcryptic.com/mdf.json

# Fetch the agent index
curl https://mdf-demo.bitcryptic.com/llms.txt

# Request markdown directly (agent-style)
curl -H "Accept: text/markdown" https://mdf-demo.bitcryptic.com/

# Free content — no payment required
curl -H "Accept: text/markdown" https://mdf-demo.bitcryptic.com/docs/getting-started

# Paid content — returns 402 with payment instructions
curl -H "Accept: text/markdown" https://mdf-demo.bitcryptic.com/premium/deep-dive

# Private content — returns 402 with auth endpoint hint
curl https://mdf-demo.bitcryptic.com/private/internals

# Atom feed with mdf:change_type metadata
curl https://mdf-demo.bitcryptic.com/feed.xml
```

The demo site exercises all three payment tiers and the full auth-via-payment flow. Both x402 (EVM) and L402 (Lightning) payment rails are stubbed — no real transaction is required to explore the protocol behaviour.

## Get involved

This is an early-stage community proposal. The open questions section of the concept document is a good starting point for discussion.

- **Discuss:** Open an issue
- **Implement:** Build an MDF-compatible server or client and link it here
- **Challenge:** If you think this is wrong, redundant, or misses something — say so

## License

MIT
