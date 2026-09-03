# MDF MCP Gateway — Concept

**Status:** Proposal / design sketch
**Date:** 2026-09-03
**Repo:** `bitcryptic-gw/mdf`
**Relates to:** `CONCEPT.md` (negotiation, 402, Response Value Signalling), `mdf-server/` (reference implementation), the llms.txt 402 thread (prooflines.org)

---

## 1. Problem

MDF as specified today is entirely supply-side.

A publisher can implement the whole spec correctly — `/mdf.json` discovery, `Accept: text/markdown` negotiation, `Vary: Accept`, `source_bytes`, a 402 carrying a machine-readable x402 offer — and receive exactly zero MDF traffic. Nothing in any mainstream agent stack knows to look for `/mdf.json` or to negotiate for markdown. Claude, ChatGPT, Perplexity and the rest fetch a URL, get HTML, and run their own client-side extraction.

That demand-side gap cannot be closed by asking model vendors to change their fetch paths. It can be closed by the user, on their own machine, by adding an MCP server.

**The proposal: MDF's reference client is an MCP server.** Not a directory service with a fetch feature — a fetch client with an optional directory.

## 2. Why MCP specifically

MCP is currently the only vendor-neutral surface through which an end user can change what their agent does when it retrieves a URL, without the model vendor's involvement. It is supported by Claude (desktop, Code, API), Opencode, Cline, Continue, and a growing set of agent runtimes. A single MCP server implementation reaches all of them.

This makes the MCP gateway the natural home for the parts of MDF that are inherently client-side:

- deciding whether to negotiate at all
- reading `source_bytes` / `savings` off a 402 and deciding whether paying is worth it
- holding a budget and a payment credential
- caching `/mdf.json` discovery documents
- recording what was spent and what was saved

None of these belong in the spec. All of them are required for the spec to be usable.

### Prior art: 402index.io

`CONCEPT.md` already cites 402index.io in Existing Partial Solutions, and it matters here: 402index is a protocol-agnostic directory of paid endpoints across L402, x402 and MPP which payment-verifies its listings hourly **and already exposes an MCP server for agent discovery**. Anyone familiar with the 402 ecosystem will recognise §5 of this document as territory 402index occupies, and it would be dishonest to present the index idea as novel.

The distinction is one of centre of gravity rather than novelty. 402index is a directory with an MCP interface: its product is the listing, and discovery is what it does. What is proposed here is a fetch client whose directory is optional, local, mirrorable, and never in the path of a request — a gateway that works perfectly well against a URL an agent already holds, with no index consulted at all. The two are complementary, and 402index is the obvious first source for an index feed under §5 rather than a competitor to it.

This also connects to open question 7 in `CONCEPT.md` (`.well-known/l402-services` alignment). If MDF sites publish that document for broader 402-ecosystem compatibility, they become discoverable by 402index without any MDF-specific integration, and the feed problem partly solves itself.

## 3. Tool surface

Three tools. Keep the surface small — MCP tool selection is driven by the model reading tool descriptions, and a large surface dilutes selection.

### `mdf_fetch(url, max_price?)`

The primary tool, and the one that must out-compete the agent's built-in fetch.

1. Resolve `/mdf.json` for the origin (cached, TTL-bounded). If absent, fall through to a plain fetch and return HTML — the tool MUST remain useful on non-MDF sites, or the model will not select it.
2. Request the URL with `Accept: text/markdown`.
3. On `200`: return markdown, plus a savings report derived from `source_bytes`.
4. On `402`: read the payment offer and any `source_bytes` / `savings` fields. Apply the payment policy (§4). Pay and retry, or return the offer to the agent for a decision, or decline and fall back to an unpriced fetch.

Returns content plus a small structured footer: bytes returned, `source_bytes`, estimated tokens saved, amount paid (if any), and remaining session budget.

### `mdf_discover(query | url)`

Answers "is there an MDF endpoint for this, and what does it cost?" without fetching content. Consults, in order: local cache → the local index snapshot (§5) → a live `/mdf.json` probe.

Cheap, side-effect-free, and safe to call speculatively before committing to a paid fetch.

