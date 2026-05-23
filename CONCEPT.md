# MDF — Markdown First

> A proposal for a web content architecture where markdown is the source of truth, agents are first-class citizens, and access policy is expressed through price.

**Status:** Draft concept — seeking community feedback  
**Authors:** Gary Walker / BitCryptic™ · Graham Hall / Slepner  
**Repo:** `bitcryptic-gw/mdf`  
**Discussion:** [GitHub Issues]

---

## The Problem

The web was built for human eyes. HTML encodes visual layout, navigation chrome, advertising scaffolding, and JavaScript interactivity — none of which carries semantic value for an AI agent consuming content. Yet agents are now among the most frequent consumers of web content, and they pay a significant tax for this mismatch.

A typical web page fetched by an agent contains 5–10× more tokens than the actual content it carries. One documented benchmark shows a Cloudflare blog post consuming 16,180 tokens as HTML versus 3,150 as markdown — an 80% overhead. At scale, across millions of agent fetches per day, this represents enormous computational waste and cost borne by AI operators, content consumers, and ultimately end users.

The deeper problem is architectural: **HTML is generated from a source of truth that is usually already markdown or structured text, then agents must reverse that transformation at significant cost.** This is wasteful by design.

A secondary problem: content creators have no mechanism to express access intent, receive compensation for agent consumption of their work, or gate access to private or premium content — all without breaking the human browsing experience.

---

## Existing Partial Solutions

Several initiatives have addressed pieces of this problem, but none provide a coherent end-to-end architecture.

**llms.txt** (Jeremy Howard, Answer.AI, 2024) proposes a `/llms.txt` markdown index file at the site root, guiding agents to key resources and optionally linking to per-page `.md` alternates. It is a discovery mechanism, not a serving or payment mechanism. Adoption is growing but it remains a community proposal without formal standardisation body backing.

**HTTP Content Negotiation** (`Accept: text/markdown`) allows agents to signal a preference for markdown, and servers that support it can respond accordingly. This is the cleanest transport approach — same URL, same content, different representation. It requires per-server implementation and offers no discovery, payment, or access policy layer.

**Cloudflare Markdown for Agents** (February 2026) productises content negotiation at the CDN edge, converting HTML to markdown in real time for any site behind Cloudflare. It adds `x-markdown-tokens` and `Content-Signal` headers. This is a conversion approach — it does not change the fact that HTML remains the source of truth, and it is tied to a single vendor's infrastructure.

**x402** is an emerging HTTP payment protocol using the long-reserved `402 Payment Required` status code, designed for machine-to-machine micropayments, particularly over crypto rails. It is not web-content-specific but provides exactly the payment primitive MDF needs.

**The gap:** none of these address markdown-as-source-of-truth, creator compensation, or unified access policy. MDF proposes to connect them.

---

## The MDF Philosophy

MDF is built on three principles:

**1. Markdown is the source of truth.**  
HTML is a rendering target, not the canonical document. Sites that adopt MDF author in markdown and serve HTML to browsers dynamically. This is already how most modern static site generators, documentation platforms, and technical blogs work internally — MDF simply makes this the explicit contract with the outside world.

**2. Agents are first-class citizens.**  
Agent access is not an afterthought handled by conversion middleware. MDF-compliant endpoints natively serve markdown via HTTP content negotiation, expose structured discovery, and behave predictably across all agent implementations without per-site parsing logic.

**3. Price is access policy.**  
Rather than maintaining separate robots.txt directives, authentication layers, and paywalls, MDF unifies access control into a single price signal attached to the markdown endpoint. The price an owner sets communicates intent clearly to both agents and their operators, and the payment mechanism doubles as proof of authorised access.

---

## Architecture

### Content Serving

MDF-compliant sites serve markdown via standard HTTP content negotiation:

```
GET /some-page HTTP/1.1
Accept: text/markdown, text/html;q=0.9
```

```
HTTP/1.1 200 OK
Content-Type: text/markdown
X-MDF-Version: 1
X-MDF-Tokens: 847
X-MDF-Price: 0.0001
X-MDF-Currency: USDC
```

The same URL serves both humans (HTML) and agents (markdown). No separate URL scheme or protocol is required — standard HTTP, standard content negotiation.

### Discovery

MDF extends the llms.txt convention. An MDF-compliant site exposes:

- `/llms.txt` — standard llms.txt index (backwards compatible)
- `/mdf.json` — machine-readable MDF capability document, advertising:
  - Supported content types
  - Default and per-section pricing
  - Accepted payment methods/chains
  - Auth token endpoint (if applicable)
  - Site-level content signals (training consent, search consent, etc.)

Example `/mdf.json`:

```json
{
  "mdf_version": "1.0",
  "site": "https://example.com",
  "pricing": {
    "default": { "amount": "0.0001", "currency": "USDC", "chain": "base" },
    "sections": {
      "/docs/*": { "amount": "0.0000", "currency": null },
      "/premium/*": { "amount": "1.0000", "currency": "USDC", "chain": "base" }
    }
  },
  "auth_endpoint": "https://example.com/mdf/auth",
  "content_signals": {
    "ai_train": false,
    "ai_input": true,
    "search": true
  },
  "llms_txt": "https://example.com/llms.txt"
}
```

### The Payment Spectrum

The price field is not merely a transaction amount — it is the primary access policy signal. Site owners choose their position on a continuous spectrum:

| Price | Meaning | Behaviour |
|-------|---------|-----------|
| `0.00` | Open access | Serve immediately, no payment required. Equivalent to permissive robots.txt. |
| `0.0001` (example) | Micropayment | Agent pays a small per-fetch fee. Content creator offsets infrastructure costs. Cheaper for AI operators than fetching and stripping HTML. |
| `1.00+` | Premium content | Meaningful payment required. Subscription-tier documentation, research, or gated resources. |
| `100.00+` | Private / authorised only | Price functions as an access barrier. At this tier, payment triggers an auth flow rather than immediate content delivery. |

