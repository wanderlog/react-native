# Wanderlog-specific patches

If you add a non-backport patch, add it here. It's useful when we want to 
rebase on upstream's `main`

- Unset certain environment variables so NVM doesn't conflict
  - Summary: fixes a build process issue with `find-node.sh` script
  - Issues:
    - https://github.com/react-native-community/upgrade-support/issues/138
  - Pull requests:
    - These are not ours, but could potentially fix them:
    - https://github.com/facebook/react-native/pull/31380 
- Add Wanderlog-specific README and instructions
  - Summary: not a code change, but adds documentation that makes this fork 
    easier to work with
- Fix crashes due to "JS functions are not convertible to dynamic" errors
  - Pull request: none (this is a bit hack-ish)
- Fix Pressables not being tappable PanResponder Views on Android
  - Related commit:
    - Moved logic restricting move events from ReactRootView to JSTouchDispatcher
  - Possibly not needed based on comment in https://github.com/facebook/react-native/pull/29533
  - Pull request: https://github.com/facebook/react-native/pull/29533
- Fix to make taps on views outside parent bounds work on Android
  - Related commits:
    - Made bounds checks also run on overflow: scroll Views
    - Fixed behavior for ReactCompoundViewGroups for react-native-svg
  - Pull request:
    - Code: https://github.com/facebook/react-native/pull/29039
    - Tests: https://github.com/facebook/react-native/pull/29393
- Avoid race conditions when setting RCTNetworkTask status
  - We got a bunch of annoying warnings of "Task orphaned for request <NSMutableURLRequest: [[SOME_HEX_CODE]]> { URL: [[IMG_URL]] }"; this fixes the race condition that caused it
  - Pull request: https://github.com/facebook/react-native/pull/28962
- Fixed disabling removing italic/bold style on TextInput
  - Related commits:
    - Retitled test view, removed extraneous import
    - Fixed linting for new example
  - Pull request: https://github.com/facebook/react-native/pull/28868
- Fixed build.gradle for facebook#28298
  - Summary: RNTester didn't build properly for testing
  - Pull request: None
  - Other relevant links: https://github.com/facebook/react-native/issues/28298
- Fix VirtualizedList jumping on Android keyboard open with wrong getItemLayout
  - Summary: Our list was jumping when the keyboard opened, so we made Android lists ignore keyboard openings.
  - Pull request: https://github.com/facebook/react-native/pull/32268
- Create publishAllToGitLab task for Maven; build-ios-artifacts for hermesc
  - Summary: To publish our own versions of React Native for Android, we need to create a package and upload it to a "package repository"
  - Pull request: None
- Prevent crash when runAnimationStep called with low frameTimeNanos
  - Summary: React Native was crashing on OnePlus and Oppo devices. This is a workaround
  - Pull request: https://github.com/facebook/react-native/pull/37487
- Fixed boost download path for iOS & Android builds
  - Summary: The previous download for boost, required by React Native, no longer works. Updated the download to match the one currently pulled by react-native. This is a Wanderlog-only patch to match our fork to what's currently on React Native.
  - Pull request: https://github.com/wanderlog/react-native/pull/8
