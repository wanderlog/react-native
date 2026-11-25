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

// Maps each view manager's JS name (e.g. "RCTView") to its class. Cached so
// each getConstantsForViewManager call is a lookup instead of a scan of every
// module class. Modules register in +load, before JS runs, so the map can't
// go stale.
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

// Builds one view manager's config. directEvents and bubblingEvents are shared
// across calls to dedupe event entries and to report, in debug builds, an event
// registered as direct by one view manager and bubbling by another.
NSMutableDictionary<NSString *, id> *viewConfigForViewManagerClass(
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
        result[name] = viewConfigForViewManagerClass(moduleClass, name, directEvents, bubblingEvents);
      }];
  return TurboModuleConvertUtils::convertObjCObjectToJSIValue(runtime, result);
};

// One view manager's entry from getConstants(), or null if there's no view
// manager with that name. The fresh event dictionaries give the same config,
// but skip the cross-view-manager debug check; getConstants() still runs it.
jsi::Value getConstantsForViewManager(facebook::jsi::Runtime &runtime, const std::string &viewManagerName)
{
  NSString *name = [NSString stringWithUTF8String:viewManagerName.c_str()];
  Class moduleClass = getViewManagerClassesByName()[name];
  if (moduleClass == nil) {
    return jsi::Value::null();
  }
  return TurboModuleConvertUtils::convertObjCObjectToJSIValue(
      runtime, viewConfigForViewManagerClass(moduleClass, name, [NSMutableDictionary new], [NSMutableDictionary new]));
}

// Empty: unlike Android, iOS UIManager constants have no generic event types.
// Events every view supports, like touches, are in BaseViewConfig.ios.js.
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