This model has several useful properties:

- **No separate access control mechanism required** — price communicates intent without additional configuration
- **Bots that ignore the payment signal self-identify** — compliant agents pay; non-compliant scrapers do not, creating a clear audit trail
- **Gradual monetisation** — owners can start at $0.00 and adjust without changing infrastructure
- **Human browsing is unaffected** — the payment layer applies only to `Accept: text/markdown` requests; standard HTML requests are served normally

### Authentication via Payment

At high price points, payment transitions from a micropayment into an access token request. The flow:

1. Agent fetches `/mdf.json`, sees price of `$X` for a section
2. Agent sends payment transaction to the site's declared wallet/payment endpoint
3. Site verifies payment on-chain and issues a time-limited bearer token
4. Agent includes bearer token in subsequent `Authorization` header for markdown fetches
5. Site serves markdown to token-bearing requests without further payment per fetch (or per session, per volume — owner configurable)

This gives site operators a full authentication layer with no passwords, no OAuth, no API key management — payment is the credential issuance mechanism.

### Content Signals

MDF adopts and extends the Content-Signal pattern (as introduced by Cloudflare) as a first-class field in `/mdf.json` and response headers. Signals include:

- `ai_train` — whether content may be used for model training
- `ai_input` — whether content may be used as agent context at inference time
- `search` — whether content may be indexed by search systems
- `human_only` — whether content is intended exclusively for human consumption (suppresses agent serving regardless of payment)

These are advisory signals. MDF does not enforce them technically but provides a standard vocabulary for expressing them, enabling compliant agent operators to honour them.

---

## What MDF Is Not

- **Not a new protocol.** MDF uses HTTP throughout. No new URL scheme, no new transport layer, no new port.
- **Not a Cloudflare replacement.** MDF is infrastructure-agnostic. A Caddy plugin, an Nginx module, a Node middleware, or a CDN feature can all implement it.
- **Not a DRM system.** MDF cannot prevent determined scrapers. It creates a standard, economic incentive for compliant behaviour and an audit trail for non-compliant behaviour.
- **Not prescriptive about payment rails.** The spec defines the interface; USDC on Base is a natural first implementation but any payment rail that can produce a verifiable on-chain receipt is compatible.

---

## Reference Implementation Plan

The reference implementation will be a self-hostable Docker image (`bitcryptic/mdf-server`) acting as a reverse proxy or standalone server. It will:

- Serve markdown natively from a content directory, with HTML rendered dynamically for browser requests
- Auto-generate `/llms.txt` and `/mdf.json` from site configuration
- Handle `Accept: text/markdown` content negotiation
- Integrate x402 payment verification against configurable chains
- Issue and validate bearer tokens for high-price-tier access
- Expose a simple dashboard: fetch counts, earnings, content signal summary

Target stack: Bun + Caddy or standalone Bun HTTP server, Docker image for Unraid/standard Docker deployment, configuration via a single `mdf.yaml`.

A hosted demo site will accompany the reference implementation, demonstrating all three payment tiers end-to-end.

---

## Relationship to BitCryptic Compute

MDF's payment layer and content delivery infrastructure align naturally with the BitCryptic Compute vision — a crypto-native infrastructure marketplace. MDF-enabled content delivery nodes are a concrete, deployable use case for that platform: operators run MDF servers, earn micropayments for content served to agents, and the BitCryptic Compute network provides the payment routing and settlement layer.

This positions BitCryptic Compute not only as an AI inference marketplace but as the infrastructure layer for the emerging agent-readable web.

---

## Open Questions

The following are explicitly unresolved and intended to drive community discussion:

1. **Payment rail standardisation** — Should the spec recommend a default chain/currency, or remain fully agnostic? Agnosticism is cleaner but creates interoperability friction for agent implementors.
2. **Receipt verification** — How does a site verify payment without running a full node? Trust a third-party RPC, run a light client, or accept signed payment proofs from a settlement layer?
3. **Rate limiting and abuse** — A $0.00 endpoint is still reachable by abusive scrapers. Should MDF include a rate-limit signalling mechanism separate from price?
4. **Markdown dialect** — Should MDF specify a markdown dialect (CommonMark, GFM) or remain agnostic? Agents benefit from predictability; authors benefit from flexibility.
5. **Content freshness** — How should agents know when markdown content has changed? ETags and `Last-Modified` are standard HTTP but may need MDF-specific extensions for structured change signals.
6. **Human access to paid content** — If `/premium/*` costs $1.00 per agent fetch, how does a human subscriber access it? MDF should not break human auth flows. Possible answer: price applies only to `Accept: text/markdown` requests; human HTML requests use existing auth (cookies, sessions) independently.

---

## How to Contribute

This is an early-stage community proposal. Feedback, criticism, implementation experiments, and alternative approaches are all welcome.

- **Discuss:** Open a GitHub Issue on this repo
- **Implement:** Build an MDF-compatible server or client and link it here
- **Challenge:** If you think this is wrong, redundant, or misses something important, say so — the open questions section above is a starting point

The goal is a spec that is good enough to be useful, simple enough to implement in an afternoon, and open enough that no single party controls it.

---

## Acknowledgements

MDF builds on the work of Jeremy Howard (llms.txt), the HTTP working group (content negotiation, RFC 7231), the x402 protocol contributors, and Cloudflare's Markdown for Agents feature which demonstrated the demand at scale.

---

*MDF is a community proposal. It is not affiliated with or endorsed by Cloudflare, Anthropic, Answer.AI, or any other organisation mentioned herein.*
