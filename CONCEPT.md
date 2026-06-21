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

**x402** is an emerging HTTP payment protocol using the long-reserved `402 Payment Required` status code, designed for machine-to-machine micropayments over EVM-compatible crypto rails. It is not web-content-specific but provides exactly the payment primitive MDF needs for stablecoin and EVM-based payment flows.

**L402** (formerly LSAT) is a complementary HTTP payment and authentication protocol built on Bitcoin's Lightning Network. It combines a Lightning invoice with a macaroon-based bearer credential, enabling sub-second, sub-cent micropayments without on-chain settlement latency. Like x402, L402 uses the `402 Payment Required` status code and is designed for machine-to-machine use. It is already supported by a growing ecosystem of Lightning-native services and tooling. MDF supports L402 as the Bitcoin-native payment rail alongside x402.

> **402index.io** is a protocol-agnostic directory of paid APIs across L402, x402, and MPP (Machine Payments Protocol, Stripe/Tempo-facilitated session-based settlement). It indexes and payment-verifies endpoints hourly and exposes an MCP server for agent discovery. It is useful prior art demonstrating real-world demand for the 402 ecosystem and a potential discoverability layer for MDF-enabled sites. MPP is acknowledged here as an emerging rail; MDF's rail-agnostic design accommodates it without spec changes, but it is not in scope for v0.1.
>
> 402index.io also uses an emerging convention — `/.well-known/l402-services` — where L402 providers publish a machine-readable JSON document describing their endpoints, pricing, and request schemas for autodiscovery. MDF's `/mdf.json` serves a richer version of this same purpose (adding content signals, feed URL, auth endpoint, and format metadata). Whether MDF sites should also publish a `.well-known/l402-services` document for compatibility with the broader 402 ecosystem is an open question — see Open Question 7.

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

`/mdf.json` is a **capability and mechanism** declaration — not a coverage index, not a price list. Its job is to state that a site supports `Accept: text/markdown` negotiation, describe how payment works if it applies (which rails are accepted, where the payment endpoint lives), and declare site-level content signals. It does **not** state which specific URLs currently have markdown available, what fraction of the site is covered, or what any individual resource costs.

Those questions are answered at request time by the actual response to an `Accept: text/markdown` request:

- **200 with markdown** — available, and free (or already paid/entitled).
- **402 with price details** — available, but requires payment for this resource.
- **Normal HTML, no `Vary: Accept`** — markdown not available for this URL at all (not yet converted, or simply not offered).

This design keeps `/mdf.json` static and reliable. Keeping it in sync with dynamic per-resource state — a backfill in progress, a newly published post not yet converted, per-post or per-tier pricing — would require continuous rewriting of a document that is meant to describe infrastructure. The per-request response is already the correct source of truth for resource-level state, and `/mdf.json` should not duplicate it and risk drifting out of sync. This also aligns with how x402 and L402 work at the protocol level: a 402 response, not a pre-declared price schedule, is the standard's price-discovery mechanism.

The one piece of information `/mdf.json` must state accurately — because it cannot be discovered per-request the way coverage and per-URL price can — is **mechanism**: which payment rails are accepted, and where the payment endpoint lives. An agent needs this before it can even attempt payment.

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

### Payment Rails

MDF is payment-rail-agnostic. Any mechanism that can produce a verifiable payment proof is compatible. Two protocols are the natural first implementations:

**x402** handles EVM-compatible chains (Base, Ethereum, Polygon, Solana) with stablecoin payments (USDC, USDT). It is well-suited to agents operating in a crypto-native or DeFi context, and to site operators who already manage EVM wallets.

**L402** handles Bitcoin via the Lightning Network. Lightning payments settle in sub-seconds at sub-cent fees with no on-chain transaction required. L402 pairs the Lightning invoice with a macaroon credential, so payment and access token issuance happen in a single round trip. It is well-suited to operators and agents in the Bitcoin ecosystem and to any use case where Lightning's payment finality and minimal trust assumptions are preferable to EVM settlement.

Sites advertise which rails they accept in `/mdf.json` via `payment.accepted_chains`. Agents select the rail their operator supports. Both protocols use the `402 Payment Required` response code, and MDF's payment flow is identical regardless of which rail executes it.

