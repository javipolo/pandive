#!/usr/bin/env bash
# Cut a release: bump the semver tag, write release/changelog-<version>.txt,
# commit it, tag, build the APK from the tagged commit, push and create the
# GitHub release with the APK attached.
#
#   scripts/release.sh [major|minor|patch]   (default: minor)
#   DRY_RUN=1 scripts/release.sh ...         print version + changelog only
#
# The APK is built *after* tagging so its versionName (from `git describe`)
# is the clean tag (1.2.0), not 1.1.0-5-gabc1234. If the build fails, the
# local commit and tag are undone and nothing is pushed.
set -euo pipefail

BUMP="${1:-minor}"
DRY_RUN="${DRY_RUN:-}"
REMOTE="${REMOTE:-origin}"
BRANCH="main"
RELEASE_DIR="release"
APK="build/app/outputs/flutter-apk/app-release.apk"

die() { echo "release: $*" >&2; exit 1; }

case "$BUMP" in major|minor|patch) ;; *) die "bump must be major, minor or patch (got '$BUMP')";; esac

cd "$(git rev-parse --show-toplevel)"

# --- Version -----------------------------------------------------------------
PREV_TAG="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n1)"
if [[ -n "$PREV_TAG" ]]; then
  IFS=. read -r MAJOR MINOR PATCH <<<"${PREV_TAG#v}"
else
  MAJOR=0 MINOR=0 PATCH=0
fi
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac
VERSION="$MAJOR.$MINOR.$PATCH"
TAG="v$VERSION"
CHANGELOG="$RELEASE_DIR/changelog-$VERSION.txt"
APK_OUT="$RELEASE_DIR/PanDive-Android-$TAG.apk"

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"

# --- Changelog ---------------------------------------------------------------
RANGE="${PREV_TAG:+$PREV_TAG..}HEAD"
# Subjects without merges or previous release commits, oldest first.
mapfile -t SUBJECTS < <(git log --no-merges --reverse --format='%s' "$RANGE" \
  | grep -v '^chore: release v' || true)
[[ ${#SUBJECTS[@]} -gt 0 ]] || die "no changes since ${PREV_TAG:-the beginning}"

section() {  # section <title> <regex of conventional prefixes>
  local title="$1" re="$2" s out=""
  for s in "${SUBJECTS[@]}"; do
    if [[ "$s" =~ ^($re)(\(.*\))?!?:\ *(.*)$ ]]; then
      out+="- ${BASH_REMATCH[3]^}"$'\n'
    fi
  done
  [[ -n "$out" ]] && printf '%s\n\n%s\n' "$title" "$out"
  return 0
}

other() {
  local s out=""
  for s in "${SUBJECTS[@]}"; do
    [[ "$s" =~ ^(feat|fix)(\(.*\))?!?: ]] && continue
    out+="- ${s}"$'\n'
  done
  [[ -n "$out" ]] && printf 'Other changes\n\n%s\n' "$out"
  return 0
}

build_changelog() {
  echo "PanDive $TAG ($(date +%F))"
  echo
  if [[ -n "$PREV_TAG" ]]; then
    echo "Changes since $PREV_TAG (${#SUBJECTS[@]} commits)."
  else
    echo "First release (${#SUBJECTS[@]} commits)."
  fi
  echo
  section "New features" "feat"
  section "Fixes" "fix"
  other
}

NOTES="$(build_changelog)"

echo "Release: ${PREV_TAG:-none} -> $TAG ($BUMP)"
echo "----------------------------------------"
echo "$NOTES"
echo "----------------------------------------"

if [[ -n "$DRY_RUN" ]]; then
  echo "DRY_RUN: nothing done"
  exit 0
fi

# --- Preconditions -----------------------------------------------------------
[[ "$(git rev-parse --abbrev-ref HEAD)" == "$BRANCH" ]] || die "not on $BRANCH"
git diff --quiet HEAD || die "uncommitted changes: commit or stash them first"
command -v gh >/dev/null || die "gh not found"
gh auth status >/dev/null 2>&1 || die "gh is not logged in (gh auth login)"
git fetch -q "$REMOTE" "$BRANCH"
git merge-base --is-ancestor "$REMOTE/$BRANCH" HEAD \
  || die "$REMOTE/$BRANCH has commits you don't have: pull first"

# --- Commit + tag ------------------------------------------------------------
mkdir -p "$RELEASE_DIR"
printf '%s\n' "$NOTES" >"$CHANGELOG"
git add "$CHANGELOG"
git commit -q -m "chore: release $TAG"
git tag -a "$TAG" -m "PanDive $TAG"
echo "Committed $CHANGELOG and tagged $TAG"

undo() {
  echo "release: build failed, undoing the local commit and tag $TAG" >&2
  git tag -d "$TAG" >/dev/null
  git reset -q --hard HEAD~1
}

# --- Build (from the tagged commit) ------------------------------------------
if ! make apk; then undo; exit 1; fi
cp "$APK" "$APK_OUT"
echo "APK: $APK_OUT"

# --- Push + GitHub release ---------------------------------------------------
git push --atomic "$REMOTE" "HEAD:$BRANCH" "refs/tags/$TAG"
gh release create "$TAG" "$APK_OUT" --title "PanDive $TAG" --notes-file "$CHANGELOG" --verify-tag
echo "Released $TAG"
