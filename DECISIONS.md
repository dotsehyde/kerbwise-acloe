# Step 2 decisions

## What I found

- The Step 1 build showed **Couldn’t load deliveries** in real mode. Page two included string prices such as `"110.00"`, where the app expected numbers. The list also contained deliveries scheduled yesterday and tomorrow, zone-less Instagram times, and a `failed` status. Some detail responses had `phone: null`.
- Delivery #7 returned 503 during completion attempts. For #33, the first completion request timed out, a subsequent read showed it as delivered, and replaying the original key returned the original acknowledgement. A timeout alone cannot establish whether a handover reached the server.
- The existing app cleared its visible route on a failed refresh. Completion retries depended on memory, so closing the app could lose the recorded cash and the key needed to retry safely. The [courier log](docs/courier-log.txt) also shows how repeated 409s and removing a row left a handover unresolved.

## What I chose to fix

| Risk | Decision |
| --- | --- |
| A completed handover disappears in a dead zone | Save the delivery ID, exact cash in pence, a stable idempotency key, and sync state in app-private storage before sending. Show **Waiting to sync** until the server acknowledges that delivery. A failed local write keeps the action available and sends no request. |
| A retry records cash twice or changes the amount | Replay the same body and key. Timeouts and 503s remain pending. A 429 pauses the queue using `Retry-After` when supplied. Terminal responses such as 409 keep the original amount visible under **Needs review**. An explicit cash mismatch can be corrected only by entering the verified amount again. |
| A key expires while the phone is offline | Use the API’s HTTP `Date` and a monotonic elapsed clock. After a restart, obtain server time before replaying. Require office review after 23 hours, leaving a buffer inside the stated 24-hour retention window. |
| A bad record or page makes work disappear | Accept exact GBP amounts as numbers or decimal strings. Use the cursor returned by the server and deduplicate by delivery ID. Preserve the last complete route after a failed refresh. Keep failed or unfamiliar statuses visible and direct the courier to the office. |
| A wrong handset date hides a stop | Use the server’s date in Europe/London, interpret zone-less timestamps as London wall time, and label earlier and upcoming deliveries separately. Keep those deliveries accessible until Operations confirms the cutoff policy. |
| Offline cash comes from an old or incomplete record | Prefer the last fetched detail. Fall back to the previously loaded summary, where the documented cash due equals the order total for cash deliveries. If the cached detail and summary disagree on payment or eligibility, ask the courier to check with the office. Missing phone numbers leave the address and handover available. |

## What I deferred

- I kept addresses, phone numbers, and delivery notes in memory. After a cold offline start, saved handovers remain available by delivery ID, and the route loads when the API returns. A persistent offline route would need an agreed retention and device-loss policy.
- Retry runs while the app is in use and when it returns to the foreground. OS background jobs and persistent rate-limit deadlines across process restarts can follow once the platform confirms its limits.
- I use the server’s receipt time for synced handovers. Recording a separate, auditable doorstep time needs a policy for devices with wrong clocks.
- Maps, notifications, iPhone support, and a customer-absent workflow remain outside this pass.

## What I would ask Kerbwise

- **Hannah** — What evidence does Finance need to reconcile a cash handover when the API reports a conflict? Who can approve a correction after a courier has already left the customer?
- **Marcus** — Which overdue jobs should remain on today’s route, and can a courier hand over an upcoming job early? What should they do when they cannot reach the customer or the cash at the door differs from the app?
- **Tomasz** — Can the API guarantee London time for zone-less orders, stable cursors and IDs, and a lookup that returns the completion receipt by idempotency key? How should the app report and resolve expired keys, and what customer data can stay on a lost or shared device?

## Verification

On the Android emulator, I scrolled through the real-mode route and opened #60, opened a delivery with a missing number, completed prepaid #6, and watched #33 recover automatically after its acknowledgement timed out. With the server stopped, I refreshed the route, checked that £109.99 was rejected for #31, and saved £110.00. The saved handover survived an offline app restart and synced when the real-mode server returned.
