// @flow
const {
  downloadHermesSourceTarball,
  expandHermesSourceTarball,
} = require('../packages/react-native/scripts/hermes/hermes-utils');
const { REPO_ROOT } = require('./consts');
const fs = require('fs');
const { rm } = require('fs/promises');
const {cp, exec} = require('shelljs');

/**
 * This script is used as a part of Patching React Native. See:
 * https://www.notion.so/wanderlog/Patching-React-Native-17b4797ed24d481eb2155c9daec1ba98?source=copy_link
 * 
 * This section goes over how we created it:
 * ["How did we figure out the steps for Create scripts for building patched React Native](https://www.notion.so/wanderlog/Patching-React-Native-17b4797ed24d481eb2155c9daec1ba98?source=copy_link#2aef9a6861f68016a0def8edec2d3d5a)
 * 
 * Much of this code is copied from buildArtifactsLocally in
 * scripts/release-testing/utils/testing-utils.js
 *
 * The main goal is to build hermesc so it can be checked in to our built
 * version.
 * 
 * If this script fails, we can debug it by running it with `CI=true` to see
 * all the intermediate commands the Shell scripts run, since the scripts
 * enable `set -x` when `CI` is set.
 */
async function buildPackage() {
  const reactNativePackagePath = `${REPO_ROOT}/packages/react-native`;

  // Start copied from scripts/release-testing/utils/testing-utils.js
  const hermesCoreSourceFolder = `${reactNativePackagePath}/sdks/hermes`;

  if (!fs.existsSync(hermesCoreSourceFolder)) {
    console.info('The Hermes source folder is missing. Downloading...');
    downloadHermesSourceTarball();
    expandHermesSourceTarball();
  }

  // need to move the scripts inside the local hermes cloned folder
  // cp sdks/hermes-engine/utils/*.sh <your_hermes_checkout>/utils/.
  cp(
    `${reactNativePackagePath}/sdks/hermes-engine/hermes-engine.podspec`,
    `${reactNativePackagePath}/sdks/hermes/hermes-engine.podspec`,
  );
  cp(
    `${reactNativePackagePath}/sdks/hermes-engine/hermes-utils.rb`,
    `${reactNativePackagePath}/sdks/hermes/hermes-utils.rb`,
  );
  cp(
    `${reactNativePackagePath}/sdks/hermes-engine/utils/*.sh`,
    `${reactNativePackagePath}/sdks/hermes/utils/.`,
  );
  // End copied from scripts/release-testing/utils/testing-utils.js

  // Builds the types_generated. We figured this out by asking:
  // "What code in this project creates the types_generated directory?"
  exec('yarn build-types', {cwd: REPO_ROOT});
  // Builds the FBReactNativeSpec. We figured this out by asking:
  // "What code in this project creates the FBReactNativeSpec directory?"
  exec('yarn install && yarn prepack', {cwd: reactNativePackagePath});
  // We don't need the README.md file
  await rm(`${reactNativePackagePath}/README.md`);

  process.env.MAC_DEPLOYMENT_TARGET = "10.15";

  // This command builds hermes and hermesc binaries for MacOS. I figured out
  // this by:
  //
  // 1. Running `find . -name hermes` and seeing that the file was in
  //    `./packages/react-native/sdks/hermes/build_macosx/bin/hermes`
  // 2. Finding references to build_macosx and seeing it was likely created
  //    by the build_apple_framework function
  // 3. Finding callers of the build_apple_framework function
  exec(
    'bash ./utils/build-mac-framework.sh',
    {cwd: `${reactNativePackagePath}/sdks/hermes`},
  );

  // We figured out the files to copy by running:
  // `find . -name hermesc` and and `find . -name hermes | grep bin`
  //
  // We figured out the destination directory by looking at the the paths in
  // the official React Native NPM package: https://www.npmjs.com/package/react-native/v/0.81.5?activeTab=code
  const hermesDir = `${reactNativePackagePath}/sdks/hermes/build_macosx/bin`;
  const hermescDir = `${reactNativePackagePath}/sdks/hermes/build_host_hermesc/bin`;
  const destinationDir = `${reactNativePackagePath}/sdks/hermesc/osx-bin`;
  console.info(`Copying files from ${hermesDir} to ${destinationDir}`);
  console.info(`Copying files from ${hermescDir} to ${destinationDir}`);
  await fs.promises.mkdir(destinationDir, { recursive: true });
  cp('-r', `${hermesDir}/*`, `${destinationDir}/`);
  cp('-r', `${hermescDir}/*`, `${destinationDir}/`);
}

buildPackage();
