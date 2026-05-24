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

**RSS/Atom** solved the content freshness problem for human subscribers in the early 2000s — rather than polling pages repeatedly, subscribers watch a feed and receive notifications when content changes. The same problem exists for agents, and the same solution applies. RSS/Atom feeds are near-universally supported and already present on most content sites.

**WebSub** (W3C, formerly PubSubHubbub) is the push layer that RSS never had built in. Publishers notify a hub when content changes; subscribers receive pushed updates rather than polling. It is already supported by WordPress, Blogger, and major feed readers, making it a natural push transport for MDF-aware agents.

**The gap:** none of these address markdown-as-source-of-truth, creator compensation, unified access policy, or agent-semantic change notifications. MDF proposes to connect them.

A core design principle of MDF is to act as a **connective layer between existing standards** rather than replacing any of them. Implementors should not need to abandon existing infrastructure — MDF provides the architecture that links these pieces into a coherent whole.

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

### Content Freshness and Agent Subscriptions

Polling is as wasteful for agents as it was for RSS readers in 2003. MDF addresses content freshness at two levels.

**Per-request freshness** uses standard HTTP mechanisms: `ETag` and `Last-Modified` response headers, honoured by compliant agents to avoid re-fetching unchanged content. No MDF-specific extension is required here — existing HTTP caching semantics apply directly.

**Site-level change subscriptions** borrow from RSS/Atom and WebSub. MDF-compliant sites expose a feed (RSS 2.0 or Atom 1.0) at a URL advertised in `/mdf.json`. Agents that support feed polling can watch for changes without fetching every page repeatedly.

MDF extends the standard feed format with an optional `<mdf:change>` namespace providing agent-semantic change metadata per entry:

```xml
<item>
  <title>Pricing updated for /premium section</title>
  <link>https://example.com/premium/overview</link>
  <pubDate>Sat, 23 May 2026 10:00:00 +0000</pubDate>
  <mdf:change_type>pricing_change</mdf:change_type>
  <mdf:path>/premium/**</mdf:path>
  <mdf:content_signals_changed>false</mdf:content_signals_changed>
  <mdf:token_delta>0</mdf:token_delta>
</item>
```

Defined `change_type` values:

| Value | Meaning |
|-------|---------|
| `content_update` | Existing page content has changed |
| `new_page` | A new page has been added |
| `retraction` | A page has been removed or significantly redacted |
| `pricing_change` | Pricing for a path has changed — agent may need to update budget allocation |
| `signal_change` | Content signals (e.g. `ai_train`) have changed |
| `mdf_capability` | The `/mdf.json` capability document itself has changed |

This allows agents to make intelligent re-fetch decisions based on change type rather than fetching and diffing content. A `pricing_change` entry is actionable without re-fetching any content at all.

**Push via WebSub** is the recommended upgrade path for sites that want real-time agent notification rather than polling. Sites declare a WebSub hub in the feed `<link rel="hub">` element per the W3C WebSub spec. Agents that support WebSub receive pushed change notifications; those that do not fall back to polling gracefully. No MDF-specific hub is required — any compliant WebSub hub works.

---

## What MDF Is Not

- **Not a new protocol.** MDF uses HTTP throughout. No new URL scheme, no new transport layer, no new port.
- **Not a Cloudflare replacement.** MDF is infrastructure-agnostic. A Caddy plugin, an Nginx module, a Node middleware, or a CDN feature can all implement it.
- **Not a DRM system.** MDF cannot prevent determined scrapers. It creates a standard, economic incentive for compliant behaviour and an audit trail for non-compliant behaviour.
- **Not prescriptive about payment rails.** The spec defines the interface; USDC on Base is a natural first implementation but any payment rail that can produce a verifiable on-chain receipt is compatible.

---

## Reference Implementation

A reference implementation is available at **https://github.com/bitcryptic-gw/mdf** and publicly deployed at **https://mdf-demo.bitcryptic.com**.

The implementation is a self-hostable Docker image (`mdf-reference-server`) built on Bun. It demonstrates the full MDF architecture end-to-end:

- Markdown-native content serving with dynamic HTML rendering for browser requests
- `Accept: text/markdown` content negotiation at existing URLs — no new protocol or port
- Auto-generated `/llms.txt` and `/mdf.json` from a single `mdf.yaml` configuration file
- Three-tier pricing demonstration: open access (`/docs/**`), micropayment (`/premium/**`), and private auth-via-payment (`/private/**`)
- x402 payment verification (stubbed — structural validation only, on-chain verification not yet implemented)
- Bearer token issuance and validation for high-price-tier access
- Standard HTTP ETags and conditional GET support
- Internal dashboard on a separate port (not publicly exposed)

The payment verification stub accepts structurally valid x402 proofs and logs them for audit without performing on-chain receipt checks. This allows the full protocol flow to be explored without live transactions. Real x402 verification is the next implementation milestone.

Configuration is via a single `mdf.yaml` file. The wallet address is supplied via Docker secret file and never appears in environment variables or image layers.

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
4. **Update gaming and re-fetch incentives** — The content freshness and subscription model must not create economic incentives for content owners to manipulate change frequency or volume. Two distinct attack vectors exist: (a) *high-frequency trivial changes* — an owner makes constant minor edits to trigger agent re-fetches and repeated payments; (b) *deliberate large rewrites* — an owner makes sweeping content changes to reset the payment clock and justify a full re-fetch fee. Several mitigations are under consideration, none yet adopted as the canonical approach: a *time-window access model* where a paid fetch grants access to all updates within a defined window (e.g. 24 hours), making incremental change gaming economically irrational; a *change significance floor* expressed as a normalised `mdf:significance` score (0.0–1.0, computed server-side via diff) that agents can threshold to ignore low-value updates without fetching or paying; and a *feed-level subscription price* replacing per-fetch update pricing entirely, aligning owner incentives with producing genuinely useful content rather than churn. The time-window model is the current preferred direction for its simplicity and the fact that it makes gaming irrational by design rather than relying on detectable behaviour. Community input is sought before this is committed to the architecture.
5. **Markdown dialect** — Should MDF specify a markdown dialect (CommonMark, GFM) or remain agnostic? Agents benefit from predictability; authors benefit from flexibility.
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

MDF builds on the work of Jeremy Howard (llms.txt), the HTTP working group (content negotiation, RFC 7231), the x402 protocol contributors, Cloudflare's Markdown for Agents feature which demonstrated the demand at scale, the RSS/Atom community whose feed standards MDF extends for agent subscriptions, and the W3C WebSub working group.

---

*MDF is a community proposal. It is not affiliated with or endorsed by Cloudflare, Anthropic, Answer.AI, or any other organisation mentioned herein.*
