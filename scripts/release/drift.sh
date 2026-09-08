#!/usr/bin/env bash
# Release drift gate: what does the release branch's base carry that the
# integration branch never received?
#
# Security PRs, hotfixes, and config edits land on main first. The release
# branch is cut from main and then takes dev's changes, so anything main holds
# that dev never received is either reverted by the release or collides with
# it, and Dependabot raises the same fix again. Run this before cutting the
# release branch; it exits non-zero while any such drift exists.
#
# Usage:
#   scripts/release/drift.sh [--base REF] [--head REF] [--since REF]
#                            [--no-fetch] [--result-file PATH]
#
# Flags:
#   --base REF          Integration branch (default: origin/dev)
#   --head REF          Release base (default: origin/main)
#   --since REF         Anchor for "commits on head since the last release".
#                       Default, in order: the newest v* tag reachable from
#                       head; the newest head commit whose subject reads
#                       "release vX.Y.Z"; the merge base of the two refs.
#   --no-fetch          Skip `git fetch origin` (default: fetch when a ref
#                       starts with origin/)
#   --result-file PATH  Write "<pass> <fail> <skip>" to PATH at exit for
#                       _lib.sh's delegate_to_subscript; suppresses the summary
#
# Gates:
#   1. Every commit on head since the anchor, and every file those commits
#      touched that base does not already contain. A file base has moved
#      further on its own is not drift: head's change (anchor to head) is
#      checked against base's copy, first by three-way merge and then line by
#      line (every added line present, every removed line gone). Lockfiles
#      are handled by gate 3.
#   2. .github/ matches exactly between base and head.
#   3. For each lockfile head carries (package-lock.json, Cargo.lock): every
#      package head resolves newer than base, one line per package name so
#      nested copies and hoisting moves never show. The count of base-newer
#      packages (routine updates awaiting release) is reported for context.
#
# Exit codes:
#   0 = no drift
#   1 = drift found (see the failed gates)
#   2 = setup error (missing dependency, unknown ref)
#
# Dependencies: git, diff, jq or jaq (for package-lock.json), sort -V, join.
set -euo pipefail

. "$(dirname "$0")/_lib.sh"

# Argument parsing -----------------------------------------------------------

BASE_REF="origin/dev"
HEAD_REF="origin/main"
SINCE_REF=""
DO_FETCH=1
RESULT_FILE=""

usage() {
  sed -n '2,42p' "$0" | sed 's/^# \?//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE_REF="$2"
      shift 2
      ;;
    --head)
      HEAD_REF="$2"
      shift 2
      ;;
    --since)
      SINCE_REF="$2"
      shift 2
      ;;
    --no-fetch)
      DO_FETCH=0
      shift
      ;;
    --result-file)
      RESULT_FILE="$2"
      shift 2
      ;;
    -h | --help) usage ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      ;;
  esac
done

require_bin git
require_bin join
JQ_BIN=""
if have_bin jq; then
  JQ_BIN=jq
elif have_bin jaq; then
  JQ_BIN=jaq
fi
readonly JQ_BIN

readonly LOCKFILE_PATTERN='(^|/)(package-lock\.json|Cargo\.lock)$'

# Setup ----------------------------------------------------------------------

