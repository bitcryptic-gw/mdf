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
| `mdf-dual-rail.json` | The `/mdf.json` for the same site. Its `/micropayment/*` price entry declares exactly the two rails the dual-rail 402 offers, at the same amounts on the same networks. |
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

Then (the script is reproduced here in full so the recorded output is
reproducible; `$MDF` is the path to this repo):

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

for (const f of ["402-usdc-base-mainnet.json", "402-dual-rail-usdc-lightning.json"]) {
  const d = read(`examples/${f}`);
  ok(v402(d), f + " mdf-402");
  ok(isPaymentRequiredV2(d), f + " x402 isPaymentRequiredV2");
  const rt = JSON.stringify(JSON.parse(Buffer.from(Buffer.from(JSON.stringify(d)).toString("base64"), "base64").toString("utf8"))) === JSON.stringify(d);
  ok(rt, f + " body==header round trip");
}

// positive controls
const bazaar = read("examples/402-dual-rail-usdc-lightning.json");
bazaar.extensions.bazaar = { info: { name: "example" }, schema: { type: "object" } };
ok(v402(bazaar), "extra extension key alongside mdf");
ok(v402(read("examples/402-usdc-base-mainnet.json")), "402 without expires_at");

// mdf.json
ok(vmdf(read("examples/mdf-dual-rail.json")), "mdf-dual-rail.json mdf.schema");
for (const ex of JSON.parse(readFileSync(`${root}/mdf.schema.json`, "utf8")).examples) ok(vmdf(ex), "mdf.schema.json own example");

// negative controls
const v1 = { mdf_version: "0.2.0", site: "https://example.com", pricing: { default: { amount: "0.0001", currency: "USDC", chain: "base" } }, payment: { accepted_chains: ["base"], accepted_currencies: ["USDC"] } };
ok(!vmdf(v1), "rejected: 0.2 price entry (amount/currency/chain)");
const renamed = { mdf_version: "0.3.0", site: "https://example.com", pricing: { default: { rails: [] } }, payment: { accepted_chains: ["eip155:8453"], accepted_currencies: ["USDC"] } };
ok(!vmdf(renamed), "rejected: old accepted_chains key");
const zero = { mdf_version: "0.3.0", site: "https://example.com", pricing: { default: { rails: [{ scheme: "exact", network: "eip155:8453", asset: "0x1111111111111111111111111111111111111111", amount: "0" }] } }, payment: { accepted_networks: ["eip155:8453"], accepted_currencies: ["USDC"] } };
ok(!vmdf(zero), "rejected: zero-priced rail");
'
```

Recorded output (2026-11-08, revision 1):

```text
PASS  402-usdc-base-mainnet.json mdf-402
PASS  402-usdc-base-mainnet.json x402 isPaymentRequiredV2
PASS  402-usdc-base-mainnet.json body==header round trip
PASS  402-dual-rail-usdc-lightning.json mdf-402
PASS  402-dual-rail-usdc-lightning.json x402 isPaymentRequiredV2
PASS  402-dual-rail-usdc-lightning.json body==header round trip
PASS  extra extension key alongside mdf
PASS  402 without expires_at
PASS  mdf-dual-rail.json mdf.schema
PASS  mdf.schema.json own example
PASS  rejected: 0.2 price entry (amount/currency/chain)
PASS  rejected: old accepted_chains key
PASS  rejected: zero-priced rail
```

A longer run of the same harness adds one further `mdf.json` control (a chain
name used as a rail network) and the nine 402 negative controls below; all
reject.

`npx ajv-cli` is not usable here: its `-c ajv-formats` hook cannot resolve the
format plugin from the npx sandbox, so the script above is the procedure.

### 402 negative controls

All rejected by `mdf-402.schema.json`: a v1 `payment` envelope with a string
`resource`; `x402Version: 1`; a chain-name `network` (`base`); a decimal
`amount`; an `lnbtc` entry with `asset: "USDC"`; an `lnbtc` entry missing
`extra.paymentFlow`; a missing `extensions.mdf`; an empty `accepts`; and a
top-level `source_bytes`.

### `mdf.json` controls

Positive: `mdf-dual-rail.json`; the schema's own example.

Negative: a 0.2 shape with a section-level single `amount`/`currency`/`chain`
(no `rails`); the old `accepted_chains` key; a chain name used as a rail
network; a zero-priced rail (an unpriced path is `"rails": []`).

### Paid-response examples

Checked against the `SettlementResponse` field table in
`specs/x402-specification-v2.md` §5.3. Upstream publishes no runtime schema for
`SettlementResponse` at the pinned commit — `typescript/packages/core/src/schemas/index.ts`
covers `PaymentRequired`, `PaymentRequirements` and `PaymentPayload` only — so
there is nothing more machine-checkable to run against them.
