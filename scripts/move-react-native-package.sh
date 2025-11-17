#!/bin/bash

set -e

SAVED_ROOT_FILES_NAME="saved-root-files"

# Parse command line arguments
help_text_and_exit() {
  cat <<END
Usage:   bash move-react-native-package.sh [--reverse] [--help]
Example:
bash move-react-native-package.sh --reverse
bash move-react-native-package.sh --help

This script is used as a part of Patching React Native. See:
https://www.notion.so/wanderlog/Patching-React-Native-17b4797ed24d481eb2155c9daec1ba98?source=copy_link

We need to do this because the installed NPM package consists of files within
the /packages/react-native directory. Since we install from Github, we need to
create a tag with those files at the root.

This script moves the react-native package to the root directory and updates
the .gitignore. It saves the moved files in a directory called
$SAVED_ROOT_FILES_NAME.

If --reverse is passed, all operations are reversed.

END
  exit 1
}

while [ $# -gt 0 ]; do
  case $1 in
    --reverse) REVERSE=true; shift 1;;
    --help) help_text_and_exit;
  esac
done

echo "Starting react-native package move script..."


# Get the repository root directory
# We want this directory to be correct even if the script has been moved by
# itself.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_BASENAME=$(basename "$PARENT_DIR")

if [ "$PARENT_BASENAME" = "$SAVED_ROOT_FILES_NAME" ]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
cd "$REPO_ROOT"

SAVED_ROOT_FILES_PATH="$REPO_ROOT/$SAVED_ROOT_FILES_NAME"

# Reverse moves
if [ "$REVERSE" = true ]; then
  echo "Reversing operations: moving files from $SAVED_ROOT_FILES_NAME back to root..."
  
  if [ ! -d "$SAVED_ROOT_FILES_PATH" ]; then
    echo "Error: $SAVED_ROOT_FILES_NAME directory not found. Nothing to reverse."
    exit 1
  fi
  
  echo "Moving react-native package contents to within saved-root-files/packages"    # Ensure the directory exists
  mkdir -p "$SAVED_ROOT_FILES_PATH/packages/react-native"

  for item in "$REPO_ROOT"/*; do
    item_name=$(basename "$item")
    if [ "$item_name" != "$SAVED_ROOT_FILES_NAME" ]; then
      echo "Moving $item_name back to packages/react-native"
      mv -f "$item" "$SAVED_ROOT_FILES_NAME/packages/react-native/"
    fi
  done

  echo "Moving .gitignore back to root"
  mv -f "$SAVED_ROOT_FILES_PATH/.gitignore" "$REPO_ROOT/.gitignore"
  
  echo "Moving all files back to root"
  mv -f "$SAVED_ROOT_FILES_PATH"/* "$REPO_ROOT/"

  echo "Deleting $SAVED_ROOT_FILES_NAME"
  rm -rf "$SAVED_ROOT_FILES_PATH"

  echo "Reverse operation completed successfully"
  exit 0
fi

# Check if we've already moved the package
if [ -d "$SAVED_ROOT_FILES_PATH" ]; then
  echo "Error: $SAVED_ROOT_FILES_NAME directory already exists. Nothing to do."
  exit 1
fi

mkdir -p "$SAVED_ROOT_FILES_PATH/packages"

echo "Saving existing .gitignore to saved-root-files/.gitignore"
cp -f "$REPO_ROOT/.gitignore" "$SAVED_ROOT_FILES_PATH/.gitignore"

echo "Updating .gitignore to add, modify, and delete lines"
# On macOS, sed -i requires an extension argument (use empty string for in-place)
# Remove /packages/react-native from paths
sed -i '' 's|/packages/react-native/|/|g' "$REPO_ROOT/.gitignore"

# Remove any lines that remove things we want to keep
# We determined these by doing these steps, and then repeating them until we
# didn't miss any files:
#
# 1. Doing `yarn add react-native@^0.81.5`
# 2. Listing the files by doing `find node_modules/react-native > originalFiles.txt`
# 3. Installing our fork of react-native
# 4. Running the same command to list the files again
# 5. Diffing the two files to see what was missed
sed -E -i '' '/^\/?vendor/d' "$REPO_ROOT/.gitignore"
sed -E -i '' '/^\/?sdks\/hermesc/d' "$REPO_ROOT/.gitignore"
sed -i '' '/types_generated/d' "$REPO_ROOT/.gitignore"
sed -i '' '/FBReactNativeSpec/d' "$REPO_ROOT/.gitignore"
echo "/saved-root-files/" >> "$REPO_ROOT/.gitignore"

echo "Moving all files to $SAVED_ROOT_FILES_PATH"
for item in "$REPO_ROOT"/*; do
  item_name=$(basename "$item")
  # Skip the directory itself
  if [ "$item_name" != "$SAVED_ROOT_FILES_NAME" ]; then
    echo "Moving $item_name to $SAVED_ROOT_FILES_PATH"
    mv -f "$item" "$SAVED_ROOT_FILES_PATH/"
  fi
done  

echo "Moving /packages/react-native contents to root..."
  
mv -f "$SAVED_ROOT_FILES_PATH/packages/react-native"/* "$REPO_ROOT/"

echo "Script completed successfully"