### `mdf_ledger()`

Returns the spend/savings ledger for the current session and rolling window. This is the tool that makes the value proposition legible to the user, and it is also the audit surface — see §6.

## 4. The payment decision — token arbitrage

This is the mechanism that makes "token saver" a literal description rather than a slogan.

The gateway holds a configured input-token price for the agent's own model. On a 402, it has `source_bytes` — the size of the HTML it would otherwise have to fetch and feed into context. It can therefore compute both sides of the trade before spending anything:

```
estimated_saving = (source_bytes - expected_markdown_bytes) / bytes_per_token × input_token_price
auto_pay iff price < estimated_saving × margin
```

Default policy: auto-pay when the price is below a configured fraction of the estimated saving (suggested default `margin = 0.5` — pay at most half of what you save), subject to the caps in §6. Above that, surface the offer to the agent rather than paying silently.

Two consequences worth stating explicitly:

- The pitch to the agent operator is not "support the open web." It is "spend a tenth of a cent to avoid two cents of context." The incentive is immediate and self-interested, which is the only kind that gets adopted.
- This gives publishers a *price signal*. If nobody's gateway ever auto-pays at your price, your price is above the token value of your content, and you will find that out from your 402→paid conversion rate rather than from theory.

Response Value Signalling (`source_bytes`, `savings`) was specified for exactly this decision point. The MCP gateway is the only place in the stack where that decision is actually made. The two were designed independently and fit without modification.

## 5. Discovery — index as accelerator, not dependency

A hosted index is the most obvious feature of this idea and the most dangerous one.

If `mdf_fetch` hard-depends on a registry being reachable, the design has reintroduced a cloud chokepoint, and inherited the ranking problem, the spam problem, and the legitimate question of why any single party decides what is listed.

**Requirements:**

- The gateway MUST work with no index at all. `/mdf.json` at a well-known path is self-discovering; just-in-time negotiation against any URL the agent already has is the base case.
- The index, where used, SHOULD be a signed, mirrorable snapshot — pulled on a schedule and cached locally, not queried live per fetch. A flat file, versioned, with a detached signature. Anyone can mirror it; anyone can publish a competing one; the gateway takes a list of feed URLs.
- Index entries carry discovery and pricing metadata only. They are a hint, never authority — the gateway always verifies against the live `/mdf.json` or the 402 itself before spending.

This keeps the whole stack self-hostable, and keeps the index composable with `llms.txt` rather than competing with it. The prooflines.org thread is a publisher independently asking for the same discovery layer from the other side; a mirrorable feed can be generated from `llms.txt` indexes as easily as from `/mdf.json` crawls.

## 6. Payment and security architecture

Everything in this section describes choices made by *this* implementation. None of it is proposed as an MDF requirement, and `CONCEPT.md` open question 11 states explicitly that spend policy is outside the specification's scope. It is documented in this level of detail because a client that spends money autonomously in response to content fetched from the open internet is a genuinely new risk surface, and other implementors deserve a worked example to argue with rather than a blank page.

This is a tool that spends money in response to content fetched from the open internet. The threat model is prompt injection, and it is not hypothetical: a page can be authored specifically to talk an agent into paying for it repeatedly, or into fetching a thousand priced URLs on an attacker-controlled domain.

**Key custody.** The MCP server holds no signing key. It calls a signer sidecar over a local socket with a policy envelope, in the same shape as `acurast-signer`. The key is file-mounted into the signer only, never present in the gateway's environment or argv, and never visible in `docker inspect`. The gateway refuses to start if the signer is unreachable or the policy file is unset.

**Policy.** This implementation enforces, in the signer rather than the caller:

- per-call maximum
- per-session and per-rolling-window maximum
- per-origin maximum, and a per-origin call-rate cap
- domain allowlist / denylist
- a global kill switch that survives restart

**Human gate above threshold.** This implementation requires two-step confirmation for any single payment above a configured amount, or for any cumulative session spend above a configured amount, rather than permitting it as a single agent-callable operation: the request returns a token and a cooldown, and the confirm completes it. This is the same pattern as `librarian-mcp`'s delete tool, adopted for the same reason: an irreversible action initiated by a model on untrusted input should not be one call.

