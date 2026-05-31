# LinkedIn — call sequence

LinkedIn posting requires the author URN first. Always follow this order.

## Post to a personal profile

1. `LINKEDIN_GET_MY_INFO` → capture the author URN from the response (`author` / `id` field).
2. `LINKEDIN_CREATE_LINKED_IN_POST` with that URN as the author and the post text.
3. If step 2 fails with an author/permission error → fall back to `LINKEDIN_CREATE_ARTICLE_OR_URL_SHARE`.

## Why the order matters

`LINKEDIN_CREATE_LINKED_IN_POST` cannot infer the author — it requires the URN returned by `LINKEDIN_GET_MY_INFO`. Calling it first hallucinates an author and 4xxs.

## Prerequisite

- `linkedin` toolkit connected (OAuth2). If not connected, emit a `connect` card instead of calling.
