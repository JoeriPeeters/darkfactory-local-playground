<!--
Konkreet feature spec — template v0.1 (dark-factory SDLC POC)

A spec is the unit of work the factory consumes: a human (or an agent + human review)
fills it, the generate stage builds from it, the verify stage checks against it, and the
PR is the human gate. The whole point is to push every design decision OUT of the code and
INTO this document, where it is cheap to review and change.

Each section maps to a dark-factory principle:
  frontmatter        -> policy router (route lights-out vs human gate by blast radius)
  Acceptance criteria -> the verification target (executable intent, not "tests pass")
  Contracts          -> cross-service safety + what verify inspects
  Decisions          -> where ambiguity is resolved (the human's real job)
  Verification plan  -> the definition of done the gate enforces
  Grounding          -> keeps generation on-convention

Copy this file to  specs/PB-<n>-<slug>.md  and fill it in. Delete the guidance comments.
-->

---
id: PB-<n>
title: <imperative, one line>
status: draft            # draft | approved | building | in-review | done
services: [<service>, frontend?]
change_class: <e.g. intra-service-additive | schema-migration | cross-service-contract | infra>
reversible: <true|false> # can it be rolled back with no data loss?
risk: <low|med|high>     # blast radius if it ships wrong
---

## Intent
<!-- One paragraph: the user-facing outcome and WHY. No implementation. -->

## Acceptance criteria
<!-- Numbered, testable, Given/When/Then. These ARE the checks the verify stage must satisfy.
     If a criterion can't be turned into a test, it's not done well enough. -->
- **AC1** — Given <state>, When <action>, Then <observable result>.
- **AC2** — ...

## Contracts
<!-- The interfaces that change. This is what protects cross-service safety and tells verify what to inspect. -->
### Data / migration
<!-- New Flyway migration, columns, indexes, defaults, backfill. -->
### API
<!-- Endpoints touched; request/response field additions; validation. -->
### Events
<!-- Domain events emitted/consumed, if any. "None" is a valid, important answer. -->

## Decisions
<!-- The heart of the spec. Each resolved ambiguity: the question, the choice, the rationale.
     This is where a one-line request becomes buildable. Cite precedent/convention. -->
- **D1** — <question>? → <choice>. Rationale: <why; cite the reference impl/convention>.

## Out of scope
<!-- Explicit non-goals. Bounds the agent so it doesn't gold-plate. -->
- ...

## Verification plan
<!-- The definition of done the gate enforces. Map each AC to a concrete check. -->
- Unit/integration tests covering: <...>
- Coverage gate: stays ≥ 70% line (JaCoCo)
- Smoke / manual: <what a human or a real run confirms>

## Grounding
<!-- Where the generator should look to stay on-convention. -->
- Conventions: `CLAUDE.md`
- Reference implementation: `<file(s) the change should imitate>`
