# Courier API v1 (notes from the platform)

Run the mock with `node courier-server.js` (Node 18 or newer, no packages). It listens on port 4000 and keeps its data in memory, so restart it to reset. From an Android emulator, the computer running it is at `10.0.2.2`.

- **Step 1:** `node courier-server.js` is the calm system that these notes describe.
- **Step 2:** `node courier-server.js --real` behaves like the live platform on a busy day.

Every request needs the header `Authorization: Bearer courier-demo-token`. Without it the API answers 401. Responses are JSON. Times are ISO 8601 with a time zone. Money is in pounds (GBP).

To see how your app behaves with no signal, stop the mock while the app is running.

## GET /deliveries

Query: `status` (optional: assigned, out, delivered), `after` (the `next` from the last answer) and `limit` (default 20, at most 25).

Returns `{ "items": [Delivery], "next": 25 }`. `next` is null on the last page.

## GET /deliveries/:id

Returns one Delivery with two extra fields, `cashDue` and `notes`, or 404.

## Delivery

| field | type | notes |
|---|---|---|
| id | integer | |
| customerName | string | |
| phone | string | the customer's number |
| address | object | `line1`, `area`, and `landmark` when we have one |
| items | integer | number of items in the parcel |
| amount | number | order total in pounds, up to 2 decimals |
| currency | string | always `GBP` |
| paymentMode | string | `cash` (the courier collects the money at the door) or `paid` (already paid online) |
| status | string | `assigned`, `out` or `delivered` |
| scheduledAt | string | when it is due |
| channel | string | `website` or `instagram` |

## POST /deliveries/:id/complete

Marks a delivery delivered. Body: `{ "cashCollected": number, "deliveredAt": string (optional), "note": string (optional) }`.

`cashCollected` must equal the amount for a `cash` delivery and 0 for a `paid` one. If it does not, the answer is 422 with `{ "code": "cash_mismatch", "expected": number }`.

`deliveredAt` is the time the courier handed over the parcel. If you leave it out, we use the time we received the request.

Answers:

- 200 `{ "id", "status": "delivered", "deliveredAt", "receivedAt" }`
- 404 unknown delivery
- 409 conflict
- 422 the request is not valid
- 429 too many requests
- 503 try again later

Send an `Idempotency-Key` header to make a repeated request safe. We keep keys for 24 hours.
