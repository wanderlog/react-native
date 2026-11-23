#!/bin/bash

set -e

help_text_and_exit() {
  if [ -n "$1" ]; then
    echo "$1"
    echo
  fi
  cat <<'END'
Usage:   bash scripts/wanderlog-release.sh <version>
Example: bash scripts/wanderlog-release.sh 0.86.3-wanderlog.3

Publishes the current *-wanderlog branch as @wanderlogapp/react-native:

1. Builds the generated files the npm package needs (hermesc, codegen output,
   TypeScript types) with scripts/build-package.js
2. Uploads the Android artifacts to GitLab's Maven registry. The app's Android
   build downloads React Native from there instead of compiling it
3. Publishes packages/react-native to npm
4. Tags the commit as v<version> so we can tell what each release contains

See "Part 3: Publishing a built version" in Patching React Native for the
one-time setup this needs:
https://app.notion.com/p/wanderlog/Patching-React-Native-17b4797ed24d481eb2155c9daec1ba98
END
  exit 1
}

NEW_VERSION="$1"
if [ -z "$NEW_VERSION" ] || [ "$NEW_VERSION" = "--help" ]; then
  help_text_and_exit
fi

packageName='@wanderlogapp/react-native'
tagName="v$NEW_VERSION"
repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
packageDir="$repoRoot/packages/react-native"
check_prerequisites() {
  cd "$repoRoot"

  local branch
  branch="$(git branch --show-current)"
  if [[ "$branch" != *-wanderlog ]]; then
    help_text_and_exit "Check out the version branch you want to release (e.g., 0.86.3-wanderlog). You're on '$branch'."
  fi
  # Untracked files are fine: the build leaves some behind (e.g.,
  # react-native-compatibility-check/dist), and npm only packs what's listed in
  # packages/react-native/package.json's "files"
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    help_text_and_exit 'Commit or stash your changes first, so the release matches what is on GitHub.'
  fi
  git pull --ff-only
  git fetch --tags

  if git rev-parse -q --verify "refs/tags/$tagName" > /dev/null; then
    help_text_and_exit "Tag $tagName already exists. Pick the next version number."
  fi
  if npm view "$packageName@$NEW_VERSION" version > /dev/null 2>&1; then
    help_text_and_exit "$packageName@$NEW_VERSION is already on npm. Pick the next version number."
  fi
  if [ "$(npm whoami 2> /dev/null)" != 'wanderlogapp' ]; then
    help_text_and_exit 'Run `npm login` and log in as wanderlogapp.'
  fi
  if ! grep -q '^gitlabPrivateToken=.' ~/.gradle/gradle.properties 2> /dev/null; then
    help_text_and_exit 'Add gitlabPrivateToken=glpat-... to ~/.gradle/gradle.properties. See the Notion doc linked below.'
  fi
  if ! command -v cmake > /dev/null; then
    help_text_and_exit 'Install cmake with `brew install cmake`.'
  fi
}

# Undo the changes the release makes to tracked files. We checked that there
# were none before we started, so this only reverts:
# - The release name and version. We only set them while publishing, since the
#   other workspaces in this repo depend on "react-native": "<upstream
#   version>", and committing the change would break yarn install for RNTester
# - The README that the package's prepack script copies into
#   packages/react-native
restore_tracked_files() {
  cd "$repoRoot"
  git checkout -- .
}

check_prerequisites

trap restore_tracked_files EXIT

# Build before changing the version, since this runs yarn install, which fails
# once react-native's version no longer matches what the other workspaces want
node scripts/build-package.js

(cd "$packageDir" && npm pkg set name="$packageName" version="$NEW_VERSION")
sed -i '' "s/^VERSION_NAME=.*/VERSION_NAME=$NEW_VERSION/" packages/react-native/ReactAndroid/gradle.properties

./gradlew publishAllToGitLab

# --ignore-scripts skips the prepack script, since build-package.js already ran
# it
(cd "$packageDir" && npm publish --access public --ignore-scripts)

git tag "$tagName"
git push origin "$tagName"

cat <<END

Published $packageName@$NEW_VERSION and pushed tag $tagName.

Next, in itineraries, set mobile/package.json's react-native dependency to
"npm:$packageName@$NEW_VERSION" and run yarn install.
END
