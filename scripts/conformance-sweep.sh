#!/usr/bin/env bash
#
# scripts/conformance-sweep.sh — standing conformance pass across the MDF
# repos (Vikunja #17). Runs in CI via .github/workflows/conformance-sweep.yml
# on every push to main and on a weekly schedule; also runnable locally.
#
# What this catches, and why each check exists:
#
#   1. VENDORED FILE DRIFT — a repo keeps a static copy of a file whose
#      source of truth lives in another repo (e.g. mdf-validator's copy of
#      mdf-402.schema.json). This is exactly the bug found 2026-09-15
#      (Vikunja #28): the spec updated its schema on 2026-09-12, the
#      validator's copy silently didn't move, and nothing said so for three
#      days until someone happened to diff the files by hand. This check
#      diffs every known vendored copy against its source repo on every run,
#      and FAILS the job if any differ — this is the check CI exists for.
#
#   2. README / STATUS-TABLE SELF-CONTRADICTION — a README's prose status
#      line disagreeing with its own status table, or with the CHANGELOG.
#      This was the single most common defect class in the original
#      2026-09-04 audit (5 of 9 findings). Cheap to grep for once you know
#      the shape: version strings that don't match across README/CHANGELOG/
#      VERSION-file/package.json within one repo. Advisory in CI (does not
#      fail the job) — it's a "look at this" list, not a parseable rule; see
#      the loose-on-purpose note in the check itself.
#
#   3. VALIDATOR-VS-LIVE-DEMO — does the validator's own CLI, run right now
#      against the live demo, report clean? Necessary but not sufficient —
#      a validator checking against a stale vendored schema (check 1's job)
#      can report clean while still being wrong, which is exactly how #28
#      stayed hidden for three days despite this check already existing.
#      Advisory in CI: the live demo being briefly unreachable shouldn't
#      fail a CI run on an unrelated commit.
#
# Exit code: nonzero iff check 1 found any vendored-file drift. Checks 2
# and 3 are always advisory (printed, never gate the job) — they produce
# candidates for a human, not verdicts, so failing CI on them would either
# be ignored or would train people to ignore the whole job.
#
# Usage:
#   ./conformance-sweep.sh [--workdir DIR] [--skip-live]
#
# Requires: git, python3 (for JSON normalization), bun (only for check 3 —
# its absence is advisory, not a hard failure).

set -uo pipefail

WORKDIR="${TMPDIR:-/tmp}/mdf-conformance-sweep-$$"
SKIP_LIVE=0
DRIFT_FOUND=0
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workdir=*) WORKDIR="${1#*=}" ;;
    --workdir) WORKDIR="${2:-}" ;;
    --skip-live) SKIP_LIVE=1 ;;
  esac
  shift
done

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

log()  { printf '%s\n' "$*"; }
sumlog() { printf '%s\n' "$*" >> "$SUMMARY"; }
warn() { printf '⚠️  %s\n' "$*"; }
ok()   { printf '✅ %s\n' "$*"; }
hr()   { printf -- '---------------------------------------------------------------\n'; }

log "MDF conformance sweep — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "workdir: $WORKDIR"
hr

sumlog "# MDF conformance sweep — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
sumlog ""

# -----------------------------------------------------------------------
# Clone (shallow, main only) every repo this sweep touches. The repo this
# script lives in (mdf) is cloned fresh too, deliberately, rather than
# reusing the CI checkout — this is what makes the script identical whether
# run in CI or on a laptop, and guards against the CI checkout being a PR
# branch rather than main when this workflow is ever extended to run on PRs.
# -----------------------------------------------------------------------

REPOS=(mdf mdf-reference-server mdf-validator)

for repo in "${REPOS[@]}"; do
  if [ -d "$repo" ]; then
    (cd "$repo" && git fetch --quiet origin main && git reset --hard --quiet origin/main)
  else
    git clone --quiet --depth 1 "https://github.com/bitcryptic-gw/${repo}.git" "$repo"
  fi
done

