# QuickBooks — call sequence

A customer must exist before an invoice can reference it.

## Create an invoice

1. `QUICKBOOKS_CREATE_CUSTOMER` → capture the customer ref id.
2. `QUICKBOOKS_CREATE_INVOICE` with that customer ref.

## Why the order matters

`QUICKBOOKS_CREATE_INVOICE` requires an existing customer ref. Create the customer first (or look one up), then invoice.

## Prerequisite

- `quickbooks` toolkit connected (OAuth2). If not connected, emit a `connect` card instead of calling.
