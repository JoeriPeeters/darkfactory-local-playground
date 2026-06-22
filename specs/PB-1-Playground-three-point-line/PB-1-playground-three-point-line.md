---
id: PB-1
title: Add a "has three-point line" amenity to playgrounds
status: draft
services: [playground-service, frontend]
change_class: intra-service-additive
reversible: true
risk: low
---

## Intent
Players want to know whether an outdoor court is marked with a three-point line, since many
street courts are not. Surface it as an amenity on the playground create screen so it can be
recorded, and return it from the API like the other amenities.

## Acceptance criteria
- **AC1** — Given a new playground is created without specifying the field, When it is persisted, Then `hasThreePointLine` is `false` (not null).
- **AC2** — Given a playground, When a `PUT /api/v1/playgrounds/{id}` includes `"hasThreePointLine": true`, Then the stored playground has the field `true` and a subsequent `GET` returns it `true`.
- **AC3** — Given the playground create screen, When the user toggles the "Three-point line" checkbox and submits, Then `hasThreePointLine` is included in the create payload and the created playground returns it from the API.
- **AC4** — Given any existing playground row, When the migration runs, Then it gets `has_three_point_line = false` with no data loss.

## Contracts
### Data / migration
- New migration `V2__add_has_three_point_line.sql`:
  `ALTER TABLE playgrounds ADD COLUMN has_three_point_line BOOLEAN NOT NULL DEFAULT FALSE;`
- No index (see D2).
### API
- `PlaygroundDto`: add `boolean hasThreePointLine`.
- `GET /{id}`, `GET /search`, `POST /`, `PUT /{id}` all carry the new field (it flows through the existing DTO mapping).
- No new endpoint.
### Events
- None. (Playground writes don't currently emit domain events; do not add one.)

## Decisions
- **D1** — Model as a standalone `has_*` boolean, or introduce a generalized amenities collection? → **Standalone boolean.** Rationale: the established convention is individual columns (`has_toilets`, `has_shower`, `has_drinking_water`, `has_lighting`, `has_parking`, `is_indoor`); follow precedent, lowest blast radius, reversible. A generalized amenity model is a separate, larger refactor and is out of scope.
- **D2** — Add a partial index like `has_lighting` has? → **No index.** Rationale: indexes on amenities exist only where they're a common search filter (`has_lighting`). Three-point line is not yet a search filter (see Out of scope), so an index is premature.
- **D3** — Make it filterable in `GET /search`? → **No, not now.** Rationale: keep this change additive and minimal; search filtering is a separate spec if demand appears.

## Out of scope
- Filtering playgrounds by `hasThreePointLine` in search.
- A generalized/normalized amenities model.
- Showing the amenity on the public detail/read-only views (this spec covers the create screen + API only).
- An edit screen — the frontend has only a create form + a read-only table today; the field round-trips via the API, not a UI edit flow.

## Verification plan
- Integration test (Testcontainers): create without the field → reads back `false` (AC1); PUT `true` → GET returns `true` (AC2); migration applies on a seeded row (AC4).
- Service unit test: DTO ↔ entity mapping includes the new field.
- Frontend: the create screen renders the checkbox and includes it in the create payload (AC3).
- Coverage gate: stays ≥ 70% line (JaCoCo).
- Smoke: run locally via docker-compose, toggle the checkbox, confirm round-trip.

## Grounding
- Conventions: `CLAUDE.md`
- Reference implementation: the existing `has_lighting` amenity end-to-end —
  `playground-service/.../domain/entity/Playground.java`,
  `domain/dto/PlaygroundDto.java`,
  `db/migration/V1__create_playgrounds.sql`,
  and the playground create screen + `frontend/src/api.js`.