SPEC_SHA=$(cd mdf && git rev-parse --short HEAD)
log "spec (bitcryptic-gw/mdf) @ $SPEC_SHA"
hr
sumlog "Spec \`main\` @ \`$SPEC_SHA\`"
sumlog ""

# =========================================================================
# CHECK 1 — vendored file drift (FAILS the job)
#
# Table format: "path-in-consumer-repo|source-repo|path-in-source-repo"
# Add a row here whenever a repo starts keeping a static copy of something
# another repo owns. If a row's source path gets fetched at run/test time
# instead of vendored (mdf-reference-server's 402-schema.test.ts does this
# already), delete the row — there's nothing to drift.
# =========================================================================

log "CHECK 1 — vendored file drift"
hr
sumlog "## Check 1 — vendored file drift"
sumlog ""

VENDORED=(
  "mdf-validator/src/schemas/mdf.schema.json|mdf|mdf.schema.json"
  "mdf-validator/src/schemas/mdf-402.schema.json|mdf|mdf-402.schema.json"
)

for row in "${VENDORED[@]}"; do
  IFS='|' read -r consumer_path source_repo source_path <<< "$row"
  if [ ! -f "$consumer_path" ]; then
    warn "$consumer_path does not exist — row is stale, update this script"
    sumlog "- ⚠️ \`$consumer_path\` does not exist — this script's VENDORED table needs updating"
    continue
  fi
  if [ ! -f "$source_repo/$source_path" ]; then
    warn "$source_repo/$source_path does not exist — row is stale, update this script"
    sumlog "- ⚠️ \`$source_repo/$source_path\` does not exist — this script's VENDORED table needs updating"
    continue
  fi
  # Normalize JSON (sorted keys, consistent indent) before diffing, so the
  # diff shows real content drift rather than incidental formatting noise
  # (key wrapping, quote style) that means nothing.
  a_norm=$(python3 -c "import json,sys; print(json.dumps(json.load(open('$consumer_path')), indent=2, sort_keys=True))" 2>/dev/null)
  b_norm=$(python3 -c "import json,sys; print(json.dumps(json.load(open('$source_repo/$source_path')), indent=2, sort_keys=True))" 2>/dev/null)
  if [ -z "$a_norm" ] || [ -z "$b_norm" ]; then
    if diff -q "$consumer_path" "$source_repo/$source_path" > /dev/null 2>&1; then
      ok "$consumer_path matches $source_repo@main:$source_path"
      sumlog "- ✅ \`$consumer_path\` matches \`$source_repo\`@main"
    else
      warn "$consumer_path is STALE relative to $source_repo@main:$source_path"
      diff "$consumer_path" "$source_repo/$source_path" | head -20 | sed 's/^/    /'
      sumlog "- ❌ **\`$consumer_path\` is STALE** relative to \`$source_repo\`@main:\`$source_path\`"
      {
        echo '```diff'
        diff "$consumer_path" "$source_repo/$source_path" | head -20
        echo '```'
        echo ""
      } >> "$SUMMARY"
      DRIFT_FOUND=1
    fi
    continue
  fi
  if [ "$a_norm" = "$b_norm" ]; then
    ok "$consumer_path matches $source_repo@main:$source_path"
    sumlog "- ✅ \`$consumer_path\` matches \`$source_repo\`@main"
  else
    warn "$consumer_path is STALE relative to $source_repo@main:$source_path"
    log "    diff (normalized):"
    diff <(echo "$a_norm") <(echo "$b_norm") | head -30 | sed 's/^/    /'
    log "    (this is the exact shape of Vikunja #28 — sync the vendored copy)"
    sumlog "- ❌ **\`$consumer_path\` is STALE** relative to \`$source_repo\`@main:\`$source_path\`"
    {
      echo '```diff'
      diff <(echo "$a_norm") <(echo "$b_norm") | head -30
      echo '```'
      echo ""
    } >> "$SUMMARY"
    DRIFT_FOUND=1
  fi
done
hr
sumlog ""

