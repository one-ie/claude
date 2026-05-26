# Verb Contracts

Pre / post / invariant for the 6 locked verbs. Loaded only when editing a verb implementation.

When a real runtime exports the verbs as testable functions, bind a property-test suite to these contracts (one property per post / inv). Until then, contracts are the spec; they are not exercised by code.

## `signal(s, from?)`

| | |
|---|---|
| **pre** | `s.receiver` is a non-empty string of form `"unit"` or `"unit:task"` |
| **post** | exactly one of: `mark(edge)` deposited, `warn(edge)` deposited, signal `enqueued`, or `dissolved` — never zero, never two |
| **inv** | missing receiver never throws; dissolution is silent (Rule 1) |

## `mark(edge, strength = 1)`

| | |
|---|---|
| **pre** | `edge` has both endpoints; `strength ≥ 0` |
| **post** | `sense(edge)` after ≥ before; delta ≤ `strength` |
| **inv** | monotone non-decreasing; commutes on disjoint edges |

## `warn(edge, strength = 1)`

| | |
|---|---|
| **pre** | `edge` has both endpoints; `strength ≥ 0` |
| **post** | `danger(edge)` after ≥ before; delta ≤ `strength` |
| **inv** | orthogonal to `mark` — `warn` never decreases `sense`; `mark` never decreases `danger` |

## `fade(rate = 0.05)`

| | |
|---|---|
| **pre** | `rate ∈ [0, 1]` |
| **post** | every edge: `sense` non-increasing; `danger` decay rate ≥ 2× `sense` decay rate |
| **inv** | converges: repeated fade drives non-hardened paths to 0 |

## `follow(type?)`

| | |
|---|---|
| **pre** | none — may return `undefined` |
| **post** | result `r` has `sense(r) = max{ sense(e) : e matches type }` or `r = undefined`; deterministic |
| **inv** | `select(type)` is probabilistic sibling; probability monotone in `sense` |

## `harden(edge)`

| | |
|---|---|
| **pre** | `edge` exists |
| **post** | subsequent `fade(r)` reduces `sense(edge)` by less than unhardened baseline |
| **inv** | hardening attenuates `fade`; does NOT increase `sense`. To strengthen, `mark` |

## 3 locked rules as global contracts

| Rule | Contract |
|---|---|
| **R1 closed loop** | for every `signal()`, exactly 1 of `mark / warn / dissolve / enqueue` over the full handler chain |
| **R2 structural time** | no path id, field, or log contains `ms / s / hr / day / week / sprint` |
| **R3 deterministic receipts** | every `/close` and `w4:verify:*` carries `content.rubric` (values ∈ [0,1]) + `content.composite` (number) |
