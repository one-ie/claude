# /do intent mode

Loaded by `do.md` when arguments are NOT a TODO filename, --auto, --wave, --once, or empty.
Treat arguments as **intent** and route to the fastest execution path.

---

## Step 1: Extract topic

Parse the intent into a topic slug (kebab-case, 2–4 words):

```
"create a landing page"     → landing-page
"fix the auth middleware"   → auth-middleware
"add payment tracking"      → payment-tracking
```

---

## Step 2: Search for context (parallel)

```bash
glob "**/*{topic}*-todo.md" | head -5         # Pattern 1: TODO files
glob "**/*{topic}*.md" | head -10             # Pattern 2: spec/plan docs
glob "**/*{topic}*" --type ts,tsx,astro | head -10  # Pattern 3: source files
glob "one/**/*{topic}*.md" | head -5          # Pattern 4: task mentions
```

Collect: `{ todos: [], specs: [], sources: [], tasks: [] }`

---

## Step 3: Reflect — what do we have?

| Found | State | Fastest path |
|-------|-------|--------------|
| TODO file exists | Execution queued | Use existing TODO mode |
| Spec exists, no TODO | Spec defines scope | Create TODO from spec, then execute |
| Sources exist, no spec | Code is the spec | Direct execution (simple) or create TODO (complex) |
| Nothing exists | Greenfield | Ask user for scope OR create minimal TODO |

**Complexity heuristic:**
- "create" / "add" / "build" → likely needs TODO (multi-wave)
- "fix" / "update" / "tweak" → likely direct execution
- "refactor" → read scope first, then decide

---

## Step 4: Report and route

```
┌─ /do intent: "{original intent}"
│
│  Topic:   {topic-slug}
│  Found:   {N} TODOs, {M} specs, {K} sources
│
│  Context:
│    • {file1} — {one-line summary}
│    • {file2} — {one-line summary}
│
│  Decision: {direct | create-todo | use-existing}
│  Rationale: {why this path is fastest}
│
└─ Proceeding with: {next action}
```

---

## Step 5: Execute

**TODO exists:** switch to `<todo-file>` mode.

**Spec exists, no TODO:**
1. Read the spec fully
2. Extract: goal, scope, constraints, exit criteria
3. Create `docs/{topic}-todo.md` from TODO template
4. Populate cycles/waves from spec structure
5. Switch to `<todo-file>` mode

**Sources exist, no spec (simple — fix/update):**
1. Read relevant source files
2. Execute directly
3. `bun run verify`
4. Mark outcome via `/close`

**Sources exist, no spec (complex — create/build):**
1. Read relevant source files
2. Create minimal TODO with one cycle
3. Switch to `<todo-file>` mode

**Nothing exists:**
1. Ask: "No existing context for '{topic}'. What's the goal? (one sentence)"
2. Create `docs/{topic}-todo.md` with user's answer as goal
3. Switch to `<todo-file>` mode
