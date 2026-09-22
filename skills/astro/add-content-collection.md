# Add Content Collection

**Category:** astro
**Version:** 2.0.0
**Used By:** `astro` skill · `/do` W3 edit wave

## Purpose

Adds a collection to `one.ie/web/src/content.config.ts`. This tree is on the Astro
Content Layer — every collection declares a **`loader`**; the legacy `type: 'content'`
shape is gone. Five collections exist today: `videos`, `playbook`, `moversPlaybook`,
`legal`, `blog`.

## Example

```typescript
// src/content.config.ts
import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

const GuideSchema = z.object({
  title: z.string(),
  order: z.number().default(0),
  publishedAt: z.coerce.date(),   // coerce — frontmatter dates arrive as strings
  tags: z.array(z.string()).default([]),
  draft: z.boolean().default(false),
});

const guides = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/guides" }),
  schema: GuideSchema,
});

// Append to the single exported object — do not add a second export.
export const collections = { videos, playbook, moversPlaybook, legal, blog, guides };
```

Then create `src/content/guides/` and put the markdown in it. Read it with
`getCollection('guides')`; filter `draft` yourself — the schema defaults it, it
doesn't exclude it.

## Version History

- **2.0.0** (2026-08-02): Rewritten for the Content Layer `loader` API and the real
  `content.config.ts`. The 1.0.0 example used the pre-Astro-5 shape with no loader.
- **1.0.0** (2025-10-18): Initial implementation
