---
name: directory-autofill
description: Fill directory-submission forms in the operator's own Chrome via claude-in-chrome, one queued row at a time, with the human approving every submit. Use whenever an operator says "file with agent", "file these directories", "run the directory autofill", or opens the File-with-agent door on the /u/[slug]/directories board. Never clicks submit, never solves a challenge, always stamps filedBy — see HARD RULES.
---

# directory-autofill — the browser hand for directory submissions

**Purpose:** Turn a run's queued directory rows into filled, human-approved submissions inside the operator's own logged-in Chrome, using the `claude-in-chrome` MCP tools — `tabs_create_mcp` / `navigate` to open the submit page, `read_page` + `find` to locate inputs, `form_input` to fill them, `computer` for a screenshot (there is no `screenshot` tool; screenshots are a `computer` action). Design + data model: `text/directory-submission-plan.md` § The browser hand. The one page this drives: `/u/[slug]/directories`.

## HARD RULES

- **The human owns the submit.** This skill fills a form and stops. It never clicks the directory's submit button, never confirms a modal that finalizes a listing, and never creates an account on the operator's behalf. The operator reviews the filled form and approves the submit themselves.
- **Never solves a challenge.** Captcha, email verification, phone verification, or any anti-bot step hands control straight back to the human — this skill does not attempt to defeat them. Resume the loop on the next queued row once the human clears it (or skip and move on).
- **Provenance always.** Every `POST /api/directories/update` call this skill makes carries `filedBy: "agent"`. If a human takes over mid-fill and finishes the submit themselves, the row is recorded `filedBy: "human"` instead — never claim agent credit for a human-finished row.
- **One generic matcher, zero per-site scripts.** The `DirectoryField` key set is closed — seven shared templates in `registry.ts` (`F_LOCAL`, `F_REVIEW`, `F_B2B`, `F_STARTUP`, `F_AITOOL`, `F_EMAIL`, `F_VERTICAL`) supply every key, and no directory declares fields inline — and packs are deterministic; the only judgment this skill exercises is "which input on this page is *phone*", via label/placeholder/autocomplete-attribute matching. All 306 directories share this one code path. A site that defeats matching gets filed by hand instead — never write a bespoke per-site scraper.
- **No stored credentials.** Auth to `/api/directories/*` rides the operator's own session, the same way other operator-side skills call the ONE API (`cc-connect`/do-signal pattern). This skill holds no secrets of its own and never asks for or stores a directory's login.
- **Watched, paced batches.** Work 10–20 queued rows per sitting, not the whole run unattended — the desktop session is the throttle. Directory sites are exactly the sites with captchas and bot detection; a human present in their own browser dissolves both without evading anything.

## The loop

```
GET /api/directories/run?slug=<slug>&runId=<runId>
        │  read the frozen packs for queued rows (batch 10–20)
        ▼
open directory.submitUrl in a new Chrome tab
        ▼
read the page, match each pack.fields[key] onto the
  closest form input by label / placeholder / autocomplete
        ▼
human checkpoint — the operator reviews the filled
  form and clicks/approves the actual submit
        ▼
capture evidence: confirmation text, listing URL if
  shown, a screenshot
        ▼
POST /api/directories/update
  { slug, id, status: "submitted", filedBy: "agent" }
  (and, once the listing appears, a later
   { status: "live", listingUrl } call — evidence, not
   assertion, per the status walk)
        ▼
next queued row · challenge encountered → hand to the
  human, resume the loop once cleared (or move on)
```

## Steps

1. **Get the run.** Ask the operator (or read from the board context) which workspace `slug` and `runId` to work. `GET /api/directories/run?slug=<slug>&runId=<runId>` returns `{ submissions: [{ id, directorySlug, status, pack, listingUrl }] }`, where `pack` is the frozen `{ fields, missing }`. Keep each row's `id` — it is the handle every `update` call needs. Only act on rows with `status: "queued"`.
2. **Look up the directory.** Cross-reference `directorySlug` against `one.ie/web/src/lib/directories/registry.ts`'s `DIRECTORIES` for the `submitUrl`, `method`, and `fields` list — the pack's `fields` map already carries the values, keyed the same as the registry's `DirectoryField.key`s.
3. **Open and fill.** Navigate to `submitUrl` in the operator's Chrome. For a `method: 'form'` directory, read the page and match each `pack.fields` entry onto the input whose label/placeholder/autocomplete most plausibly matches that key. The twelve keys the templates can emit: `name`, `company`, `address`, `city`, `phone`, `email`, `website`, `url`, `category`, `tagline`, `description`, `pricing`. For a `method: 'email'` directory, draft the email in the operator's mail client instead of a web form, still stopping before send.
4. **Stop at the human checkpoint.** Once every matchable field is filled, stop and tell the operator plainly: "Form filled for {directory.name} — review and submit when ready." Do not proceed until the operator confirms they submitted it (or tells you to skip).
5. **Record the evidence.** After the operator confirms, `POST /api/directories/update` with `{ slug, id, status: "submitted", filedBy: "agent" }`. If the directory's confirmation page shows a live listing URL immediately, follow up once confirmed live with `{ status: "live", listingUrl }` — `listingUrl` is required to mark live, and the route 400s without it. If a listing takes longer to appear, leave the row `submitted` — the operator marks it live later from the board.
6. **Handle challenges and mismatches.** A captcha, email/phone verification loop, or a form the matcher can't confidently map → stop, tell the operator this row needs a by-hand fill from the pack drawer, and move to the next queued row. Never guess a field mapping you're not confident about — an empty field the operator notices beats a wrong value they don't.
7. **Repeat, paced.** Work through the batch (10–20 rows), then stop and summarize: how many submitted, how many handed to the human, how many skipped and why.

## Failure modes (designed in, not edge cases)

- **No Chrome session / extension not available** — refuse at startup with a plain message; tell the operator the pack drawer's by-hand path (copy fields, open submit page, mark submitted) is always the fallback.
- **Field mapping fails** — leave the row `queued`, note which fields couldn't be matched, move on. Never invent a value for a field the pack doesn't supply.
- **Directory site redesigned / submitUrl dead** — stop and leave the row `queued` with a note saying why. The status walk (`ALLOWED_TRANSITIONS` in `update.ts`) only allows `queued → submitted` and `submitted → live | rejected`, so a queued row **cannot** be marked `rejected` — that call 400s with `invalid_transition`. `rejected` is the verdict on a submission the directory turned down, not on a directory that can't be reached. A note on the stuck row is the signal that routes the registry fix and future runs away from this directory.

## See also

- `text/directory-submission.md` — the promise
- `text/directory-submission-plan.md` — data model, API shapes, § The browser hand
- `text/directory-submission-ui.md` — the File-with-agent door on the board
- `one.ie/web/src/lib/directories/registry.ts` — `DIRECTORIES`, `Directory`, `DirectoryField`
- `one.ie/web/src/pages/api/directories/run.ts` · `update.ts` — the two guarded routes this skill calls
