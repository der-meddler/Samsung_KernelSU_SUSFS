#!/usr/bin/env bash
# Regenerate patches/a556b from jimsterino's branch in WildKernels/Samsung_Kernels and decide
# whether it differs from the set this repo carries. Used by
# .github/workflows/sync-wildkernels-patches.yml, and runnable by hand with the same result:
#
#   WORK=/tmp/wksync scripts/wk-patch-sync.sh
#
# How the set is built: his branch is a Samsung import followed by his own small commits.
# Instead of one patch per commit (which breaks as soon as he adds something and later removes
# it again), the patches are the NET difference between his last import commit and his branch
# tip, one patch per changed file, relative to the Linux tree root (our layout). His
# scripts/setlocalversion BUILD_NUMBER edit is left out: the source action derives it from
# the source tag.
#
# How "changed" is decided: both the current set and the new set are applied in order, with
# the same `patch -p1` the build uses, to a sparse clone of A556B-source. The set changed if
# the resulting trees differ. Patch names, headers and hunk context do not matter.
#
# Environment (all optional):
#   WK_BRANCH         his branch                                  [SM-A556B-Oneui7]
#   WK_REPO           his repository                              [https://github.com/WildKernels/Samsung_Kernels.git]
#   SRC_REPO          our source repository                       [https://github.com/der-meddler/A556B-source.git]
#   SRC_REF           branch or tag of it to check against        [main]
#   PATCH_DIR         the current patch set                       [<repo>/patches/a556b]
#   WORK              scratch directory (recreated)               [./wk-sync]
#   IMPORT_MIN_FILES  a commit touching more kernel/ files than this is a Samsung import [200]
# Results: $WORK/new-patches/*.patch, $WORK/report.md, and `changed=true|false` on stdout and
# in $GITHUB_OUTPUT when that is set. Exit status 1 means the new set does not apply.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WK_BRANCH=${WK_BRANCH:-SM-A556B-Oneui7}
WK_REPO=${WK_REPO:-https://github.com/WildKernels/Samsung_Kernels.git}
SRC_REPO=${SRC_REPO:-https://github.com/der-meddler/A556B-source.git}
SRC_REF=${SRC_REF:-main}
PATCH_DIR=${PATCH_DIR:-$ROOT/patches/a556b}
WORK=${WORK:-$PWD/wk-sync}
IMPORT_MIN_FILES=${IMPORT_MIN_FILES:-200}

PATCH_DIR=$(cd "$PATCH_DIR" && pwd)
rm -rf "$WORK"; mkdir -p "$WORK/new-patches"
WORK=$(cd "$WORK" && pwd)
REPORT=$WORK/report.md
: > "$REPORT"

out() { echo "$1"; [ -n "${GITHUB_OUTPUT:-}" ] && echo "$1" >> "$GITHUB_OUTPUT"; return 0; }

# ---- his branch: find the last Samsung import, then the net change after it ------------------
# blobless and without checkout: commit metadata plus the few blobs the diffs need
git clone -q --filter=blob:none --no-checkout --single-branch -b "$WK_BRANCH" "$WK_REPO" "$WORK/wk"
cd "$WORK/wk"
TIP=$(git rev-parse HEAD)
BASE=""
for c in $(git rev-list --reverse HEAD); do
  n=$(git diff-tree --no-commit-id -r --name-only "$c" | grep -c '^kernel/' || true)
  [ "$n" -gt "$IMPORT_MIN_FILES" ] && BASE=$c
done
if [ -z "$BASE" ]; then
  echo "no Samsung import commit (more than $IMPORT_MIN_FILES kernel/ files) on $WK_BRANCH" >&2
  exit 1
fi

{
  echo "Branch \`$WK_BRANCH\` at \`${TIP:0:9}\`, last Samsung import \`${BASE:0:9}\`: $(git log -1 --format=%s "$BASE")"
  echo
  echo "His commits since that import touching kernel/:"
  git log --reverse --format='- `%h` %ad %s' --date=short "$BASE..$TIP" -- kernel/ || true
  echo
} >> "$REPORT"

mapfile -t FILES < <(git diff --name-only "$BASE" "$TIP" -- kernel/ ':(exclude)kernel/scripts/setlocalversion' | sort)
i=0
for f in "${FILES[@]}"; do
  i=$((i + 1))
  rel=${f#kernel/}
  name=$(printf '%04d-%s.patch' "$i" "$(echo "$rel" | tr '/' '-')")
  {
    echo "Net change to $rel on WildKernels/Samsung_Kernels $WK_BRANCH"
    echo "(${BASE:0:12}..${TIP:0:12}), from these commits:"
    git log --reverse --format='  %h %s' "$BASE..$TIP" -- "$f"
    echo
    git diff "$BASE" "$TIP" --relative=kernel -- "$f"
  } > "$WORK/new-patches/$name"
done
{
  if [ "$i" -eq 0 ]; then
    echo "Net change: none (his edits cancel out, or he has none besides BUILD_NUMBER)."
  else
    echo "Net change, one patch per file:"
    for p in "$WORK"/new-patches/*.patch; do echo "- \`$(basename "$p")\`"; done
  fi
  echo
} >> "$REPORT"
echo "generated $i patch(es) from ${BASE:0:9}..${TIP:0:9}"

# ---- our source: apply both sets the way the build does and compare the result ---------------
cd "$WORK"
mapfile -t PATHS < <(cat "$PATCH_DIR"/*.patch new-patches/*.patch 2>/dev/null \
  | sed -n 's|^diff --git a/\([^ ]*\) b/.*|/\1|p' | sort -u)
git clone -q --depth 1 --filter=blob:none --sparse -b "$SRC_REF" "$SRC_REPO" src
[ "${#PATHS[@]}" -gt 0 ] && git -C src sparse-checkout set --no-cone "${PATHS[@]}"
SRC_SHA=$(git -C src rev-parse HEAD)

# apply_set <label> <patch>... : prints the resulting diff of src to <label>.diff; status 1 if a patch fails
apply_set() {
  local label=$1; shift
  git -C src reset -q --hard; git -C src clean -fdq
  for p in "$@"; do
    if ! patch -p1 -d src --forward --no-backup-if-mismatch -s < "$p" > "$label.log" 2>&1; then
      echo "$label: $(basename "$p") does not apply"; cat "$label.log"
      return 1
    fi
  done
  git -C src add -A --sparse
  git -C src diff --cached > "$label.diff"
}

shopt -s nullglob
OLD=("$PATCH_DIR"/*.patch)
NEW=(new-patches/*.patch)

old_ok=true
apply_set old "${OLD[@]}" || old_ok=false
if ! apply_set new "${NEW[@]}"; then
  { echo "**The regenerated set does not apply to $SRC_REPO@$SRC_REF (\`${SRC_SHA:0:9}\`).** See the job log."; } >> "$REPORT"
  out "changed=true"
  exit 1
fi

if [ "$old_ok" = false ]; then
  changed=true
  echo "The current set no longer applies to $SRC_REPO@$SRC_REF (\`${SRC_SHA:0:9}\`); the regenerated one does." >> "$REPORT"
elif cmp -s old.diff new.diff; then
  changed=false
  echo "Result: identical to the current set when applied to $SRC_REPO@$SRC_REF (\`${SRC_SHA:0:9}\`)." >> "$REPORT"
else
  changed=true
  { echo "Result: the regenerated set changes the source differently from the current set:"
    echo; echo '```diff'; diff old.diff new.diff | head -n 80 || true; echo '```'; } >> "$REPORT"
fi
out "changed=$changed"
cat "$REPORT"