A third rail — **MPP (Machine Payments Protocol, via Stripe/Tempo)** — has emerged in the broader 402 ecosystem. MPP is a session-based fiat settlement option facilitated by Stripe or Tempo rather than a decentralised payment network. It is not in scope for MDF v0.1 but is acknowledged as a future extension point. MDF's payment-rail-agnostic design means MPP could be added without architectural changes — a site would simply advertise it in `payment.accepted_chains` and implement the corresponding verification logic.

### Authentication via Payment

At high price points, payment transitions from a micropayment into an access token request. The flow:

1. Agent fetches `/mdf.json`, sees price of `$X` for a section
2. Agent sends payment transaction to the site's declared wallet/payment endpoint
3. Site verifies payment (on-chain receipt for x402; Lightning invoice settlement for L402) and issues a time-limited bearer token
4. Agent includes bearer token in subsequent `Authorization` header for markdown fetches
5. Site serves markdown to token-bearing requests without further payment per fetch (or per session, per volume — owner configurable)

This gives site operators a full authentication layer with no passwords, no OAuth, no API key management — payment is the credential issuance mechanism.

### Content Signals

MDF adopts and extends the Content-Signal pattern (as introduced by Cloudflare) as a first-class field in `/mdf.json` and response headers. Signals include:

- `ai_train` — whether content may be used for model training
- `ai_input` — whether content may be used as agent context at inference time
- `search` — whether content may be indexed by search systems
- `human_only` — whether content is intended exclusively for human consumption (suppresses agent serving regardless of payment)

#### Human Presence Verification

The `human_only` signal expresses intent, but intent is not enforcement. For content where the
distinction between a human and an agent consumer genuinely matters, a stronger mechanism is needed.

Passkeys (WebAuthn/FIDO2) are the strongest available human-presence primitive on the web today. A
passkey operation requires a hardware gesture — biometric, PIN, or physical tap — that cannot be
delegated to software without the human's active participation. This is precisely the gap that
platforms serving royalty-bearing or sensitive content struggle to close: a session token proves
authentication happened, but not that a human initiated the request. Agents holding valid credentials
are indistinguishable from humans at the token layer alone.

For `human_only` content tiers where a meaningful price is set, we think the right pattern is to
require a WebAuthn assertion as part of the payment and token-issuance flow:

1. Agent fetches `/mdf.json`, sees `human_only: true` for the requested section and a non-zero price.
2. Agent surfaces this to its human operator — it cannot satisfy the requirement autonomously.
3. Human authenticates with their passkey, submits payment, and receives a time-limited bearer token
   carrying the WebAuthn attestation.
4. Agent uses that token for subsequent fetches within the session — mirroring how a human would
   delegate access after logging in to a conventional site.

This keeps passkeys out of the critical path for agent-accessible content, where they would be an
outright barrier, while giving publishers a meaningful human-presence gate for content that warrants it.

Note the relationship to open question 6 (human access to paid content): the separation of HTML and
markdown auth flows is the foundational answer to that question — human browsers use existing session
auth, agents use the payment-and-token flow. Passkey attestation sits within the payment-and-token
flow as an optional additional signal for `human_only` tiers specifically. The two mechanisms are
complementary, not competing.

**On the fraud incentive structure**

A related concern — prompted by how streaming platforms handle artificial consumption fraud — is
whether MDF faces a similar consumer-side abuse problem. We don't think it does, for a structural
reason: in MDF, payment flows upstream. The consumer pays the content owner per fetch. There is no
financial incentive to fake consumption, because doing so costs the attacker money rather than
earning it. The fraud vector that plagues per-stream royalty models — bots holding valid credentials
and simulating activity to inflate payouts — does not exist in this architecture.

The producer-side equivalent — content owners making trivial updates to force agent re-fetches and
extract repeated payments — is a real concern and is tracked separately as open question 4.

**Where we'd welcome input**

We're reasonably confident passkeys belong at the extension layer rather than in MDF core, and that
the payment-upstream model eliminates the streaming-fraud analogue. Two points where we're less
certain and would value community input:

- Should WebAuthn verification for `human_only` tiers be performed directly by the MDF server, or
  delegated to an identity provider? Direct verification is simpler and avoids third-party
  dependencies; IdP delegation is more flexible for sites with existing auth infrastructure.
- Should `human_only` be expressible at the section level in `/mdf.json` (as it currently is), at
  the per-resource level via response headers, or both?

If you've worked on human-presence verification in agent-native architectures, we'd genuinely like
to hear your perspective — open an issue or start a discussion in the spec repo.

These are advisory signals. MDF does not enforce them technically but provides a standard vocabulary for expressing them, enabling compliant agent operators to honour them.

