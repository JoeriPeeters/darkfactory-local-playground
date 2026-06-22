# `specs/` — the work orders the factory consumes

A **spec** is the unit of work in the [dark-factory pipeline](../factory). It's the
*only* place a design decision is allowed to live before it becomes code: a human
(agent-assisted) fills it in, the factory generates from it, verifies against it,
and hands back a branch for review.

The guiding principle: **push every design decision OUT of the code and INTO the
spec, where it's cheap to review and change.** The code becomes a derivative of
this document — so the spec's quality is a hard ceiling on the output's quality.

> The factory is a mirror. A precise spec yields clean code; a vague one yields
> confident, broken code — faithfully. The load-bearing human is whoever can
> write a spec the machine can't misread.

---

## Files

| File | Role |
|---|---|
| `SPEC_TEMPLATE.md` | the skeleton — copy it to author a new spec |
| `schema.json` | machine-readable contract for the frontmatter (single source of truth) |
| `SCHEMA.md` | human-readable docs for that contract |
| `validate.py` | stdlib validator — enforces `schema.json`; the factory's stage-0 gate |
| `PB-1-Playground-three-point-line/` | a complete, worked example spec |

---

## Anatomy of a spec

A spec is just a markdown file: a **frontmatter block** (structured metadata the
machine reads) followed by **plain-language sections** (read by humans + the
generating agent). Each part is consumed by a specific stage of the factory:

| Section | Consumed by | Purpose |
|---|---|---|
| **frontmatter** | router / validator | metadata: id, status, risk, change_class, reversibility |
| **Intent** | generate + human gate | the *why*, one paragraph, no implementation |
| **Acceptance criteria** | **verify** | executable Given/When/Then — the only thing verify scores against |
| **Contracts** | generate + verify | the interfaces that change (migrations, API, events) |
| **Decisions** | the human (authoring) | every resolved ambiguity, with rationale — the real work |
| **Out of scope** | generate | the fence that stops gold-plating |
| **Verification plan** | verify + gate | the definition of done |
| **Grounding** | generate | what to read/imitate to stay on-convention |

The frontmatter is a contract with a fixed vocabulary so machines can route on it
reliably — see [`SCHEMA.md`](SCHEMA.md) for every field and its allowed values.

---

## Authoring a spec

```bash
# 1. copy the template into its own folder (specs can carry supporting artifacts)
mkdir specs/PB-2-my-feature
cp specs/SPEC_TEMPLATE.md specs/PB-2-my-feature/PB-2-my-feature.md

# 2. fill it in — delete the guidance comments, resolve every ambiguity in Decisions

# 3. validate before handing it to the factory
python3 specs/validate.py specs/PB-2-my-feature/PB-2-my-feature.md
```

`validate.py` with no arguments validates every `specs/**/PB-*.md`:

```bash
python3 specs/validate.py
```

Naming convention: a **work order** is `PB-<n>-<slug>.md` (the factory's trigger
keys on the `PB-` prefix, so `SCHEMA.md` / `SPEC_TEMPLATE.md` are correctly ignored).

---

## Tips for a spec the machine can't misread

- **Resolve, don't list.** Whatever you leave ambiguous, the machine resolves for
  you — silently, with a guess. The `Decisions` section is you doing that thinking
  on purpose.
- **Ground against reality.** Point `Grounding` at a real reference implementation
  and check it actually exists. Most cold-agent failures are *grounding* failures
  (a spec assuming a screen or test harness that isn't there).
- **Make every acceptance criterion testable.** If it can't become a check, it
  isn't sharp enough to be done.
- **Say what's out of scope.** "Events: None" is a valid, important answer.

---

## See also

- [`../factory/`](../factory) — the pipeline that consumes these specs
- [`../CLAUDE.md`](../CLAUDE.md) — project conventions (part of grounding)
