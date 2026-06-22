# `factory/` — a local dark-factory SDLC, in four files

This is the runnable companion to the blog post on building a **dark-factory
(lights-out) software pipeline** locally. It turns a **spec** into a **reviewed,
tested branch** with no human keystroke on the code:

```
git push spec ─▶ trigger ─▶ validate ─▶ generate ─▶ verify ─▶ gate (your review)
```

The whole factory is four small things: a validated spec (see [`../specs/`](../specs)),
a git hook, a shell script, and a stock container image. Everything heavier
(Step Functions, Bedrock, a workflow engine) is the *production* shape — this is
the laptop sketch that proves the mechanism.

> ⚠️ **This is a proof-of-concept, not a product.** It runs synchronously in your
> own working checkout, uses a personal `claude` login, and keeps no run-state.
> It exists to demonstrate the *shape* of an agentic SDLC, not to ship code
> unattended. See "What this is NOT" below.

---

## The files

| File | Role | What it is |
|---|---|---|
| `factory.sh` | **the line** (orchestrator) | validates → branches → generates → verifies → commits |
| `demo.sh` | demo driver | runs the whole flow hands-free, for a screen recording |
| `demo-reset.sh` | reset | returns the repo to a clean, re-runnable state |
| `LAST_RUN.md` | generated | the agent's own summary of the most recent run (overwritten each run) |
| `BLOCKED.md` | generated | written only if the generate step refuses to guess on a vague spec |

The **trigger** is not in this folder — it's a `post-receive` git hook on a bare
repo that calls `factory.sh`. See [Trigger](#the-trigger) below.

---

## The stages (what `factory.sh` does)

| # | Stage | Tool | Notes |
|---|---|---|---|
| 0 | **validate** | `python3 ../specs/validate.py` | hard gate — a malformed spec stops the run before anything is generated |
| 1 | **branch** | `git switch -c factory/<spec>` | work happens isolated; nothing existing is touched |
| 2 | **generate** | `claude` (host CLI) | file-edit tools **only** — no shell, so the agent can't run/grade its own work |
| 3 | **verify** | `podman run maven:3.9-amazoncorretto-21 mvn verify` | the **inspector is never the builder**; runs the real JUnit suite + JaCoCo gate in the same toolchain as CI |
| 4 | **gate** | `git commit` → branch | your review is the human gate (swap in `gh pr create` on GitHub) |

Two load-bearing design choices:

- **The agent cannot verify itself.** Generate gets `Read,Edit,Write,Grep,Glob`
  and nothing else; the *script* owns verify. The thing being graded doesn't get
  to write its own report card.
- **Verify runs in a container matching CI.** `corretto-21` is the same runtime
  the CodeBuild pipeline uses, so "green locally" means "green in CI."

---

## Requirements

- `bash`, `git`, `python3` (stdlib only)
- [`podman`](https://podman.io) with a running machine (for the verify stage)
- the [`claude`](https://docs.claude.com/en/docs/claude-code) CLI, authenticated
- a populated `~/.m2` helps (mounted into the verify container to avoid re-downloads)

---

## Run it

### Directly

```bash
# from the repo root, on a clean main:
./factory/factory.sh specs/PB-1-Playground-three-point-line/PB-1-playground-three-point-line.md
```

On success you land on `factory/PB-1-…` with a commit ready to review:

```bash
git diff main..factory/PB-1-playground-three-point-line
```

### The trigger (push → factory)

The factory fires on a push to a **local bare repo** (a stand-in for CodeCommit /
GitHub). One-time setup:

```bash
git init --bare --initial-branch=main ~/konkreet-factory.git
git remote add factory ~/konkreet-factory.git
# install the post-receive hook (see the blog post for the script) into:
#   ~/konkreet-factory.git/hooks/post-receive
```

Then the whole flow is one command:

```bash
git push factory main      # → trigger fires → factory.sh runs → tested branch
```

### For a recording

```bash
./factory/demo.sh          # press Enter between beats while narrating
./factory/demo.sh --auto   # timed pauses, hands-free (good for a GIF)
```

`demo.sh` self-resets first, so you can re-run take after take.

---

## What this is NOT (and what production needs)

| Local POC | Production |
|---|---|
| `factory.sh` (bash, no state) | a workflow engine — Step Functions / Temporal / GH Actions |
| trigger runs synchronously in your checkout | event-driven dispatch into an **isolated, ephemeral** workspace |
| `claude` CLI, personal login | a managed model endpoint (e.g. **Bedrock**) with service creds + cost controls |
| one service's unit tests | integration + contract tests, linters/ArchUnit, SAST, dependency/secret scans |
| grounding = a file path typed by hand | **RAG** over the codebase + a long-term decision memory |
| "go look at a branch" | a real PR with required checks + risk-based routing |
| **no run-state** — dies halfway, start over | durable state, retries, idempotency, audit trail |

Not faked at all, and needed for a real factory: **routing by risk**, **measuring
human-touch rate to earn autonomy**, and **mutation testing to trust the tests**.

---

## See also

- [`../specs/`](../specs) — the spec format, schema, and validator the factory consumes
- [`../CLAUDE.md`](../CLAUDE.md) — project conventions (part of the generate step's grounding)

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