### Content Freshness and Agent Subscriptions

Polling is as wasteful for agents as it was for RSS readers in 2003. MDF addresses content freshness at two levels.

**Per-request freshness** uses standard HTTP mechanisms: `ETag` and `Last-Modified` response headers, honoured by compliant agents to avoid re-fetching unchanged content. No MDF-specific extension is required here — existing HTTP caching semantics apply directly.

**Site-level change subscriptions** borrow from RSS/Atom and WebSub. MDF-compliant sites expose a feed (RSS 2.0 or Atom 1.0) at a URL advertised in `/mdf.json`. Agents that support feed polling can watch for changes without fetching every page repeatedly.

MDF extends the standard feed format with the `mdf:` XML namespace, providing agent-semantic change metadata per entry:

```xml
<feed
  xmlns="http://www.w3.org/2005/Atom"
  xmlns:mdf="https://github.com/bitcryptic-gw/mdf/ns/1.0">

  <link rel="hub" href="https://pubsubhubbub.appspot.com/"/>

  <entry>
    <id>urn:uuid:38398fe6-b711-45af-a5ce-ee27da9f89d0</id>
    <title>Pricing updated for /premium section</title>
    <updated>2026-05-28T10:00:00.000Z</updated>
    <link rel="alternate" href="https://example.com/premium/overview"/>
    <mdf:change_type>pricing_change</mdf:change_type>
  </entry>

</feed>
```

**Namespace URI:** `https://github.com/bitcryptic-gw/mdf/ns/1.0`

The namespace is declared on the root `<feed>` element. Each entry carries a single `<mdf:change_type>` element. The feed is Atom 1.0. A WebSub hub is declared via `<link rel="hub">` for push notification support.

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
- **Not prescriptive about payment rails.** The spec defines the interface; x402 over EVM chains and L402 over Lightning are the natural first implementations, but any payment rail that can produce a verifiable payment proof is compatible.

---

## Reference Implementation

The reference implementation is a self-hostable Docker image (`bitcryptic/mdf-server`) available on Docker Hub. Source is at `bitcryptic-gw/mdf-reference-server`. It:

- Serves markdown natively from a content directory, with HTML rendered dynamically for browser requests
- Auto-generates `/llms.txt` and `/mdf.json` from site configuration
- Handles `Accept: text/markdown` content negotiation
- Integrates x402 payment verification against configurable EVM chains
- Integrates L402 payment verification against a configurable Lightning node or LSP endpoint
- Issues and validate bearer tokens for high-price-tier access
- Exposes a simple dashboard: fetch counts, earnings by rail, content signal summary

Target stack: Bun + Caddy or standalone Bun HTTP server, Docker image for Unraid/standard Docker deployment, configuration via a single `mdf.yaml`.

A hosted demo site is live at **https://mdf-demo.bitcryptic.com**, demonstrating all three payment tiers end-to-end across both payment rails.
---

## Relationship to BitCryptic Compute

MDF's payment layer and content delivery infrastructure align naturally with the BitCryptic Compute vision — a crypto-native infrastructure marketplace. MDF-enabled content delivery nodes are a concrete, deployable use case for that platform: operators run MDF servers, earn micropayments for content served to agents, and the BitCryptic Compute network provides the payment routing and settlement layer.

This positions BitCryptic Compute not only as an AI inference marketplace but as the infrastructure layer for the emerging agent-readable web.

---

## Open Questions

The following are explicitly unresolved and intended to drive community discussion:

