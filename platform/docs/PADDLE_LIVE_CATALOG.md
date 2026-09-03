# Paddle Live catalog

The current production catalog was promoted in the AXIO7 Paddle Live account
on 2026-07-28.

- Base currency: USD
- Automatic currency conversion: Paddle-localized checkout totals
- Country price overrides: none
- Trials: none; recurring subscriptions charge immediately
- Free and Pro: recurring monthly collection
- Annual: recurring yearly collection
- Pro and Annual renew automatically; Free remains read-only

| Plan | Product ID | Billing | Price | Active price ID |
| --- | --- | --- | ---: | --- |
| Free | `pro_01kymjkn4ajyfn0thc3jdv1wry` | Monthly recurring | $0 | `pri_01kymjn5cde81z68cfjrcnptpp` |
| Pro | `pro_01ky5d3gphpv2q8fz10a6ycq0f` | Monthly recurring | $69 | `pri_01kymjjgjdhp86hatg9yx41fp1` |
| Annual | `pro_01kymjp3gnmb6mnv0qc4nxxn98` | Yearly recurring | $699 | `pri_01kymjrawnh203mkhzz9d3sn08` |

These products, prices, and their historical predecessors are permanent
production infrastructure. Do not archive or delete them as test cleanup.
The runtime maps each button to the exact allow-listed Price ID above, creates
the transaction server-side, opens Paddle Checkout, and grants access only
after verified Paddle fulfillment.

The former Starter, Pro $149, and Lifetime entities remain active only for
historical reconciliation and existing-customer access. They are not public
purchase choices and must not be deleted or archived.