**Ledger.** Append-only, on disk, one line per decision (paid / declined / gated), with URL, price, `source_bytes`, estimated saving, and policy verdict. This is both the user-facing value report and the forensic record if something goes wrong.

**Input validation.** Payment offers arriving in a 402 body are untrusted input: validate against a schema, bound all numeric fields, reject unknown payment schemes rather than attempting them, and never follow a payment endpoint on a different origin from the resource without explicit policy allowance.

## 7. Telemetry — the strategic argument

MDF's adoption case currently rests on third-party estimates of agentic traffic share. A deployed gateway produces first-party numbers instead: real agent fetch volume, measured byte and token savings per fetch, 402→paid conversion rates, and price sensitivity by content category.

That data is the only evidence that will move publishers, and it is a byproduct of the tool rather than a separate effort. It SHOULD be opt-in, aggregate-only, and self-hostable like everything else — a gateway operator can point telemetry at their own collector or at nothing.

## 8. The claim that needs hardening

`CONCEPT.md` now scopes this claim properly in its Problem section, and the client's job is to substantiate it empirically rather than restate it. The short version: "markdown is more token-efficient than HTML" holds against raw HTML and against boilerplate-heavy pages even after client-side extraction, but approaches zero on already-clean documentation. Stated without qualification, the 402 asks an agent to pay for something it may believe it already has.

The gateway is the only component positioned to settle this with data rather than argument, because it sees both representations:

1. **Wire and context both.** Server-side conversion means boilerplate never crosses the wire *or* enters the context window. Client-side extraction pays the download cost regardless.
2. **Semantic authority.** The publisher decides what the content is. Navigation, advertising, consent banners and related-article rails are absent by construction, not by heuristic.
3. **Extraction reliability.** JS-rendered content, malformed tables, and paginated bodies are where client-side extraction silently degrades or fails. A canonical markdown representation removes that failure class.

The paid tier is therefore buying quality and determinism, not merely bytes. The gateway's ledger is what turns that from an assertion into a measurement — it can record both representations' sizes and, where the fetch is unpriced, compare its own extraction against the served markdown.

## 9. Non-goals

- Not a search engine. `mdf_discover` resolves known resources; it does not rank the web.
- Not a payment processor. Settlement is x402 / L402 as already specified; the gateway is a client.
- Not a hosted service. The reference implementation is a container the user runs.
- Not a replacement for `llms.txt`. Complementary — freetext discovery versus structured negotiation, as argued in the prooflines.org thread.

## 10. Open questions

1. **Tool-selection competition.** The model must prefer `mdf_fetch` over its built-in fetch. How much of that is tool description wording, and does it hold across Claude / Opencode / Cline? Needs empirical testing before anything else is worth building.
2. **`expected_markdown_bytes` on a 402.** The arbitrage calculation needs an estimate of the markdown size, but `savings` is optional and conversion-dependent. Fall back to a global compression ratio prior, or refuse to auto-pay without `savings`? A learned per-origin ratio from the ledger is a third option.
3. **Index feed format.** Reuse `mdf.json`'s schema as a repeated record, define a separate feed schema, or emit an `llms.txt`-compatible form with structured trailing notes?
4. **Signer reuse.** Does `acurast-signer` generalise to an x402/L402 policy signer, or is this a second sidecar sharing a pattern rather than code?
5. **Caching and revalidation.** Paid content is cached — for how long, keyed how, and does a cache hit on paid content constitute a second use the publisher priced for? Interacts with the Update Gaming open item (spec #4).
6. **Multi-agent budgets.** With per-agent identities already in use elsewhere in the stack, should budgets be per-agent-identity rather than per-gateway?

## 11. Suggested next step

Question 1 gates everything else. Build the smallest possible `mdf_fetch` — negotiation and 200-path only, no payment, no index, no signer — point it at the live `mdf-server` demo, and measure whether Claude Code and Opencode actually select it over their native fetch, and under which tool descriptions. If they do not, the payment architecture is moot; if they do, the rest of this document is the build order.