# Fetches origin when either ref is a remote-tracking ref; a failed fetch is
# reported and the gates run on whatever the local refs hold.
maybe_fetch() {
  [[ $DO_FETCH -eq 1 ]] || return 0
  [[ "$BASE_REF" == origin/* || "$HEAD_REF" == origin/* ]] || return 0
  git fetch origin --quiet 2>/dev/null || echo "warning: git fetch origin failed; using local refs" >&2
}

# Aborts with exit 2 when a ref does not resolve to a commit.
require_ref() {
  git rev-parse --verify --quiet "$1^{commit}" >/dev/null || {
    echo "unknown ref: $1" >&2
    exit 2
  }
}

# Resolves the anchor commit for "since the last release" and prints how it
# was chosen. Honors --since when given.
resolve_anchor() {
  local tag subject_commit
  if [[ -n "$SINCE_REF" ]]; then
    require_ref "$SINCE_REF"
    ANCHOR=$(git rev-parse "$SINCE_REF^{commit}")
    ANCHOR_HOW="--since $SINCE_REF"
    return
  fi
  if tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' "$HEAD_REF" 2>/dev/null); then
    ANCHOR=$(git rev-parse "$tag^{commit}")
    ANCHOR_HOW="tag $tag"
    return
  fi
  subject_commit=$(git log -1 --format=%H --extended-regexp \
    --grep='release v?[0-9]+\.[0-9]+\.[0-9]+' "$HEAD_REF" 2>/dev/null || true)
  if [[ -n "$subject_commit" ]]; then
    ANCHOR="$subject_commit"
    ANCHOR_HOW="release commit $(git log -1 --format='%h %s' "$subject_commit")"
    return
  fi
  ANCHOR=$(git merge-base "$BASE_REF" "$HEAD_REF")
  ANCHOR_HOW="merge base $(git rev-parse --short "$ANCHOR")"
}

# Gate 1: commits on head since the anchor and the files they touched -------

# Prints the blob id of PATH at REF, or nothing when the path is absent.
blob_at() {
  git rev-parse --verify --quiet "$1:$2" 2>/dev/null || true
}

# Classifies PATH as "contained", "differs", or "missing": whether base
# already holds everything head changed in it since the anchor. First a
# three-way merge of head's change onto base's copy; a clean merge that leaves
# base's copy untouched is contained. When base has also edited nearby lines
# the merge cannot answer, so the fallback checks head's change line by line:
# every line head added must appear in base's copy and every line head removed
# must be gone from it. Lines that are only punctuation are ignored, since
# they repeat throughout a file.
classify_file() {
  local path="$1" anchor_blob head_blob base_blob tmp merged status
  head_blob=$(blob_at "$HEAD_REF" "$path")
  base_blob=$(blob_at "$BASE_REF" "$path")
  anchor_blob=$(blob_at "$ANCHOR" "$path")
  if [[ -z "$base_blob" ]]; then
    echo missing
    return
  fi
  if [[ "$head_blob" == "$base_blob" ]]; then
    echo contained
    return
  fi
  if [[ -z "$anchor_blob" ]]; then
    echo differs
    return
  fi
  tmp=$(mktemp -d)
  git cat-file -p "$anchor_blob" >"$tmp/anchor"
  git cat-file -p "$base_blob" >"$tmp/base"
  git cat-file -p "$head_blob" >"$tmp/head"
  set +e
  merged=$(git merge-file -p "$tmp/base" "$tmp/anchor" "$tmp/head" 2>/dev/null)
  status=$?
  set -e
  if [[ $status -eq 0 && "$merged" == "$(<"$tmp/base")" ]]; then
    echo contained
  elif lines_contained "$tmp/anchor" "$tmp/head" "$tmp/base"; then
    echo contained
  else
    echo differs
  fi
  rm -rf "$tmp"
}

# Returns 0 when every content line ADDED between ANCHOR_FILE and HEAD_FILE
# is present in BASE_FILE and every content line REMOVED is absent from it.
lines_contained() {
  local anchor_file="$1" head_file="$2" base_file="$3" line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:][:punct:]]*$ ]] && continue
    grep -qxF -- "$line" "$base_file" || return 1
  done < <(diff --unchanged-line-format= --old-line-format= --new-line-format='%L' "$anchor_file" "$head_file" || true)
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:][:punct:]]*$ ]] && continue
    grep -qxF -- "$line" "$base_file" && return 1
  done < <(diff --unchanged-line-format= --old-line-format='%L' --new-line-format= "$anchor_file" "$head_file" || true)
  return 0
}

gate_head_commits() {
  header "Commits on $HEAD_REF since $ANCHOR_HOW"
  local commits files path verdict touched_by
  local -a flagged=()
  commits=$(git log --format='%h %s' "$ANCHOR..$HEAD_REF")
  if [[ -z "$commits" ]]; then
    gate_pass "no commits on $HEAD_REF since the anchor"
    return
  fi
  printf '%s\n' "$commits" | sed 's/^/    /'
  files=$(git diff --name-only "$ANCHOR" "$HEAD_REF" | grep -vE "$LOCKFILE_PATTERN" || true)
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -n "$(blob_at "$HEAD_REF" "$path")" ]] || continue # deleted on head; reviewed by hand
    verdict=$(classify_file "$path")
    [[ "$verdict" == contained ]] || flagged+=("$verdict $path")
  done <<<"$files"
  if [[ ${#flagged[@]} -eq 0 ]]; then
    gate_pass "$BASE_REF already contains every change those commits made"
    return
  fi
  gate_fail "changes on $HEAD_REF that $BASE_REF does not contain" "${#flagged[@]} files"
  for path in "${flagged[@]}"; do
    touched_by=$(git log --format=%h "$ANCHOR..$HEAD_REF" -- "${path#* }" | paste -sd, -)
    printf '    %-9s %s  (head commits %s)\n' "${path%% *}" "${path#* }" "$touched_by"
  done
}

# Gate 2: .github/ must match ------------------------------------------------

gate_github_dir() {
  header ".github/ parity"
  local diff
  diff=$(git diff --name-status "$BASE_REF" "$HEAD_REF" -- .github/ || true)
  if [[ -z "$diff" ]]; then
    gate_pass ".github/ identical on $BASE_REF and $HEAD_REF"
    return
  fi
  gate_fail ".github/ differs between $BASE_REF and $HEAD_REF" "$(printf '%s\n' "$diff" | wc -l | tr -d ' ') paths"
  printf '%s\n' "$diff" | sed 's/^/    /'
}

# Gate 3: lockfile resolution ------------------------------------------------

# Prints "name version scope" per package for the lockfile PATH at REF,
# keeping only the highest version per name. scope is dev/runtime for npm
# and crate for Cargo.
lockfile_versions() {
  local ref="$1" path="$2"
  case "$path" in
    *package-lock.json)
      git show "$ref:$path" | "$JQ_BIN" -r '.packages | to_entries[]
        | select(.key | contains("node_modules/"))
        | select(.value.version != null)
        | "\(.key | sub(".*node_modules/"; "")) \(.value.version) \(if .value.dev then "dev" else "runtime" end)"'
      ;;
    *Cargo.lock)
      git show "$ref:$path" | awk -F'"' '
        /^name = /    { name = $2 }
        /^version = / { if (name != "") { print name " " $2 " crate"; name = "" } }'
      ;;
  esac | sort -k1,1 -k2,2V | awk '{ last[$1] = $0 } END { for (k in last) print last[k] }' | sort -k1,1
}

# Runs the resolution comparison for one lockfile path.
compare_lockfile() {
  local path="$1"
  local head_newer=0 base_newer=0 head_lines="" name base_ver head_ver head_scope newest line
  if [[ -z "$(blob_at "$BASE_REF" "$path")" ]]; then
    gate_skip "$path" "not present on $BASE_REF"
    return
  fi
  if [[ "$path" == *package-lock.json && -z "$JQ_BIN" ]]; then
    gate_skip "$path" "needs jq or jaq"
    return
  fi
  while read -r name base_ver _ head_ver head_scope; do
    [[ "$base_ver" == "$head_ver" ]] && continue
    newest=$(printf '%s\n%s\n' "$base_ver" "$head_ver" | sort -V | tail -1)
    if [[ "$newest" == "$head_ver" ]]; then
      head_newer=$((head_newer + 1))
      line=$(printf '    %-8s %-44s %s=%-14s %s=%s' "$head_scope" "$name" "$BASE_REF" "$base_ver" "$HEAD_REF" "$head_ver")
      head_lines+="$line"$'\n'
    else
      base_newer=$((base_newer + 1))
    fi
  done < <(join <(lockfile_versions "$BASE_REF" "$path") <(lockfile_versions "$HEAD_REF" "$path"))
  if [[ $head_newer -eq 0 ]]; then
    gate_pass "$path: nothing newer on $HEAD_REF ($base_newer packages newer on $BASE_REF, awaiting release)"
    return
  fi
  gate_fail "$path: $head_newer packages newer on $HEAD_REF" "$base_newer newer on $BASE_REF, awaiting release"
  printf '%s' "$head_lines"
}

gate_lockfiles() {
  header "Lockfile resolution"
  local paths path
  paths=$(git ls-tree -r --name-only "$HEAD_REF" | grep -E "$LOCKFILE_PATTERN" || true)
  if [[ -z "$paths" ]]; then
    gate_skip "lockfiles" "no package-lock.json or Cargo.lock on $HEAD_REF"
    return
  fi
  while IFS= read -r path; do
    [[ -n "$path" ]] && compare_lockfile "$path"
  done <<<"$paths"
}

# Main -----------------------------------------------------------------------

main() {
  maybe_fetch
  require_ref "$BASE_REF"
  require_ref "$HEAD_REF"
  resolve_anchor
  gate_head_commits
  gate_github_dir
  gate_lockfiles

  if [[ -n "$RESULT_FILE" ]]; then
    printf "%d %d %d\n" "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" >"$RESULT_FILE"
  else
    print_summary
  fi
  [[ $FAIL_COUNT -eq 0 ]] || exit 1
}

main "$@"
