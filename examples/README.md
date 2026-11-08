# 402, paid-response and `/mdf.json` examples

Complete, schema-valid examples for MDF 0.3.0. Each one is written against
x402 v2 at `x402-foundation/x402` commit `513dd66d2b3eb2388065f9923d81aa496e626082`
(2026-11-06).

> **Every value here is fabricated.** The addresses, public key, invoice,
> request hash, payment hash and transaction hash are placeholders chosen to be
> obviously fake and are not payable, resolvable or attributable to anyone. The
> service name and URLs use `example.com`, which is reserved for documentation.
> The invoice is not a decodable BOLT11 string.

| File | What it is |
|---|---|
| `402-usdc-base-mainnet.json` | A USDC-only `402 Payment Required` body: x402 `exact` on Base mainnet (`eip155:8453`). Deliberately has **no** `expires_at`, showing that member is optional. |
| `402-dual-rail-usdc-lightning.json` | A dual-rail 402: USDC on Base mainnet plus BTC over Lightning (`exact` on `lnbtc:000000000019d6689c085ae165831e93`). Carries `expires_at`. |
| `mdf-dual-rail.json` | The `/mdf.json` for the same site. Its `/micropayment/*` price entry declares exactly the two rails the dual-rail 402 offers, at the same amounts on the same networks. Priced entirely `per_fetch`, so it has **no** `payment` or `auth` block. |
| `mdf-token-tier.json` | A `/mdf.json` with a token-access section: `/private/**` carries `"access": "token"` and the document declares `auth.endpoint`. |
| `200-paid-usdc-base-mainnet.json` | The decoded `PAYMENT-RESPONSE` header of a paid 200 on the EVM rail (an x402 v2 `SettlementResponse`). |
| `200-paid-lnbtc.json` | The decoded `PAYMENT-RESPONSE` header of a paid 200 on the Lightning rail. `payer` is absent, as the lnbtc scheme requires. |

The site's declared price for a resource and the offer it emits are tied
together normatively: the `accepts[]` entries a server sends MUST correspond
one-to-one to the rails `/mdf.json` declares for that path, with identical
`scheme`, `network`, `asset` and `amount`, minus any degraded rail. These files
are the worked version of that rule — `mdf-dual-rail.json`'s
`/micropayment/*` rails (1000 micro-USDC on `eip155:8453`, 1000 millisatoshis on
`lnbtc:…`) are the two entries in `402-dual-rail-usdc-lightning.json`.

## How each is carried on the wire

A 402 sends the **same** object twice: as the response body, and base64-encoded
in the `PAYMENT-REQUIRED` header. The examples are stored as the JSON object;
the header value is that file's bytes, base64-encoded:

```bash
base64 -i examples/402-usdc-base-mainnet.json | tr -d '\n'
```

A conformant response therefore looks like:

```http
HTTP/1.1 402 Payment Required
Content-Type: application/json; charset=utf-8
Cache-Control: no-store
X-MDF-Version: 1
PAYMENT-REQUIRED: <base64 of the body below>

{ ...the body... }
```

A paid 200 carries the decoded `PAYMENT-RESPONSE` example base64-encoded in the
`PAYMENT-RESPONSE` header, alongside the negotiated markdown:

```http
HTTP/1.1 200 OK
Content-Type: text/markdown; charset=utf-8
Cache-Control: private, no-store
X-MDF-Version: 1
PAYMENT-RESPONSE: <base64 of 200-paid-usdc-base-mainnet.json or 200-paid-lnbtc.json>

# Premium deep-dive
...
```

## Validation

In a scratch directory, outside this repo:

```bash
npm init -y && npm install ajv@8 ajv-formats@3 @x402/core@2.30.0
```

Then (reproduced in full so the recorded output is reproducible; `$MDF` is the
path to this repo):

