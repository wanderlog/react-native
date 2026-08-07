/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow
 * @format
 */

const {REACT_NATIVE_PACKAGE_DIR, REPO_ROOT} = require('./shared/consts');
const fs = require('fs');
const path = require('path');
const {cp, exec} = require('shelljs');

/**
 * This script is used as a part of Patching React Native. See:
 * https://www.notion.so/wanderlog/Patching-React-Native-17b4797ed24d481eb2155c9daec1ba98?source=copy_link
 *
 * This script prepares the react-native npm package for publishing from our fork.
 * It mirrors the upstream release pipeline in 0.86:
 * - yarn build
 * - yarn build-types
 * - react-native prepack (codegen + README)
 * - copy hermesc binaries into sdks/hermesc for GitHub installs
 *
 * If this script fails, we can debug it by running it with `CI=true` to see
 * all the intermediate commands the Shell scripts run, since the scripts
 * enable `set -x` when `CI` is set.
 */
async function buildPackage() {
  if (exec('yarn install', {cwd: REPO_ROOT}).code !== 0) {
    process.exit(1);
  }

  if (exec('yarn build', {cwd: REPO_ROOT}).code !== 0) {
    process.exit(1);
  }

  if (exec('yarn build-types --skip-snapshot', {cwd: REPO_ROOT}).code !== 0) {
    process.exit(1);
  }

  if (
    exec('node ./scripts/prepack.js', {cwd: REACT_NATIVE_PACKAGE_DIR}).code !==
    0
  ) {
    process.exit(1);
  }

  await copyHermescBinaries();
}

async function copyHermescBinaries() {
  let hermesCompilerRoot;
  try {
    hermesCompilerRoot = path.dirname(
      require.resolve('hermes-compiler', {
        paths: [REPO_ROOT, REACT_NATIVE_PACKAGE_DIR],
      }),
    );
  } catch (error) {
    console.warn(
      '[build-package] hermes-compiler not found; skipping hermesc copy.',
    );
    return;
  }

  const osxBinSource = path.join(hermesCompilerRoot, 'hermesc', 'osx-bin');
  const destinationDir = path.join(
    REACT_NATIVE_PACKAGE_DIR,
    'sdks/hermesc/osx-bin',
  );

  if (!fs.existsSync(osxBinSource)) {
    console.warn(
      `[build-package] hermesc osx-bin not found at ${osxBinSource}; skipping copy.`,
    );
    return;
  }

  console.info(`Copying hermesc from ${osxBinSource} to ${destinationDir}`);
  await fs.promises.mkdir(destinationDir, {recursive: true});
  cp('-r', `${osxBinSource}/*`, `${destinationDir}/`);
}

if (require.main === module) {
  void buildPackage();
}

module.exports = {buildPackage};
