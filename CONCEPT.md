# MDF — Markdown First

> A proposal for a web content architecture where markdown is the source of truth, agents are first-class citizens, and access policy is expressed through price.

**Status:** Draft concept — seeking community feedback  
**Authors:** Gary Walker / BitCryptic™ · Graham Hall / Slepner  
**Repo:** `bitcryptic-gw/mdf`  
**Discussion:** [GitHub Issues]

---

## The Problem

The web was built for human eyes. HTML encodes visual layout, navigation chrome, advertising scaffolding, and JavaScript interactivity — none of which carries semantic value for an AI agent consuming content. Yet agents are now among the most frequent consumers of web content, and they pay a significant tax for this mismatch.

A typical web page fetched by an agent contains 5–10× more tokens than the actual content it carries. One documented benchmark shows a Cloudflare blog post consuming 16,180 tokens as HTML versus 3,150 as markdown — an 80% reduction, or roughly 5× the tokens for the same content. For an agent that feeds raw HTML into its context window, that overhead is paid in full on every fetch, and at scale it represents enormous computational waste borne by AI operators, content consumers, and ultimately end users.

This claim is worth stating precisely, because it is frequently overstated. Many agent runtimes already perform client-side HTML-to-markdown extraction before content reaches the model, and where that extraction succeeds, the context-window saving from a server-side markdown representation is small or nil. The size of the real saving depends on the content:

- **Boilerplate-heavy pages** — news, commerce, marketing, anything carrying navigation chrome, advertising scaffolding, consent interstitials and related-content rails — retain a substantial saving even after client-side extraction, because heuristic extractors routinely keep or discard the wrong regions, and the full payload must be downloaded regardless of what is subsequently thrown away.
- **JS-rendered, paginated, or table-dense pages** — where client-side extraction degrades silently or fails outright, returning truncated or garbled content that the agent has no way to identify as wrong.
- **Already-clean documentation and static content** — where a competent client-side extractor arrives at substantially the same result, and the honest saving approaches zero.

MDF's efficiency argument therefore holds for the wire in every case, since the HTML is never transferred at all, and for the context window where the content warrants it. What it offers universally is not compression but **determinism**: a canonical representation authored by the publisher, in which what counts as the content is declared rather than inferred.

The deeper problem is architectural: **HTML is generated from a source of truth that is usually already markdown or structured text, then agents must reverse that transformation at significant cost.** This is wasteful by design.

### The compensation problem

The second problem is independent of the first. It applies to every page regardless of how well that page converts, and it does not depend on markdown being smaller than HTML.

Content creators have no mechanism to express access intent, to receive compensation for agent consumption of their work, or to gate premium material without breaking the human browsing experience. The prevailing outcome is that content is scraped, absorbed and propagated, with the value accruing to whoever aggregates it rather than to whoever wrote it.

The established defence is the walled garden: put the work behind a login and a subscription, and accept that it becomes invisible to the open web. This protects the content but it is a blunt instrument. It excludes the casual reader, the citing author and the legitimate agent alike; it forces every publisher to operate an authentication and billing stack; and it removes the material from the commons entirely in order to stop it being taken for free.

MDF proposes payment as the gate rather than enclosure. A price attached to a markdown endpoint lets a publisher remain open and discoverable while still being paid for machine consumption. At higher price points the same mechanism issues an access credential, giving a small publisher the practical equivalent of a subscription wall without building one. For agents, it converts a category of content that was previously unavailable at any price into content that can be lawfully purchased at the point of use.

