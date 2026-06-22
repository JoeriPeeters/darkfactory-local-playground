# LAST_RUN — PB-1: Add "has three-point line" amenity

Implemented the standalone `hasThreePointLine` boolean amenity end-to-end,
following the existing `has_lighting` precedent (D1). No index (D2), not a
search filter (D3), no events, no edit/detail UI (out of scope).

## Changes

### playground-service
- **`db/migration/V2__add_has_three_point_line.sql`** (new) — `ALTER TABLE
  playgrounds ADD COLUMN has_three_point_line BOOLEAN NOT NULL DEFAULT FALSE;`
  (AC1, AC4).
- **`domain/entity/Playground.java`** — added `Boolean hasThreePointLine`
  column with `@Builder.Default = false`.
- **`domain/dto/PlaygroundDto.java`** — added the field to `CreateRequest`
  (default false), `UpdateRequest` (nullable), and `Response`.
- **`service/PlaygroundService.java`** — mapped the field in `create`,
  `update` (null-guarded partial update, AC2), and `toResponse` (so it flows
  through GET/search/POST/PUT).
- **`service/PlaygroundServiceTest.java`** — added a unit test asserting the
  field maps DTO ↔ entity ↔ response.

### frontend
- **`src/pages/create.js`** — added a "Three-point line" checkbox to the
  Amenities group and included `hasThreePointLine` in the create payload (AC3).
- `src/api.js` unchanged — the field round-trips through the existing JSON body.

## Not done (per rules)
- Did not commit, run tests, or run builds.
