#!/usr/bin/env bash
# Cut a new macOS release of WebcamCircle.
#
# Usage:
#   scripts/release-mac.sh <new-version> <release-notes>
#
# Example:
#   scripts/release-mac.sh 0.2.0 "Fix camera permission prompt"
#
# What it does, in order:
#   1. Bumps the version field in package.json
#   2. Updates the Trajano81 mac download URLs in readme.md
#   3. Rebuilds both DMGs (arm64 + x64)
#   4. Commits and pushes the version bump to main
#   5. Tags the commit and pushes the tag
#   6. Creates a GitHub release with both DMGs attached
#
# Exits early on any failure. The Windows download URL is not touched.

set -euo pipefail

REPO="Trajano81/WebcamCircle"

if [ $# -ne 2 ]; then
	cat >&2 <<USAGE
Usage: $0 <new-version> <release-notes>
Example: $0 0.2.0 "Fix camera permission prompt"
USAGE
	exit 1
fi

NEW_VERSION="$1"
NOTES="$2"

if ! git diff --quiet HEAD; then
	echo "Error: working tree is dirty. Commit or stash first." >&2
	exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
	echo "Error: must be on main (currently on $CURRENT_BRANCH)." >&2
	exit 1
fi

if git rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
	echo "Error: tag $NEW_VERSION already exists locally." >&2
	exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
	echo "Error: gh CLI not installed. https://cli.github.com/" >&2
	exit 1
fi

OLD_VERSION=$(node -e "console.log(require('./package.json').version)")
if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
	echo "Error: new version equals current version ($OLD_VERSION)." >&2
	exit 1
fi

echo "Releasing $OLD_VERSION -> $NEW_VERSION on $REPO"

# Bump package.json version (preserves tab indentation)
sed -i.bak "s|\"version\": \"$OLD_VERSION\"|\"version\": \"$NEW_VERSION\"|" package.json
rm package.json.bak

# Update only the Trajano81 mac download URLs in readme.md
sed -i.bak "s|$REPO/releases/download/$OLD_VERSION/WebcamCircle-$OLD_VERSION-|$REPO/releases/download/$NEW_VERSION/WebcamCircle-$NEW_VERSION-|g" readme.md
rm readme.md.bak

# Rebuild
rm -rf dist
npm run dist:mac

ARM64_DMG="dist/WebcamCircle-$NEW_VERSION-arm64.dmg"
X64_DMG="dist/WebcamCircle-$NEW_VERSION-x64.dmg"
if [ ! -f "$ARM64_DMG" ] || [ ! -f "$X64_DMG" ]; then
	echo "Error: expected DMGs not produced under dist/." >&2
	exit 1
fi

# Commit and push
git add package.json readme.md
git commit -m "chore: bump to $NEW_VERSION"
git push origin main

# Tag and push tag
git tag -a "$NEW_VERSION" -m "$NEW_VERSION"
git push origin "$NEW_VERSION"

# Create release with both DMGs as assets
gh release create "$NEW_VERSION" \
	"$ARM64_DMG" \
	"$X64_DMG" \
	--repo "$REPO" \
	--title "$NEW_VERSION" \
	--notes "$NOTES"

echo ""
echo "Done. https://github.com/$REPO/releases/tag/$NEW_VERSION"
