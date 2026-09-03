# MDF — Markdown First

> A proposal for a web content architecture where markdown is the source of truth, agents are first-class citizens, and access policy is expressed through price.

**Status:** Draft · Seeking community feedback  
**Authors:** Gary Walker / [BitCryptic™](https://bitcryptic.com) · Graham Hall / [Slepner](https://slepner.com.au)

---

## The problem in one paragraph

AI agents are now among the most frequent consumers of web content, yet the web serves them HTML — a format built for human eyes. Most agents compensate by stripping navigation, ads, scripts and layout markup client-side. That works, until it doesn't: the result depends entirely on how well a given page yields to a heuristic extractor, and the page has to be downloaded in full either way. Meanwhile the person who wrote the content receives nothing for it. MDF proposes a simple, open architecture addressing both halves: markdown as the canonical source, HTTP content negotiation for delivery, and an optional payment layer that doubles as access policy — giving creators a way to be paid for agent consumption of their work rather than watching it scraped and propagated for free.

## What MDF proposes

- **Markdown-first authoring** — markdown is the source of truth; HTML is rendered from it for browsers, not the other way around
- **Native agent serving** — `Accept: text/markdown` returns clean markdown at the same URL, no conversion middleware required
- **Structured discovery** — `/mdf.json` advertises capabilities, pricing, and content signals in a machine-readable format that agents can query before fetching
- **Price as access policy** — a single price field unifies open access, micropayment, and private/authenticated access into one continuous spectrum, using the x402 (EVM/stablecoin) and L402 (Bitcoin/Lightning) payment standards

## Two arguments, not one

**Efficiency, where it applies.** Serving markdown means the HTML never crosses the wire. Whether it also saves context-window tokens depends on the page: boilerplate-heavy commercial and editorial pages retain a large saving even against a good client-side extractor, while clean documentation may save almost nothing. Where MDF is unconditionally better is determinism — the publisher declares what the content is, rather than an extractor guessing, so JS-rendered, paginated and table-dense pages stop failing silently.

**Compensation, always.** This half doesn't depend on markdown being smaller. Today a creator's options are to be scraped for free or to retreat behind a login and disappear from the open web. MDF offers a third: stay open and discoverable, and be paid at the point of machine consumption. At higher price tiers the same payment mechanism issues an access credential, giving a small publisher the practical equivalent of a subscription wall without operating one — and giving agents a lawful route to content that was previously unavailable at any price.

## How the price spectrum works

| Price | What it means |
|-------|--------------|
| `$0.00` | Open — serve immediately, no payment required |
| `$0.0001` | Micropayment — small per-fetch fee offsets creator costs; on boilerplate-heavy pages, typically cheaper for AI operators than downloading and extracting the HTML |
| `$1.00+` | Premium — meaningful payment for gated content |
| `$100.00+` | Private — payment triggers an auth token issuance rather than immediate delivery |

Servers performing on-server markdown conversion may also report the size reduction between the original HTML and the served markdown directly in the response — giving agents a concrete efficiency signal alongside the price itself, rather than requiring them to price a request in the dark. See the concept document's Response Value Signalling section for details.

## Read the full proposal

→ [CONCEPT.md](./CONCEPT.md)

The concept document covers the full architecture, existing partial solutions, open questions, and the reference implementation plan.

→ [MCP-GATEWAY.md](./MCP-GATEWAY.md)

A concept document for an MDF reference *client*: an MCP gateway that lets any MCP-capable agent runtime discover, negotiate, evaluate and pay for MDF content. Concept stage, not built.

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
- [x] Lightning invoice verification for L402 (stub → production)
- [x] `mdf-402.schema.json` — JSON Schema for the 402 response body
- [ ] Reference client — MDF MCP gateway (concept published, not built)

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

## Ecosystem

### MDF Analytics for WordPress
A WordPress plugin that tracks AI agent traffic and `Accept: text/markdown` requests to your site, with a dashboard showing estimated earnings from MDF-enabled content. Phase 1 of a planned full MDF integration for WordPress including wallet connection and automatic markdown generation.

→ [bitcryptic-gw/mdf-analytics-wp](https://github.com/bitcryptic-gw/mdf-analytics-wp)

## Get involved

This is an early-stage community proposal. The open questions section of the concept document is a good starting point for discussion.

- **Discuss:** Open an issue
- **Implement:** Build an MDF-compatible server or client and link it here
- **Challenge:** If you think this is wrong, redundant, or misses something — say so

## License

MIT
