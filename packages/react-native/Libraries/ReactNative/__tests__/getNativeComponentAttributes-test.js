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

// Fresh objects per call, since getNativeComponentAttributes() mutates the
// view config it gets
const createViewConfigs = (): {[string]: {[string]: unknown}} => ({
  RCTTestView: {
    baseModuleName: 'RCTView',
    NativeProps: {testProp: 'boolean'},
    bubblingEventTypes: {topOwnBubble: {phasedRegistrationNames: {}}},
    directEventTypes: {topOwnDirect: {registrationName: 'onOwnDirect'}},
  },
  RCTOtherTestView: {NativeProps: {}},
  RCTView: {
    NativeProps: {baseProp: 'boolean'},
    directEventTypes: {topBaseDirect: {registrationName: 'onBaseDirect'}},
  },
});

describe.each(['ios', 'android'])(
  'getNativeComponentAttributes in bridgeless mode on %s',
  platform => {
    const originalGlobals: {[string]: unknown} = {};
    let getConstantsForViewManager: JestMockFn<[string], unknown>;

    beforeEach(() => {
      for (const name of GLOBAL_NAMES) {
        originalGlobals[name] = getGlobal(name);
      }
      const viewConfigs = createViewConfigs();
      getConstantsForViewManager = jest.fn(
        (viewManagerName: string) => viewConfigs[viewManagerName] ?? null,
      );
      setGlobal('RN$Bridgeless', true);
      setGlobal(
        'RN$LegacyInterop_UIManager_getConstants',
        jest.fn(() => {
          throw new Error('getConstants() should not be called');
        }),
      );
      setGlobal(
        'RN$LegacyInterop_UIManager_getConstantsForViewManager',
        getConstantsForViewManager,
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
      jest.resetModules();
    });

    it('builds the attributes one view manager at a time, without getConstants()', () => {
      const getDefaultEventTypes = jest.fn(() => ({
        bubblingEventTypes: {topDefaultBubble: {phasedRegistrationNames: {}}},
        directEventTypes: {topDefaultDirect: {registrationName: 'onDefault'}},
      }));
      setGlobal(
        'RN$LegacyInterop_UIManager_getDefaultEventTypes',
        getDefaultEventTypes,
      );
      const getNativeComponentAttributes =
        require('../getNativeComponentAttributes').default;

      const attributes = getNativeComponentAttributes('RCTTestView');
      getNativeComponentAttributes('RCTOtherTestView');

      expect(attributes).toMatchObject({
        uiViewClassName: 'RCTTestView',
        validAttributes: {testProp: true, baseProp: true},
        bubblingEventTypes: {
          topDefaultBubble: {phasedRegistrationNames: {}},
          topOwnBubble: {phasedRegistrationNames: {}},
        },
        directEventTypes: {
          topBaseDirect: {registrationName: 'onBaseDirect'},
          topDefaultDirect: {registrationName: 'onDefault'},
          topOwnDirect: {registrationName: 'onOwnDirect'},
        },
      });
      expect(getConstantsForViewManager.mock.calls).toEqual([
        ['RCTTestView'],
        ['RCTView'],
        ['RCTOtherTestView'],
      ]);
      expect(getDefaultEventTypes).toHaveBeenCalledTimes(1);
    });

    it('handles empty default event types, as on iOS', () => {
      setGlobal(
        'RN$LegacyInterop_UIManager_getDefaultEventTypes',
        jest.fn(() => ({})),
      );
      const getNativeComponentAttributes =
        require('../getNativeComponentAttributes').default;

      expect(
        getNativeComponentAttributes('RCTTestView').directEventTypes,
      ).toEqual({
        topBaseDirect: {registrationName: 'onBaseDirect'},
        topOwnDirect: {registrationName: 'onOwnDirect'},
      });
    });

    it('returns null for an unknown view manager', () => {
      setGlobal(
        'RN$LegacyInterop_UIManager_getDefaultEventTypes',
        jest.fn(() => ({})),
      );
      const getNativeComponentAttributes =
        require('../getNativeComponentAttributes').default;

      expect(getNativeComponentAttributes('NotAViewManager')).toBeNull();
    });
  },
);
