/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include "RCTLegacyUIManagerConstantsProvider.h"

#import <React/RCTBridge+Private.h>
#import <React/RCTComponentData.h>
#import <React/RCTUIManager.h>
#import <React/RCTViewManager.h>
#import <ReactCommon/RCTTurboModule.h>
#import <react/runtime/nativeviewconfig/LegacyUIManagerConstantsProviderBinding.h>

namespace facebook::react {
namespace {

// Maps each view manager's JS name (e.g. "RCTView") to its class. Finding the
// names is cheap. Building each view config is the slow part.
NSDictionary<NSString *, Class> *getViewManagerClassesByName()
{
  static NSDictionary<NSString *, Class> *viewManagerClassesByName;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableDictionary<NSString *, Class> *classesByName = [NSMutableDictionary new];
    for (Class moduleClass in RCTGetModuleClasses()) {
      if ([moduleClass isSubclassOfClass:RCTViewManager.class]) {
        classesByName[RCTViewManagerModuleNameForClass(moduleClass)] = moduleClass;
      }
    }
    viewManagerClassesByName = classesByName;
  });
  return viewManagerClassesByName;
}

NSMutableDictionary<NSString *, id> *getModuleConstants(
    Class moduleClass,
    NSString *name,
    NSMutableDictionary<NSString *, NSDictionary *> *directEvents,
    NSMutableDictionary<NSString *, NSDictionary *> *bubblingEvents)
{
  auto viewConfig = [RCTComponentData viewConfigForViewMangerClass:moduleClass];
  return RCTModuleConstantsForDestructuredComponent(directEvents, bubblingEvents, moduleClass, name, viewConfig);
}

jsi::Value getConstants(facebook::jsi::Runtime &runtime)
{
  NSMutableDictionary<NSString *, NSObject *> *result = [NSMutableDictionary new];
  auto directEvents = [NSMutableDictionary new];
  auto bubblingEvents = [NSMutableDictionary new];
  [getViewManagerClassesByName()
      enumerateKeysAndObjectsUsingBlock:^(NSString *name, Class moduleClass, __unused BOOL *stop) {
        result[name] = getModuleConstants(moduleClass, name, directEvents, bubblingEvents);
      }];
  return TurboModuleConvertUtils::convertObjCObjectToJSIValue(runtime, result);
};

// One view manager's entry from getConstants(), or null if there's no view
// manager with that name
jsi::Value getConstantsForViewManager(facebook::jsi::Runtime &runtime, const std::string &viewManagerName)
{
  NSString *name = [NSString stringWithUTF8String:viewManagerName.c_str()];
  Class moduleClass = getViewManagerClassesByName()[name];
  if (moduleClass == nil) {
    return jsi::Value::null();
  }
  return TurboModuleConvertUtils::convertObjCObjectToJSIValue(
      runtime, getModuleConstants(moduleClass, name, [NSMutableDictionary new], [NSMutableDictionary new]));
}

// iOS has no generic event types, so this is empty. Unlike Android
// (https://github.com/facebook/react-native/blob/v0.86.3/packages/react-native/ReactAndroid/src/main/java/com/facebook/react/uimanager/UIManagerModuleConstantsHelper.kt#L128-L129),
// iOS's UIManager constants only have one entry per view manager
// (https://github.com/facebook/react-native/blob/v0.86.3/packages/react-native/React/Modules/RCTUIManager.mm#L1508-L1523).
// Events that every view supports, like touches, are in JS instead
// (https://github.com/facebook/react-native/blob/v0.86.3/packages/react-native/Libraries/NativeComponent/BaseViewConfig.ios.js#L24).
jsi::Value getDefaultEventTypes(facebook::jsi::Runtime &runtime)
{
  return jsi::Object(runtime);
}

} // namespace

void installLegacyUIManagerConstantsProviderBinding(jsi::Runtime &runtime)
{
  LegacyUIManagerConstantsProviderBinding::install(runtime, "getConstants", getConstants);
  LegacyUIManagerConstantsProviderBinding::install(runtime, "getConstantsForViewManager", getConstantsForViewManager);
  LegacyUIManagerConstantsProviderBinding::install(runtime, "getDefaultEventTypes", getDefaultEventTypes);
}
} // namespace facebook::react