```bash
MDF=/path/to/mdf node --input-type=module -e '
import { readFileSync } from "node:fs";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { isPaymentRequiredV2 } from "@x402/core/schemas";
const root = process.env.MDF;
const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);
const v402 = ajv.compile(JSON.parse(readFileSync(`${root}/mdf-402.schema.json`, "utf8")));
const vmdf = ajv.compile(JSON.parse(readFileSync(`${root}/mdf.schema.json`, "utf8")));
const read = (p) => JSON.parse(readFileSync(`${root}/${p}`, "utf8"));
const ok = (c, l) => console.log((c ? "PASS  " : "FAIL  ") + l);
const USDC = { scheme: "exact", network: "eip155:8453", asset: "0x1111111111111111111111111111111111111111", amount: "100" };
const site = (extra) => ({ mdf_version: "0.3.0", site: "https://example.com", pricing: { default: { rails: [USDC] } }, ...extra });

for (const f of ["402-usdc-base-mainnet.json", "402-dual-rail-usdc-lightning.json"]) {
  const d = read(`examples/${f}`);
  ok(v402(d), f + " mdf-402");
  ok(isPaymentRequiredV2(d), f + " x402 isPaymentRequiredV2");
  const rt = JSON.stringify(JSON.parse(Buffer.from(Buffer.from(JSON.stringify(d)).toString("base64"), "base64").toString("utf8"))) === JSON.stringify(d);
  ok(rt, f + " body==header round trip");
}
const bazaar = read("examples/402-dual-rail-usdc-lightning.json");
bazaar.extensions.bazaar = { info: { name: "example" }, schema: { type: "object" } };
ok(v402(bazaar), "control: extra extension key alongside mdf");
ok(v402(read("examples/402-usdc-base-mainnet.json")), "control: 402 without expires_at");

ok(vmdf(read("examples/mdf-dual-rail.json")), "mdf-dual-rail.json (per_fetch only, no payment/auth)");
ok(vmdf(read("examples/mdf-token-tier.json")), "mdf-token-tier.json (token section + auth.endpoint)");
for (const ex of JSON.parse(readFileSync(`${root}/mdf.schema.json`, "utf8")).examples) ok(vmdf(ex), "mdf.schema.json own example");
ok(vmdf(site({})), "control: priced per_fetch site, no payment/auth block");
ok(vmdf(site({ auth: { endpoint: "https://example.com/mdf/auth" }, pricing: { default: { rails: [USDC], access: "token" } } })), "control: token default + auth.endpoint");

const tokenNoAuth = site({ pricing: { default: { rails: [USDC] }, sections: { "/private/**": { rails: [USDC], access: "token" } } } });
ok(!vmdf(tokenNoAuth), "rejected: token section without auth.endpoint");
const tokenNoEndpoint = site({ auth: { token_ttl_seconds: 86400 }, pricing: { default: { rails: [USDC] }, sections: { "/private/**": { rails: [USDC], access: "token" } } } });
ok(!vmdf(tokenNoEndpoint), "rejected: token section, auth without endpoint");
const tokenEmpty = site({ auth: { endpoint: "https://example.com/mdf/auth" }, pricing: { default: { rails: [USDC] }, sections: { "/private/**": { rails: [], access: "token" } } } });
ok(!vmdf(tokenEmpty), "rejected: access token with an empty rail list");
ok(!vmdf(site({ pricing: { default: { rails: [USDC], access: "subscription" } } })), "rejected: unknown access value");
ok(!vmdf(site({ auth: { endpoint: "https://example.com/mdf/auth", price_threshold: "10.00" } })), "rejected: leftover auth.price_threshold");
ok(!vmdf(site({ payment: { accepted_networks: ["eip155:8453"] } })), "rejected: leftover accepted_networks");
ok(!vmdf(site({ payment: { accepted_currencies: ["USDC"] } })), "rejected: leftover accepted_currencies");
ok(!vmdf(site({ payment: { wallet: "0x3333333333333333333333333333333333333333" } })), "rejected: leftover wallet");
ok(!vmdf(site({ payment: { endpoint: "https://example.com/mdf/pay" } })), "rejected: leftover payment object");
'
```

Recorded output (2026-11-08, revision 2):

```text
PASS  402-usdc-base-mainnet.json mdf-402
PASS  402-usdc-base-mainnet.json x402 isPaymentRequiredV2
PASS  402-usdc-base-mainnet.json body==header round trip
PASS  402-dual-rail-usdc-lightning.json mdf-402
PASS  402-dual-rail-usdc-lightning.json x402 isPaymentRequiredV2
PASS  402-dual-rail-usdc-lightning.json body==header round trip
PASS  control: extra extension key alongside mdf
PASS  control: 402 without expires_at
PASS  mdf-dual-rail.json (per_fetch only, no payment/auth)
PASS  mdf-token-tier.json (token section + auth.endpoint)
PASS  mdf.schema.json own example
PASS  control: priced per_fetch site, no payment/auth block
PASS  control: token default + auth.endpoint
PASS  rejected: token section without auth.endpoint
PASS  rejected: token section, auth without endpoint
PASS  rejected: access token with an empty rail list
PASS  rejected: unknown access value
PASS  rejected: leftover auth.price_threshold
PASS  rejected: leftover accepted_networks
PASS  rejected: leftover accepted_currencies
PASS  rejected: leftover wallet
PASS  rejected: leftover payment object
```

A longer run of the same harness adds the earlier controls (0.2 price entry,
old `accepted_chains` key, chain name as a rail network, zero-priced rail,
decimal rail amount) and the nine 402 negative controls below; all reject.

`npx ajv-cli` is not usable here: its `-c ajv-formats` hook cannot resolve the
format plugin from the npx sandbox, so the script above is the procedure.

### 402 negative controls

All rejected by `mdf-402.schema.json`: a v1 `payment` envelope with a string
`resource`; `x402Version: 1`; a chain-name `network` (`base`); a decimal
`amount`; an `lnbtc` entry with `asset: "USDC"`; an `lnbtc` entry missing
`extra.paymentFlow`; a missing `extensions.mdf`; an empty `accepts`; and a
top-level `source_bytes`.

### `mdf.json` controls

Positive: `mdf-dual-rail.json` (priced, no `payment`/`auth`); `mdf-token-tier.json`
(token section, `auth.endpoint` present); the schema's own example; a priced
`per_fetch` site with neither block; a document-level `access: "token"` with
`auth.endpoint`.

Negative: a `token` section without `auth.endpoint`; a `token` section whose
`auth` has no `endpoint`; `access: "token"` with an empty rail list; an unknown
`access` value; leftover `auth.price_threshold`, `payment.accepted_networks`,
`payment.accepted_currencies`, `payment.wallet` or `payment` itself; a 0.2
price entry (`amount`/`currency`/`chain`); the old `accepted_chains` key; a
chain name as a rail network; a zero-priced rail; a decimal rail amount.

### Paid-response examples

Checked against the `SettlementResponse` field table in
`specs/x402-specification-v2.md` §5.3. Upstream publishes no runtime schema for
`SettlementResponse` at the pinned commit — `typescript/packages/core/src/schemas/index.ts`
covers `PaymentRequired`, `PaymentRequirements` and `PaymentPayload` only — so
there is nothing more machine-checkable to run against them.
