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
    expect(attributes).toMatchObject({
      bubblingEventTypes: {
        topDefaultBubble: {phasedRegistrationNames: {}},
        topOwnBubble: {phasedRegistrationNames: {}},
      },
      directEventTypes: {
        topDefaultDirect: {registrationName: 'onDefault'},
        topOwnDirect: {registrationName: 'onOwnDirect'},
      },
    });
  });

  it('calls the default event types binding once across components', () => {
    const getDefaultEventTypes = jest.fn(() => ({}));
    // $FlowExpectedError[cannot-write]
    global.RN$LegacyInterop_UIManager_getDefaultEventTypes =
      getDefaultEventTypes;
    jest.resetModules();

    const getNativeComponentAttributes =
      require('../getNativeComponentAttributes').default;
    getNativeComponentAttributes('RCTTestView');
    getNativeComponentAttributes('RCTOtherTestView');

    expect(getDefaultEventTypes).toHaveBeenCalledTimes(1);
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

    expect(attributes.directEventTypes).toEqual({
      topOwnDirect: {registrationName: 'onOwnDirect'},
    });
  });
});