1. **Payment rail standardisation** — Should the spec recommend a default rail (x402 on Base? L402 on Lightning?), or remain fully agnostic? Agnosticism is cleaner but creates interoperability friction for agent implementors who must support multiple rails. A third rail, MPP (Machine Payments Protocol, Stripe/Tempo-facilitated session-based settlement), has emerged in the broader 402 ecosystem — MDF's rail-agnostic design accommodates it without spec changes but it is not yet formally in scope for v0.1.
2. **Receipt verification** — How does a site verify payment without running a full node? For x402: trust a third-party RPC, run a light client, or accept signed payment proofs from a settlement layer. For L402: trust an LSP, run a lightweight Lightning node, or verify macaroon credentials independently.
3. **Rate limiting and abuse** — A $0.00 endpoint is still reachable by abusive scrapers. Should MDF include a rate-limit signalling mechanism separate from price?
4. **Update gaming and re-fetch incentives** — The content freshness and subscription model must not create economic incentives for content owners to manipulate change frequency or volume. Two distinct attack vectors exist: (a) *high-frequency trivial changes* — an owner makes constant minor edits to trigger agent re-fetches and repeated payments; (b) *deliberate large rewrites* — an owner makes sweeping content changes to reset the payment clock and justify a full re-fetch fee. Several mitigations are under consideration, none yet adopted as the canonical approach: a *time-window access model* where a paid fetch grants access to all updates within a defined window (e.g. 24 hours), making incremental change gaming economically irrational; a *change significance floor* expressed as a normalised `mdf:significance` score (0.0–1.0, computed server-side via diff) that agents can threshold to ignore low-value updates without fetching or paying; and a *feed-level subscription price* replacing per-fetch update pricing entirely, aligning owner incentives with producing genuinely useful content rather than churn. The time-window model is the current preferred direction for its simplicity and the fact that it makes gaming irrational by design rather than relying on detectable behaviour. Community input is sought before this is committed to the architecture.
5. **Markdown dialect** — Should MDF specify a markdown dialect (CommonMark, GFM) or remain agnostic? Agents benefit from predictability; authors benefit from flexibility.
6. **Human access to paid content** — If `/premium/*` costs $1.00 per agent fetch, how does a human subscriber access it? MDF should not break human auth flows. Possible answer: price applies only to `Accept: text/markdown` requests; human HTML requests use existing auth (cookies, sessions) independently.

7. **`.well-known/l402-services` alignment** — 402index.io uses this emerging convention for L402 endpoint autodiscovery. MDF's `/mdf.json` serves a richer version of the same purpose. Should MDF sites also publish a `.well-known/l402-services` document for compatibility with the broader L402 ecosystem, or is `/mdf.json` the canonical MDF discovery mechanism and `.well-known` left to implementors who want dual compatibility?

8. **L402 token format compatibility** — 402index.io classifies L402 tokens by format (V2 TLV binary, V1 binary, V0 libmacaroons text, JSON, or unknown) and checks compatibility with the `lnget` client per BLIP-0026. The MDF reference implementation uses an HMAC-bound JSON token — simpler than libmacaroons, no additional dependencies, sufficient for the reference implementation. Whether MDF should specify or recommend a token format for agent ecosystem interoperability is unresolved. A more compatible format could improve out-of-the-box agent support; the current approach prioritises simplicity and auditability.

9. **Broker/alternate content URL extension** — Should `/mdf.json` support declaring an alternate host where a third party serves a site's markdown on its behalf (e.g. a broker or CDN-like intermediary)? Pre-declaring the alternate `content_url` in `/mdf.json` solves *origin* trust (the redirect target is named by the same domain serving the discovery document, inheriting its DNS/TLS trust) but not *content integrity* once the markdown is fetched from the third party. Two non-exclusive approaches are under consideration: the broker signs the markdown payload (or its hash) with a key whose pubkey is pre-declared in `/mdf.json`, reusing the same attested-signing pattern used elsewhere for payment verification — the stronger guarantee, requiring key management on the broker's side; or content-hash pinning, where `/mdf.json` declares a hash of the current content and the agent checks the fetched markdown against it — simpler, but freshness-coupled to the origin keeping the hash current rather than an independent authority. Neither has been adopted; this extension has not been built.

---

## How to Contribute

This is an early-stage community proposal. Feedback, criticism, implementation experiments, and alternative approaches are all welcome.

- **Discuss:** Open a GitHub Issue on this repo
- **Implement:** Build an MDF-compatible server or client and link it here
- **Challenge:** If you think this is wrong, redundant, or misses something important, say so — the open questions section above is a starting point

The goal is a spec that is good enough to be useful, simple enough to implement in an afternoon, and open enough that no single party controls it.

---

## Acknowledgements

MDF builds on the work of Jeremy Howard (llms.txt), the HTTP working group (content negotiation, RFC 7231), the x402 protocol contributors, the 402index.io team whose protocol-agnostic directory demonstrates real-world demand and provides a useful prior art reference for the broader 402 ecosystem, the L402 protocol contributors and the broader Lightning Network development community, Cloudflare's Markdown for Agents feature which demonstrated the demand at scale, the RSS/Atom community whose feed standards MDF extends for agent subscriptions, and the W3C WebSub working group.

---

*MDF is a community proposal. It is not affiliated with or endorsed by Cloudflare, Anthropic, Answer.AI, or any other organisation mentioned herein.*
