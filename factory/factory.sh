#!/usr/bin/env bash
#
# factory.sh — local dark-factory SDLC spine (POC)
#
#   commit a spec  ─▶  [ generate → verify ]  ─▶  branch + diff (your review = the gate)
#
# The factory sits UPSTREAM of CodePipeline: it turns a spec into a reviewable
# diff. After you merge, the existing pipeline does merge → deploy.
#
# Deliberate boundary: the GENERATE agent gets only file-editing tools, never
# Bash. The script — not the agent — runs VERIFY, so the agent can't game its
# own definition of done. Verify is the ceiling of autonomy; keep it honest.
#
# Usage:   factory/factory.sh specs/PB-1-playground-three-point-line.md
#
set -euo pipefail

# ── locate repo root regardless of where we're invoked from ──────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ── pretty logging ───────────────────────────────────────────────────────────
c_reset=$'\033[0m'; c_bold=$'\033[1m'; c_grn=$'\033[32m'; c_red=$'\033[31m'; c_ylw=$'\033[33m'; c_blu=$'\033[34m'
stage() { printf '\n%s%s▶ %s%s\n' "$c_bold" "$c_blu" "$1" "$c_reset"; }
ok()    { printf '%s✓ %s%s\n' "$c_grn" "$1" "$c_reset"; }
warn()  { printf '%s! %s%s\n' "$c_ylw" "$1" "$c_reset"; }
die()   { printf '%s✗ %s%s\n' "$c_red" "$1" "$c_reset" >&2; exit 1; }

# ── args ─────────────────────────────────────────────────────────────────────
SPEC="${1:-}"
[ -n "$SPEC" ] || die "usage: factory/factory.sh <spec-file>"
[ -f "$SPEC" ] || die "spec not found: $SPEC"

SPEC_BASE="$(basename "$SPEC" .md)"          # e.g. PB-1-playground-three-point-line
SPEC_ID="$(grep -m1 '^id:' "$SPEC" | awk '{print $2}')"
SPEC_TITLE="$(grep -m1 '^title:' "$SPEC" | sed 's/^title:[[:space:]]*//')"
BRANCH="factory/${SPEC_BASE}"

printf '%s%s═══ factory ═══%s  %s — %s\n' "$c_bold" "$c_blu" "$c_reset" "${SPEC_ID:-?}" "${SPEC_TITLE:-$SPEC_BASE}"

# ── precondition: clean working tree (the run must start from a known state) ──
if [ -n "$(git status --porcelain)" ]; then
  die "working tree is dirty. Commit/stash/revert first — the factory must start clean so the diff it produces is purely its own output."
fi

# ── STAGE 0 — VALIDATE SPEC (hard gate) ──────────────────────────────────────
stage "0 · validate spec"
python3 specs/validate.py "$SPEC" || die "spec failed validation — fix the spec, not the code."
ok "spec is well-formed"

# ── STAGE 1 — BRANCH ─────────────────────────────────────────────────────────
stage "1 · branch"
START_REF="$(git rev-parse --abbrev-ref HEAD)"
git switch -c "$BRANCH" 2>/dev/null || git switch "$BRANCH"
ok "on $BRANCH (from $START_REF)"

# ── STAGE 2 — GENERATE (autonomous, file-edit tools only) ────────────────────
stage "2 · generate"
GEN_PROMPT="You are the GENERATE stage of an automated SDLC factory.

Implement the feature specified in: ${SPEC}
Read that spec in full first. The spec is the contract — build exactly what its
Acceptance criteria, Contracts, and Decisions require, nothing more.

Rules:
- Follow the conventions in CLAUDE.md and imitate the files named in the spec's
  Grounding section.
- Honour the Contracts section literally (migrations, API fields, events).
- Respect Out of scope — do NOT gold-plate.
- Edit only the code/files needed. Do not commit. Do not run tests or builds.
- If the spec is ambiguous or assumes something that does not exist in the repo,
  STOP and write your blocker to factory/BLOCKED.md instead of guessing.

