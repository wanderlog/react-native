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

describe.each(['ios', 'android'])(
  'getNativeComponentAttributes in bridgeless mode on %s',
  platform => {
    const originalGlobals: {[string]: unknown} = {};

    beforeEach(() => {
      for (const name of GLOBAL_NAMES) {
        originalGlobals[name] = getGlobal(name);
      }
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
      jest.resetModules();
    });

    it('adds the default event types without calling getConstants()', () => {
      const getConstants = jest.fn();
      setGlobal('RN$Bridgeless', true);
      setGlobal('RN$LegacyInterop_UIManager_getConstants', getConstants);
      setGlobal(
        'RN$LegacyInterop_UIManager_getConstantsForViewManager',
        jest.fn(() => ({NativeProps: {}})),
      );
      setGlobal(
        'RN$LegacyInterop_UIManager_getDefaultEventTypes',
        jest.fn(() => ({
          directEventTypes: {topDefault: {registrationName: 'onDefault'}},
        })),
      );
      const getNativeComponentAttributes =
        require('../getNativeComponentAttributes').default;

      expect(
        getNativeComponentAttributes('RCTTestView').directEventTypes,
      ).toEqual({topDefault: {registrationName: 'onDefault'}});
      expect(getConstants).not.toHaveBeenCalled();
    });
  },
);
