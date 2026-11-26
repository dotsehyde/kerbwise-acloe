# Review of Kwesi’s Delivered button

**Request changes.** These five findings block the merge

1. **A handover can disappear before the server confirms it.** `deliver` removes the row before the request finishes. If the response is lost, the courier gets a generic error and loses the row they need to check. A double tap can start another request, and the retry loop sends a fresh timestamp with no idempotency key. Save the handover locally, keep the row visible as **Waiting to sync**, and reuse one key and payload per handover. Retry temporary failures with a delay, respect `Retry-After`, and keep a 409 visible for reconciliation. Test a double tap and a server commit followed by a lost response.

2. **The order total is sent as cash collected.** `deliver(d)` sends `d.amount` for every drop. A courier could receive a different amount and the app would report the total anyway. A prepaid order with a nonzero total should send zero. Use the detail’s payment mode and cash due, require the courier to enter the actual cash, and compare exact pence. Show the expected amount when the server reports a cash mismatch. Test a prepaid drop and an incorrect cash entry.

3. **The route can omit stops or fail to load.** The API caps a page at 25, so `limit=50&page=1` leaves the rest of the route behind. A strict `as double` cast also fails on integer or string amounts, and a missing phone can fail the whole decode. Follow `next` with `after` until it’s null, handle the known response formats, and keep the last complete route visible with a refresh error. Test all 60 rows and a mixed-format later page.

4. **Customer information is exposed in logs and on the list.** `print(res.body)` logs customer names, phone numbers, and addresses. For diagnostics, log the endpoint, status, and item count. Keep the phone number in the delivery detail where the courier needs it to call.

5. **Refreshes can pile up and outlive the screen.** The two-second timer starts another load even if the previous one is pending, and the page has no timer cleanup when it closes. A slow response can overwrite fresher data or call `setState` after disposal. Refresh on user action or app resume, allow one load at a time, and check `mounted` before updating the view. Replace the test’s three-second sleep with a controlled response and verify that leaving the screen during a load is safe.
