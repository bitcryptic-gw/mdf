# 402 and paid-response examples

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
| `402-usdc-base-mainnet.json` | A USDC-only `402 Payment Required` body: x402 `exact` on Base mainnet (`eip155:8453`). |
| `402-dual-rail-usdc-lightning.json` | A dual-rail 402: USDC on Base mainnet plus BTC over Lightning (`exact` on `lnbtc:000000000019d6689c085ae165831e93`). |
| `200-paid-usdc-base-mainnet.json` | The decoded `PAYMENT-RESPONSE` header of a paid 200 on the EVM rail (an x402 v2 `SettlementResponse`). |
| `200-paid-lnbtc.json` | The decoded `PAYMENT-RESPONSE` header of a paid 200 on the Lightning rail. `payer` is absent, as the lnbtc scheme requires. |

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

The 402 examples validate against both the MDF schema and the published x402 v2
runtime schema. In a scratch directory, outside this repo:

```bash
npm init -y && npm install ajv@8 ajv-formats@3 @x402/core@2.30.0

MDF=/path/to/mdf node --input-type=module -e '
import { readFileSync } from "node:fs";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { isPaymentRequiredV2 } from "@x402/core/schemas";
const root = process.env.MDF;
const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);
const validate = ajv.compile(JSON.parse(readFileSync(`${root}/mdf-402.schema.json`, "utf8")));
for (const f of ["402-usdc-base-mainnet.json", "402-dual-rail-usdc-lightning.json"]) {
  const doc = JSON.parse(readFileSync(`${root}/examples/${f}`, "utf8"));
  console.log(f, "mdf-schema:", validate(doc) ? "PASS" : "FAIL",
              "| x402 isPaymentRequiredV2:", isPaymentRequiredV2(doc) ? "PASS" : "FAIL");
}'
```

Recorded output (2026-11-08):

```text
402-usdc-base-mainnet.json mdf-schema: PASS | x402 isPaymentRequiredV2: PASS
402-dual-rail-usdc-lightning.json mdf-schema: PASS | x402 isPaymentRequiredV2: PASS
```

`npx ajv-cli` is not usable here: its `-c ajv-formats` hook cannot resolve the
format plugin from the npx sandbox, so the script above is the checked-in
procedure.

Negative controls, confirming the MDF schema actually rejects the shapes 0.2.x
produced (all rejected): a v1 `payment` envelope with a string `resource`,
`x402Version: 1`, a chain-name `network` (`base`), a decimal `amount`, an
`lnbtc` entry with `asset: "USDC"`, an `lnbtc` entry missing `extra.paymentFlow`,
a missing `extensions.mdf`, an empty `accepts`, and a top-level `source_bytes`.

The paid-response examples are checked
against the `SettlementResponse` field table in
`specs/x402-specification-v2.md` §5.3; upstream publishes no runtime schema for
`SettlementResponse` at the pinned commit — `typescript/packages/core/src/schemas/index.ts`
covers `PaymentRequired`, `PaymentRequirements` and `PaymentPayload` only — so
there is nothing more machine-checkable to run against them.

`AJV` needs `ajv-formats` for the `date-time`/`uri` annotations; the `pattern`
on each field is the load-bearing constraint, not `format`.
