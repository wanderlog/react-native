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

jest.unmock('../UIManager');

const GLOBAL_NAMES = [
  'RN$Bridgeless',
  'RN$LegacyInterop_UIManager_getConstants',
  'RN$LegacyInterop_UIManager_getConstantsForViewManager',
  'RN$LegacyInterop_UIManager_getDefaultEventTypes',
];

function getGlobal(name: string): unknown {
  // $FlowExpectedError[prop-missing]
  return global[name];
}

function setGlobal(name: string, value: unknown) {
  // $FlowExpectedError[prop-missing]
  global[name] = value;
}

describe.each(['ios', 'android'])('Bridgeless UIManager on %s', platform => {
  const originalGlobals: {[string]: unknown} = {};
  const fullConstants = {
    LazyViewManagersEnabled: true,
    ViewManagerNames: ['RCTTestView'],
  };
  const viewManagerConfig = {Commands: {focus: 1}};
  const defaultEventTypes = {bubblingEventTypes: {}, directEventTypes: {}};
  let getConstants: JestMockFn<[], unknown>;
  let getConstantsForViewManager: JestMockFn<[string], unknown>;
  let getDefaultEventTypes: JestMockFn<[], unknown>;

  beforeEach(() => {
    for (const name of GLOBAL_NAMES) {
      originalGlobals[name] = getGlobal(name);
    }
    getConstants = jest.fn(() => fullConstants);
    getConstantsForViewManager = jest.fn(() => viewManagerConfig);
    getDefaultEventTypes = jest.fn(() => defaultEventTypes);
    setGlobal('RN$Bridgeless', true);
    setGlobal('RN$LegacyInterop_UIManager_getConstants', getConstants);
    setGlobal(
      'RN$LegacyInterop_UIManager_getConstantsForViewManager',
      getConstantsForViewManager,
    );
    setGlobal(
      'RN$LegacyInterop_UIManager_getDefaultEventTypes',
      getDefaultEventTypes,
    );
    jest.resetModules();
    jest.doMock('../../Utilities/Platform', () => ({
      OS: platform,
      select: (spec: {[string]: unknown}) =>
        spec[platform] ?? spec.native ?? spec.default,
    }));
  });

  afterEach(() => {
    for (const name of GLOBAL_NAMES) {
      setGlobal(name, originalGlobals[name]);
    }
    jest.restoreAllMocks();
    jest.resetModules();
  });

  it('does not build any view configs when imported', () => {
    const UIManager = require('../UIManager').default;

    expect(getConstants).not.toHaveBeenCalled();
    expect(getConstantsForViewManager).not.toHaveBeenCalled();
    expect(
      Object.getOwnPropertyDescriptor(UIManager, 'RCTTestView'),
    ).toBeUndefined();
  });

  it('fetches and caches one view manager config at a time', () => {
    const UIManager = require('../UIManager').default;

    expect(UIManager.getViewManagerConfig('RCTTestView')).toBe(
      viewManagerConfig,
    );
    expect(UIManager.getViewManagerConfig('RCTTestView')).toBe(
      viewManagerConfig,
    );
    expect(getConstantsForViewManager).toHaveBeenCalledTimes(1);
    expect(getConstantsForViewManager).toHaveBeenCalledWith('RCTTestView');

    // Unknown names are cached too
    getConstantsForViewManager.mockReturnValueOnce(null);
    expect(UIManager.getViewManagerConfig('NotAViewManager')).toBeNull();
    expect(UIManager.getViewManagerConfig('NotAViewManager')).toBeNull();
    expect(getConstantsForViewManager).toHaveBeenCalledTimes(2);

    expect(getConstants).not.toHaveBeenCalled();
  });

  it('does not fall back to the full constants without the per-manager binding', () => {
    setGlobal('RN$LegacyInterop_UIManager_getConstantsForViewManager', null);
    const consoleError = jest
      .spyOn(console, 'error')
      .mockImplementation(() => {});
    const UIManager = require('../UIManager').default;

    expect(UIManager.getViewManagerConfig('RCTTestView')).toBeNull();
    expect(consoleError).toHaveBeenCalledTimes(1);
    expect(getConstants).not.toHaveBeenCalled();
  });

  it('caches the default event types', () => {
    const UIManager = require('../UIManager').default;

    expect(UIManager.getDefaultEventTypes?.()).toBe(defaultEventTypes);
    expect(UIManager.getDefaultEventTypes?.()).toBe(defaultEventTypes);
    expect(getDefaultEventTypes).toHaveBeenCalledTimes(1);
  });

  it('still returns the full constants from getConstants()', () => {
    const UIManager = require('../UIManager').default;

    expect(UIManager.getConstants()).toBe(fullConstants);
    expect(UIManager.getConstants()).toBe(fullConstants);
    expect(getConstants).toHaveBeenCalledTimes(1);
  });
});

describe('Bridgeless UIManager on android', () => {
  afterEach(() => {
    setGlobal('RN$Bridgeless', undefined);
    setGlobal(
      'RN$LegacyInterop_UIManager_getConstantsForViewManager',
      undefined,
    );
    jest.resetModules();
  });

  it('shares the config cache with getConstantsForViewManager', () => {
    const viewManagerConfig = {Commands: {}};
    const getConstantsForViewManager = jest.fn(() => viewManagerConfig);
    setGlobal('RN$Bridgeless', true);
    setGlobal(
      'RN$LegacyInterop_UIManager_getConstantsForViewManager',
      getConstantsForViewManager,
    );
    jest.resetModules();
    jest.doMock('../../Utilities/Platform', () => ({
      OS: 'android',
      select: (spec: {[string]: unknown}) =>
        spec.android ?? spec.native ?? spec.default,
    }));
    const UIManager = require('../UIManager').default;

    expect(UIManager.getViewManagerConfig('RCTTestView')).toBe(
      viewManagerConfig,
    );
    expect(UIManager.getConstantsForViewManager?.('RCTTestView')).toBe(
      viewManagerConfig,
    );
    expect(getConstantsForViewManager).toHaveBeenCalledTimes(1);
  });
});
