# Spec frontmatter schema (contract) — v0.1

The frontmatter at the top of every `specs/PB-*.md` is a **contract between the spec author
and the factory's machinery** (router, orchestrator, dashboards, validator). It is the
machine-readable header; everything below the second `---` is the human-readable body.

The single source of truth is [`schema.json`](schema.json) — `validate.py` enforces it, and
this file documents it. **Anything a machine routes on lives here; anything only a human/agent
reads stays in the body.** Routing fields use a fixed vocabulary (enum) so consumers can branch
reliably.

## Fields

| Field | Required | Type | Allowed values | Read by |
|---|---|---|---|---|
| `id` | yes | string | `PB-<n>` (e.g. `PB-1`) | traceability (spec → PR → deploy) |
| `title` | yes | string | one line | humans/dashboards |
| `status` | yes | enum | `draft`, `approved`, `building`, `in-review`, `done` | orchestrator gate, dashboards |
| `services` | yes | list | any of `playground-service`, `team-service`, `match-service`, `live-engine`, `identity-service`, `notification-service`, `frontend` | orchestrator (what to build/test), queries |
| `change_class` | yes | enum | `intra-service-additive`, `schema-migration`, `cross-service-contract`, `infra`, `frontend-only` | **router** (lane selection) |
| `reversible` | yes | bool | `true`, `false` | **router** (gate placement) |
| `risk` | yes | enum | `low`, `med`, `high` | **router** (gate placement) |

Unknown fields are **rejected** (`allow_unknown_fields: false`) — a typo'd key (`reversable`)
must fail loudly, not be silently ignored.

## Routing intent (how the router is meant to read this)

This is the *policy* the frontmatter feeds; the router code implements it.

- `reversible: false` **or** `risk: high` **or** `change_class` ∈ {`schema-migration`, `cross-service-contract`, `infra`} → **human gate required** (no auto-merge).
- `change_class: intra-service-additive` **and** `reversible: true` **and** `risk: low` → eligible for the **lights-out lane** (auto-merge on green verify).
- Everything else → default human gate.

## Changing the schema

The field set is an interface. Renaming/removing a field breaks every consumer that reads it,
so: update `schema.json`, this file, `SPEC_TEMPLATE.md`, and every consumer together, and bump
`schema_version`.