# =========================================================================
# CHECK 2 — README / status-table / version self-contradiction (advisory)
# =========================================================================

log "CHECK 2 — README / status self-contradiction candidates (advisory)"
hr
sumlog "## Check 2 — README / status self-contradiction candidates (advisory)"
sumlog ""

for repo in "${REPOS[@]}"; do
  readme="$repo/README.md"
  [ -f "$readme" ] || continue

  version_sources=()
  [ -f "$repo/VERSION" ] && version_sources+=("VERSION:$(cat "$repo/VERSION" | tr -d '[:space:]')")
  if [ -f "$repo/package.json" ]; then
    pkg_version=$(grep -m1 '"version"' "$repo/package.json" | sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/')
    [ -n "$pkg_version" ] && version_sources+=("package.json:$pkg_version")
  fi
  readme_version=$(grep -m1 -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$readme" | head -1)
  [ -n "$readme_version" ] && version_sources+=("README:$readme_version")
  if [ -f "$repo/CHANGELOG.md" ]; then
    changelog_version=$(grep -m1 -oE '## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$repo/CHANGELOG.md" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$changelog_version" ] && version_sources+=("CHANGELOG:$changelog_version")
  fi

  if [ "${#version_sources[@]}" -gt 1 ]; then
    log "  $repo version strings: ${version_sources[*]}"
    bare=$(printf '%s\n' "${version_sources[@]}" | sed -E 's/^[^:]+:v?//' | sort -u)
    bare_count=$(printf '%s\n' "$bare" | wc -l | tr -d ' ')
    if [ "$bare_count" -gt 1 ]; then
      warn "$repo has $bare_count distinct version strings across its own files — check by hand"
      sumlog "- ⚠️ **$repo**: $bare_count distinct version strings (${version_sources[*]}) — worth a look"
    else
      ok "$repo version strings agree"
      sumlog "- ✅ **$repo** version strings agree (${version_sources[*]})"
    fi
  fi

  if grep -qi 'stubbed' "$readme" && grep -qi 'complete' "$readme"; then
    log "  $repo README contains both \"stubbed\" and \"complete\" — read it, don't trust this script's judgement:"
    grep -n -i -B1 -A1 'stubbed' "$readme" | sed 's/^/    /'
    sumlog "- ⚠️ **$repo** README contains both \"stubbed\" and \"complete\" — worth a human read, not necessarily a bug"
  fi
done
hr
sumlog ""

# =========================================================================
# CHECK 3 — validator against the live demo (advisory)
# =========================================================================

log "CHECK 3 — validator vs live demo (advisory)"
hr
sumlog "## Check 3 — validator vs live demo (advisory)"
sumlog ""

if [ "$SKIP_LIVE" -eq 1 ]; then
  log "  skipped (--skip-live)"
  sumlog "_skipped (--skip-live)_"
else
  if command -v bun > /dev/null 2>&1; then
    (
      cd mdf-validator || exit 1
      bun install --silent
      log "  running: bun run src/index.ts -- --check-headers https://mdf-demo.bitcryptic.com"
      if bun run src/index.ts -- --check-headers https://mdf-demo.bitcryptic.com; then
        ok "validator reports the live demo clean"
        echo "- ✅ validator reports the live demo clean" >> "$SUMMARY"
      else
        warn "validator reported a problem against the live demo — see job log above"
        echo "- ⚠️ validator reported a problem against the live demo — see job log for detail" >> "$SUMMARY"
      fi
    )
  else
    warn "bun not found — cannot run the validator CLI"
    sumlog "- ⚠️ bun not available in this environment — check 3 skipped"
  fi
fi
hr
sumlog ""

# =========================================================================
# Summary
# =========================================================================

if [ "$DRIFT_FOUND" -eq 1 ]; then
  log "RESULT: vendored-file drift found — failing."
  sumlog "## Result: ❌ vendored-file drift found"
else
  log "RESULT: no vendored-file drift."
  sumlog "## Result: ✅ no vendored-file drift"
fi

exit "$DRIFT_FOUND"