When done, write a short summary of what you changed to factory/LAST_RUN.md."

rm -f factory/BLOCKED.md
set +e
claude -p "$GEN_PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Read,Edit,Write,Grep,Glob" \
  --model claude-opus-4-8
GEN_RC=$?
set -e
[ $GEN_RC -eq 0 ] || die "generate agent exited with code $GEN_RC"
[ -f factory/BLOCKED.md ] && { warn "agent reported a blocker:"; cat factory/BLOCKED.md; die "generation blocked — sharpen the spec and re-run."; }
[ -n "$(git status --porcelain)" ] || die "agent produced no changes — likely a spec problem."
ok "generation produced changes"

# ── STAGE 3 — VERIFY (the script owns this, not the agent) ───────────────────
stage "3 · verify"
VERIFY_OK=1

# 3a — spec still validates (the agent didn't corrupt it)
python3 specs/validate.py "$SPEC" >/dev/null && ok "spec re-validates" || { warn "spec no longer validates"; VERIFY_OK=0; }

# 3b — run the JaCoCo-gated suite in every changed dir that has a pom.xml.
#      Prefer podman (corretto-21 == CodeBuild's toolchain) over a host mvn. The
#      agent never runs this — the script owns verify so the generator can't game it.
MVN_IMAGE="maven:3.9-amazoncorretto-21"
run_mvn_verify() {  # $1 = service dir relative to repo root
  local d="$1"
  if command -v podman >/dev/null 2>&1; then
    podman run --rm --security-opt label=disable \
      -v "$ROOT/$d":/work -v "$HOME/.m2":/root/.m2 -w /work \
      "$MVN_IMAGE" mvn verify --batch-mode --no-transfer-progress
  elif command -v mvn >/dev/null 2>&1; then
    ( cd "$ROOT/$d" && mvn -q verify --batch-mode --no-transfer-progress )
  else
    return 127
  fi
}

CHANGED_SERVICE_DIRS="$(git status --porcelain | awk '{print $2}' | cut -d/ -f1 | sort -u)"
ran_any=0
for d in $CHANGED_SERVICE_DIRS; do
  [ -f "$d/pom.xml" ] || continue
  ran_any=1
  log="${TMPDIR:-/tmp}/factory-verify-${d//\//_}.log"
  printf '   verify · %s …\n' "$d"
  if run_mvn_verify "$d" >"$log" 2>&1; then
    ok "$d: tests + JaCoCo gate passed   (log: $log)"
  else
    rc=$?
    if [ "$rc" -eq 127 ]; then
      warn "neither podman nor mvn available — Java verify SKIPPED. Verify is INCOMPLETE."
    else
      warn "$d: verify FAILED (exit $rc) — last lines of $log:"
      tail -25 "$log"
    fi
    VERIFY_OK=0
  fi
done
[ "$ran_any" -eq 1 ] || warn "no changed dir has a pom.xml — no Java verify ran"

# ── STAGE 4 — GATE (commit; your review is the human gate) ───────────────────
stage "4 · gate"
git add -A
git commit -q -m "${SPEC_ID:-spec}: ${SPEC_TITLE:-$SPEC_BASE}

Generated by factory.sh from ${SPEC}.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
ok "committed on $BRANCH"

printf '\n%s── diff summary ──%s\n' "$c_bold" "$c_reset"
git --no-pager diff --stat "$START_REF" HEAD

printf '\n%s═══ result ═══%s\n' "$c_bold" "$c_reset"
if [ $VERIFY_OK -eq 1 ]; then
  ok "VERIFY PASSED — review the branch, then merge to hand off to CodePipeline:"
else
  warn "VERIFY INCOMPLETE/FAILED — do not merge until green. Review the diff:"
fi
printf '   git switch %s && git diff %s..%s\n' "$BRANCH" "$START_REF" "$BRANCH"
printf '   (gate is your review — swap in `gh pr create` once the repo is on GitHub)\n'
