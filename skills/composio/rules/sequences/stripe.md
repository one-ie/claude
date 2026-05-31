# Stripe — call sequence

Invoices and payments are multi-step. Never collapse them into one call.

## Send an invoice

1. `STRIPE_CREATE_CUSTOMER` → capture the customer id (`cus_...`).
2. `STRIPE_CREATE_INVOICE` with that customer id → capture the invoice id (`in_...`).
3. Finalize the invoice (the invoice must be finalized before it can be sent).
4. `STRIPE_SEND_INVOICE` with the invoice id.

## Take a direct payment

- `STRIPE_CREATE_PAYMENT_INTENT` with amount + currency + customer id.

## Why the order matters

`STRIPE_CREATE_INVOICE` needs a customer id from `STRIPE_CREATE_CUSTOMER`; `STRIPE_SEND_INVOICE` needs a finalized invoice id. Skipping a step 4xxs.

## Prerequisite

- `stripe` toolkit connected (API key). If not connected, emit a `connect` card instead of calling.
