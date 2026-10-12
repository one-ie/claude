---
name: distribute
description: Take a video or image made in Claude Code and hand it to ONE for distribution — upload it into the workspace media library, draft a social post that carries it, and stage it as ad creative for a campaign. A person publishes; this skill never does. Use when someone says "post this video", "put my video in the library", "send this clip to ONE", "use this as an ad", "distribute this", "draft a post with this image", or "why didn't my video post".
---

# Distribute — from a file on this machine to the platform

**Three doors, in order: upload → draft → stage.** Each is a real door. This
skill names no other. Publishing and ad spend are a person's step on the web
page — a key drafts, a person presses publish. That line is deliberate: a post
that publishes itself, or an ad that spends money, with nobody in the loop is
exactly what ONE refuses.

## 0. Connected?

The `one` CLI reads `~/.config/one/key`. No key → run `/oneie-claude:setup`
first. Every door below acts as that key's actor, and a workspace the key may
not write is **refused, never quietly swapped for your own** — read the `key=`
in the receipt; it names the workspace the bytes actually reached.

## 1. Upload into the library

```bash
one media upload ./clip.mp4 --workspace <slug>
```

| File | Door | Ceiling |
|---|---|---|
| `.mp4` `.m4v` `.mov` `.webm` | streamed `PUT /api/media/video-upload` | 100 MB |
| `.png` `.jpg` `.gif` `.webp` | `media:upload` | 5 MiB |
| `.avi` `.mkv` | refused locally — convert first: `ffmpeg -i in.avi out.mp4` | — |

The receipt prints an **absolute** URL. Use that one: platforms fetch media
from their own servers, and a `/api/...` path means nothing to them.

## 2. Draft a post that carries it

In one step:

```bash
one media upload ./clip.mp4 --workspace <slug> --post "Caption here" --platforms facebook
```

Or from a URL you already have:

```bash
one social create --group <slug> --content "Caption" --platforms facebook --media-url <absolute-url>
```

Both print the page where a person reviews and publishes:
`https://one.ie/u/<slug>/marketing/social`. Give the user that link. Do not
try to schedule or publish from the key — the door answers `403
approval_required`, by design.

**What each platform does with a video today** (checked against the live
integration registry, not assumed):

| Platform | Video post |
|---|---|
| Facebook Page | should post the video (wired to the real action; no real post has proven it yet) |
| LinkedIn, X | posts the caption only — the video is not attached |
| Instagram, TikTok | not working yet |

Say this to the user before they pick platforms. Never report a LinkedIn or X
post as "posted the video".

## 3. Stage it as ad creative

```bash
one ask world:create-thing --data '{
  "name": "Clip — feed video",
  "type": "creative-asset",
  "group": "<campaign-id>",
  "tags": ["creative:pending"],
  "meta": {
    "platform": "meta", "placement": "feed", "format_key": "meta-feed-video",
    "variant": "a", "kind": "video", "url": "<absolute-url>",
    "provider": "upload", "prompt": "", "seed": "", "cost": 0,
    "width": 1080, "height": 1920,
    "primaryText": "…", "headline": "…", "cta": "LEARN_MORE"
  }
}'
```

`creative:pending`, never `creative:approved` — approval is the person's step
on the campaign's Creative tab. **Ad pushes are not live on any platform yet**:
say so plainly if asked to "run the ad". The creative is staged and visible;
nothing spends.

## When it fails

| Answer | Means | Do |
|---|---|---|
| `401` | the key matched nothing | `/oneie-claude:setup` |
| `403 forbidden` | the key is real, the workspace is not yours to write | ask which workspace; never retry into your own |
| `403 approval_required` | a key tried to schedule or publish | hand the user the review link |
| `413` | over the ceiling | trim or re-encode (`ffmpeg -crf 28`) |
| `415` | the bytes are not mp4/mov/webm | re-encode; the extension is not what is checked |