This is the leg of the proposal that holds where the efficiency argument does not. A page that a client-side extractor handles perfectly still leaves its author uncompensated.

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
X-MDF-Source-Bytes: 48213
X-MDF-Price: 0.0001
X-MDF-Currency: USDC
```

`X-MDF-Source-Bytes` carries the same value as the `source_bytes` field described under Response Value Signalling, exposed as a header for responses where a body-level field is not appropriate. Earlier drafts of this document showed an `X-MDF-Tokens` header here; it has been removed, because a server cannot produce an authoritative token count for a requesting agent whose tokenizer it does not know. Byte counts are verifiable and tokenizer-independent; token counts are not.

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
  "payment": {
    "endpoint": "https://example.com/mdf/pay",
    "accepted_chains": ["base", "lightning"],
    "accepted_currencies": ["USDC", "BTC"]
  },
  "auth": {
    "endpoint": "https://example.com/mdf/auth",
    "token_ttl_seconds": 86400,
    "price_threshold": "10.00"
  },
  "content_signals": {
    "ai_train": false,
    "ai_input": true,
    "search": true
  },
  "formats": {
    "dialect": "commonmark",
    "frontmatter": true
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
| `0.0001` (example) | Micropayment | Agent pays a small per-fetch fee. Content creator offsets infrastructure costs. On boilerplate-heavy pages this is typically cheaper for AI operators than fetching and stripping HTML. |
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

1. Agent requests the resource with `Accept: text/markdown` and receives a `402` stating a price of `$X`, a payment endpoint, and (where this tier issues a credential) an auth endpoint
2. Agent sends payment transaction to the payment endpoint named in that response
3. Site verifies payment (on-chain receipt for x402; Lightning invoice settlement for L402) and issues a time-limited bearer token
4. Agent includes bearer token in subsequent `Authorization` header for markdown fetches
5. Site serves markdown to token-bearing requests without further payment per fetch (or per session, per volume — owner configurable)

This gives site operators a full authentication layer with no passwords, no OAuth, no API key management — payment is the credential issuance mechanism.

### The 402 Response Body

Until now the 402 flow has been described in prose only, and the only schematised artefact in this repo has been `/mdf.json`. That was tenable while MDF was a supply-side proposal. It is no longer, because the 402 body is the one part of the wire format that arrives at a consumer from an arbitrary origin and may cause that consumer to spend money.

`mdf-402.schema.json` describes the JSON body a server emits alongside a `402 Payment Required` response to an `Accept: text/markdown` request. It is a description of server output, not a constraint on consumers — nothing in this specification requires a consumer to validate against it, and the schema exists so that those who choose to have something to validate against.

The only field a server must emit is `payment`, carrying at minimum an `endpoint`, an `amount` and a `currency`. Everything else is optional, including the diagnostic `error` and `reason` strings, the `source_bytes` and `savings` fields described below, and `auth_endpoint` where payment at this tier issues a credential rather than delivering content.

Five points warrant explanation rather than schema.

**Amounts are strings.** `payment.amount` is a decimal string, not a JSON number. Binary floating point cannot represent common decimal amounts exactly, and a payment protocol is the last place to accept that rounding.

**The `payment` object mixes two scopes.** `amount`, `currency` and `chain` describe *this offer for this resource*. `accepted_chains` and `accepted_currencies` describe *what the site accepts in general* — the same mechanism `/mdf.json` declares. Repeating site capability in the 402 saves a consumer a round trip and is worth keeping, but the two scopes are not distinguished structurally, and a consumer must not read `accepted_chains` as a set of rails available for the resource at hand. The offer is what `amount`, `currency` and `chain` say it is.

**Rail is declared, but remains optional.** The reference server emits `payment.rail` alongside `chain`, derived from the same branch that selects the payment verifier rather than from a second mapping table. The field is nonetheless optional in the schema, because inferring rail from `chain` — `base` and `ethereum` implying x402, `lightning` implying L402 — is workable and was the only option available before this was implemented. That inference breaks the moment two rails share a settlement network, which MPP settling on an EVM chain would immediately cause, so servers are encouraged to declare rail explicitly and consumers should prefer the declared value where present.

**Payment endpoints should be same-origin.** A server SHOULD declare a `payment.endpoint` on the same origin as the resource being priced. Where a server declares a cross-origin endpoint, it should expect some consumers to decline the offer: an instruction arriving from one origin directing payment to another is indistinguishable, from the consumer's position, from an injected instruction. Operators with a genuine need for a separate payment host — a shared billing service across several properties — should anticipate that this requires explicit configuration on the consumer side rather than working unattended. The same trust boundary appears in a different guise in open question 9.

**Two fields close gaps a consumer cannot close for itself.** `resource`, the absolute URL being priced, is the one piece of a 402 that cannot be reconstructed once the response is separated from the request that produced it — queued, retried, logged, or passed between processes. `payment.expires_at` states how long the offer stands; without it, any consumer that defers a payment is guessing at the validity of what it holds. Both are emitted by the reference server, the latter derived from the same window the `session_nonce` was already bound to rather than from a newly invented lifetime.

Numeric fields in the schema are bounded. This is not pedantry: the values are supplied by the responding origin, and an implausible `source_bytes` fed into a consumer's own cost calculation is a cheap way to manipulate that consumer's spending decision.

### Response Value Signalling

Two related but independent signals let agents make better-informed decisions about a resource, beyond price alone.

**`source_bytes`** — the byte length of the current response's underlying content. This requires no markdown conversion and is available to any server, converted or not: it's simply "how large is this page." Servers **may** include `source_bytes` on any response (200 or 402) as a general-purpose size signal.

**`savings`** — a comparison between a resource's HTML representation and its markdown representation, available only once a server actually performs on-server HTML-to-markdown conversion for that resource. Where `source_bytes` is a standalone fact about the current response, `savings` requires both representations to exist. Servers **may** include a `savings` object in the `402 Payment Required` response body (and optionally on `200`-with-markdown responses) once they have both values in hand, giving agents a concrete efficiency signal alongside price rather than evaluating price in isolation.

Both are optional but recommended, not required — a server is fully MDF-compliant without emitting either. `source_bytes` has the lower implementation bar and may reasonably be adopted first; `savings` is naturally a later addition for servers that already perform conversion. Neither is a pricing mechanism, a coverage claim, or a capability declared in advance in `/mdf.json` — both are computed and disclosed per-response, at request time, exactly like price itself.

**Shape:**

```json
"source_bytes": 48213
```

```json
"savings": {
  "source_bytes": 48213,
  "markdown_bytes": 6104,
  "reduction_pct": 87.3
}
```

- `source_bytes` — byte length of the rendered HTML representation.
- `markdown_bytes` — byte length of the served markdown representation.
- `reduction_pct` — `(1 - markdown_bytes / source_bytes) * 100`, rounded to one decimal place.

When both `source_bytes` and `savings` are present in the same response, `savings.source_bytes` should match the top-level `source_bytes` value — they describe the same measurement, exposed at two levels of detail for convenience.

Byte-size reduction is the primary, defensible metric for `savings`: it is directly measurable from what the server already holds, with no tokenizer assumptions and no dependency on which model or vendor's tokenizer the requesting agent uses. Servers may additionally report an approximate token estimate, but if they do, it must be clearly labelled as a heuristic (e.g. an accompanying `token_estimate_note` describing the method, such as a chars/4 approximation), never presented as an authoritative count — actual token counts vary by tokenizer and cannot be verified for an arbitrary requesting agent.

Implementations should measure `source_bytes` against the same rendered-HTML output the markdown conversion itself was run against (post-filter, post-shortcode-expansion, however the implementation's pipeline works), not raw unrendered source, so the comparison reflects what a human browser or naive scraper would actually receive.

This is not a pricing mechanism. A **server** must not use these values to influence or justify the price it sets — price remains governed entirely by the payment/402 flow described above. The prohibition applies to the server side only: these fields exist precisely so that a requesting agent can judge whether a stated price is worth paying, and consuming them for that purpose is their intended use, not a violation of it.

Neither field is a coverage or capability claim, and neither has any relationship to `/mdf.json`, which continues to assert capability and mechanism only.

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

1. Agent sees `human_only: true` for the requested section in `/mdf.json`, requests the resource, and receives a `402` stating a non-zero price.
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
- **Not dependent on any particular client.** MDF is implemented by servers. A consumer needs only standard HTTP content negotiation to participate. The reference client described in `MCP-GATEWAY.md` is one convenience implementation, not a requirement, and not a gatekeeper.

---

## Reference Implementations

The reference implementation is a self-hostable Docker image (`bitcryptic/mdf-server`) available on Docker Hub. Source is at `bitcryptic-gw/mdf-reference-server`. It:

- Serves markdown natively from a content directory, with HTML rendered dynamically for browser requests
- Auto-generates `/llms.txt` and `/mdf.json` from site configuration
- Handles `Accept: text/markdown` content negotiation
- Integrates x402 payment verification against configurable EVM chains
- Integrates L402 payment verification against a configurable Lightning node or LSP endpoint
- Issues and validates bearer tokens for high-price-tier access
- Exposes a simple dashboard: fetch counts, earnings by rail, content signal summary

Target stack: Bun + Caddy or standalone Bun HTTP server, Docker image for Unraid/standard Docker deployment, configuration via a single `mdf.yaml`.

A hosted demo site is live at **https://mdf-demo.bitcryptic.com**, demonstrating every payment tier end-to-end. The L402 rail settles real Lightning invoices; the x402 rail is stubbed pending on-chain verification.

A reference **client** is at the concept stage: an MCP server that gives any MCP-capable agent runtime the ability to discover `/mdf.json`, negotiate for markdown, evaluate a 402 offer against the token cost of fetching the HTML instead, and pay within an operator-defined budget. The design is documented in `MCP-GATEWAY.md`. It is not built, and MDF does not require a client of any particular shape — see open questions 10 and 11.

---

## Relationship to BitCryptic Compute

MDF's payment layer and content delivery infrastructure align naturally with the BitCryptic Compute vision — a crypto-native infrastructure marketplace. MDF-enabled content delivery nodes are a concrete, deployable use case for that platform: operators run MDF servers, earn micropayments for content served to agents, and the BitCryptic Compute network provides the payment routing and settlement layer.

This positions BitCryptic Compute not only as an AI inference marketplace but as the infrastructure layer for the emerging agent-readable web.

---

## Open Questions

The following are explicitly unresolved and intended to drive community discussion:

1. **Payment rail standardisation** — Should the spec recommend a default rail (x402 on Base? L402 on Lightning?), or remain fully agnostic? Agnosticism is cleaner but creates interoperability friction for agent implementors who must support multiple rails. A third rail, MPP (Machine Payments Protocol, Stripe/Tempo-facilitated session-based settlement), has emerged in the broader 402 ecosystem — MDF's rail-agnostic design accommodates it without spec changes but it is not yet formally in scope for v0.1.

2. **Receipt verification** — How does a site verify payment without running a full node? For x402: trust a third-party RPC, run a light client, or accept signed payment proofs from a settlement layer. For L402: trust an LSP, run a lightweight Lightning node, or verify macaroon credentials independently.

3. **Rate limiting and abuse** — A $0.00 endpoint is still reachable by abusive scrapers. Should MDF include a rate-limit signalling mechanism separate from price? Note that this is only half a server-side problem: a well-behaved consumer enforcing its own per-origin call-rate caps addresses the compliant-agent case without any spec mechanism at all, leaving the spec question narrowed to what a server can usefully signal to consumers that are already inclined to listen. See `MCP-GATEWAY.md` §6 for how one client implementation approaches this, and open question 10 on whether the spec should have anything to say about consumers in the first place.

4. **Update gaming and re-fetch incentives** — The content freshness and subscription model must not create economic incentives for content owners to manipulate change frequency or volume. Two distinct attack vectors exist: (a) *high-frequency trivial changes* — an owner makes constant minor edits to trigger agent re-fetches and repeated payments; (b) *deliberate large rewrites* — an owner makes sweeping content changes to reset the payment clock and justify a full re-fetch fee. Several mitigations are under consideration, none yet adopted as the canonical approach: a *time-window access model* where a paid fetch grants access to all updates within a defined window (e.g. 24 hours), making incremental change gaming economically irrational; a *change significance floor* expressed as a normalised `mdf:significance` score (0.0–1.0, computed server-side via diff) that agents can threshold to ignore low-value updates without fetching or paying; and a *feed-level subscription price* replacing per-fetch update pricing entirely, aligning owner incentives with producing genuinely useful content rather than churn. The time-window model is the current preferred direction for its simplicity and the fact that it makes gaming irrational by design rather than relying on detectable behaviour. Community input is sought before this is committed to the architecture.

   A fourth avenue becomes available once MDF consumers exist in the field, and it is detection rather than prevention. A client maintaining a spend ledger — what it paid, for which resource, at what size, and when — can measure churn directly: per-origin re-fetch frequency against payment frequency, and whether paid re-fetches correlate with substantive change in the returned content. This requires no cooperation from the origin and no spec mechanism whatsoever. Its output is an operator-level decision to reduce or cease spending against an origin, which is a blunt remedy but a real one, and it is measurable by every client that pays. It does not replace the time-window model, which prevents rather than detects. It is noted here as an argument against over-engineering the spec-side mitigation before there is field data on whether gaming actually occurs at meaningful scale.

5. **Markdown dialect** — Should MDF specify a markdown dialect (CommonMark, GFM) or remain agnostic? Agents benefit from predictability; authors benefit from flexibility. In practice every current implementation — the reference server, the demo site, and the WordPress plugin — emits CommonMark, and `/mdf.json` already carries a `formats.dialect` field for sites to declare their choice. The open part of this question is now narrower: should CommonMark be the recommended default with `formats.dialect` as the escape hatch, or should the spec stay fully agnostic and rely on the declaration alone?

6. **Human access to paid content** — If `/premium/*` costs $1.00 per agent fetch, how does a human subscriber access it? MDF should not break human auth flows. Possible answer: price applies only to `Accept: text/markdown` requests; human HTML requests use existing auth (cookies, sessions) independently.

7. **`.well-known/l402-services` alignment** — 402index.io uses this emerging convention for L402 endpoint autodiscovery. MDF's `/mdf.json` serves a richer version of the same purpose. Should MDF sites also publish a `.well-known/l402-services` document for compatibility with the broader L402 ecosystem, or is `/mdf.json` the canonical MDF discovery mechanism and `.well-known` left to implementors who want dual compatibility?

8. **L402 token format compatibility** — 402index.io classifies L402 tokens by format (V2 TLV binary, V1 binary, V0 libmacaroons text, JSON, or unknown) and checks compatibility with the `lnget` client per BLIP-0026. The MDF reference implementation uses an HMAC-bound JSON token — simpler than libmacaroons, no additional dependencies, sufficient for the reference implementation. Whether MDF should specify or recommend a token format for agent ecosystem interoperability is unresolved. A more compatible format could improve out-of-the-box agent support; the current approach prioritises simplicity and auditability.

9. **Broker/alternate content URL extension** — Should `/mdf.json` support declaring an alternate host where a third party serves a site's markdown on its behalf (e.g. a broker or CDN-like intermediary)? Pre-declaring the alternate `content_url` in `/mdf.json` solves *origin* trust (the redirect target is named by the same domain serving the discovery document, inheriting its DNS/TLS trust) but not *content integrity* once the markdown is fetched from the third party. Two non-exclusive approaches are under consideration: the broker signs the markdown payload (or its hash) with a key whose pubkey is pre-declared in `/mdf.json`, reusing the same attested-signing pattern used elsewhere for payment verification — the stronger guarantee, requiring key management on the broker's side; or content-hash pinning, where `/mdf.json` declares a hash of the current content and the agent checks the fetched markdown against it — simpler, but freshness-coupled to the origin keeping the hash current rather than an independent authority. Neither has been adopted; this extension has not been built.

10. **Client conformance and tool selection** — Should MDF define a normative client profile at all? This specification describes publisher behaviour end to end and says nothing about consumers, which was a natural consequence of MDF having been supply-side only. Reference client work has now begun (see `MCP-GATEWAY.md`), which makes the question live — but we are not persuaded that it is the specification's place to constrain consumers, particularly while the only consumer implementation is written by the same authors. A conformance profile authored by the party shipping the sole client is how a community proposal becomes a vendor specification. There is also an unresolved empirical question underneath it: whether an agent runtime will reliably select an MDF-aware fetch tool in preference to its own built-in fetch. That depends on tool descriptions and runtime selection heuristics, not on anything a specification can mandate, and it is untested. Until it is tested, client conformance language would be specifying behaviour for a population that does not yet exist. Deliberately left open.

11. **Spend policy scope** — Budgets, per-call and per-session caps, per-origin rate limits, human confirmation thresholds above a spend threshold, and payment key custody are all necessary for any consumer that spends money autonomously in response to untrusted input. None of them are MDF specification concerns. The specification defines the wire format and the payment flow; how an operator constrains their own agent's spending is an implementation and deployment matter, and MDF should not attempt to standardise it. This is stated explicitly so that the reference client's design decisions in `MCP-GATEWAY.md` are not read as specification extensions. If field experience later shows that some minimal interoperable expression of spend policy is genuinely needed — a way for a server to advertise, say, that it prices per-session rather than per-fetch — that would be a narrow addition arising from evidence, not the general policy framework described in the client document.

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
