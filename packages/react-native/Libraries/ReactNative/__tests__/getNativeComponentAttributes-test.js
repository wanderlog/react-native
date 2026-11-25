/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow strict-local
 * @format
 */

'use strict';

// A fresh object per call, since merge() mutates event types in place
const createViewConfig = () => ({
  NativeProps: {},
  bubblingEventTypes: {topOwnBubble: {phasedRegistrationNames: {}}},
  directEventTypes: {topOwnDirect: {registrationName: 'onOwnDirect'}},
});

// Like the iOS bridgeless UIManager: no getDefaultEventTypes method
jest.mock('../UIManager', () => ({
  __esModule: true,
  default: {
    getViewManagerConfig: jest.fn(() => createViewConfig()),
    getConstants: jest.fn(() => {
      throw new Error('getConstants() should not be called');
    }),
  },
}));

describe('getNativeComponentAttributes', () => {
  const originalGetDefaultEventTypes =
    global.RN$LegacyInterop_UIManager_getDefaultEventTypes;

  afterEach(() => {
    // $FlowExpectedError[cannot-write]
    global.RN$LegacyInterop_UIManager_getDefaultEventTypes =
      originalGetDefaultEventTypes;
    jest.resetModules();
  });

  it('merges default event types from the binding without calling getConstants()', () => {
    const getDefaultEventTypes = jest.fn(() => ({
      bubblingEventTypes: {topDefaultBubble: {phasedRegistrationNames: {}}},
      directEventTypes: {topDefaultDirect: {registrationName: 'onDefault'}},
    }));
    // $FlowExpectedError[cannot-write]
    global.RN$LegacyInterop_UIManager_getDefaultEventTypes =
      getDefaultEventTypes;
    jest.resetModules();

    const getNativeComponentAttributes =
      require('../getNativeComponentAttributes').default;
    const attributes = getNativeComponentAttributes('RCTTestView');

    expect(getDefaultEventTypes).toHaveBeenCalledTimes(1);
    expect(Object.keys(attributes.bubblingEventTypes).sort()).toEqual([
      'topDefaultBubble',
      'topOwnBubble',
    ]);
    expect(Object.keys(attributes.directEventTypes).sort()).toEqual([
      'topDefaultDirect',
      'topOwnDirect',
    ]);
  });

  it('handles an empty result, as on iOS', () => {
    // $FlowExpectedError[cannot-write]
    global.RN$LegacyInterop_UIManager_getDefaultEventTypes = jest.fn(
      () => ({}),
    );
    jest.resetModules();

    const getNativeComponentAttributes =
      require('../getNativeComponentAttributes').default;
    const attributes = getNativeComponentAttributes('RCTTestView');

    expect(Object.keys(attributes.directEventTypes)).toEqual(['topOwnDirect']);
  });
});
