# Gmail — call sequence

Reply in-thread instead of sending a new message, to avoid duplicate/disconnected emails.

## Reply to an existing thread

1. `GMAIL_FETCH_EMAILS` with a query (`{"max_results":1,"query":"..."}`) → capture the `threadId` / message id.
2. `GMAIL_REPLY_TO_THREAD` with that thread id and the reply body.

## Send a brand-new email

- `GMAIL_SEND_EMAIL` directly (no thread context needed).

## Why the order matters

Using `GMAIL_SEND_EMAIL` to answer an existing conversation breaks threading and can duplicate a send. Fetch the thread first, then reply.

## Prerequisite

- `gmail` toolkit connected (OAuth2). If not connected, emit a `connect` card instead of calling.
