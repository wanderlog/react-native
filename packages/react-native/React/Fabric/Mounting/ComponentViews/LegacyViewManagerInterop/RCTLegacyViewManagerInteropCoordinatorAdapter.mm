/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTLegacyViewManagerInteropCoordinatorAdapter.h"
#import <React/RCTConversions.h>
#import <React/UIView+React.h>
#import <react/utils/FollyConvert.h>

@implementation RCTLegacyViewManagerInteropCoordinatorAdapter {
  RCTLegacyViewManagerInteropCoordinator *_coordinator;
  NSInteger _tag;
  /**
   * The props we last sent to the paper view. We diff against these so a frame of a native-driver animation only
   * converts and sends the keys it changed, not every prop (e.g. a polyline's whole coordinates array).
   */
  folly::dynamic _sentProps;
}

- (instancetype)initWithCoordinator:(RCTLegacyViewManagerInteropCoordinator *)coordinator reactTag:(NSInteger)tag
{
  if (self = [super init]) {
    _coordinator = coordinator;
    _tag = tag;
    _sentProps = folly::dynamic::object();
  }
  return self;
}

- (void)dealloc
{
  [_paperView removeFromSuperview];
  [_coordinator removeObserveForTag:_tag];
}

- (UIView *)paperView
{
  if (!_paperView) {
    _paperView = [_coordinator createPaperViewWithTag:_tag];
    __weak __typeof(self) weakSelf = self;
    [_coordinator addObserveForTag:_tag
                        usingBlock:^(std::string eventName, folly::dynamic &&event) {
                          if (weakSelf.eventInterceptor) {
                            weakSelf.eventInterceptor(eventName, std::move(event));
                          }
                        }];
  }
  return _paperView;
}

- (void)setProps:(const folly::dynamic &)props propKeysToSkip:(nullable NSSet<NSString *> *)propKeysToSkip
{
  if (!props.isObject()) {
    return;
  }
  folly::dynamic changedProps = RCTLegacyViewManagerInteropDiffProps(props, _sentProps, propKeysToSkip);
  if (changedProps.empty()) {
    return;
  }
  [_coordinator setProps:facebook::react::convertFollyDynamicToId(changedProps) forView:self.paperView];
}

- (void)handleCommand:(NSString *)commandName args:(NSArray *)args
{
  [_coordinator handleCommand:commandName args:args reactTag:_tag paperView:self.paperView];
}

@end

folly::dynamic RCTLegacyViewManagerInteropDiffProps(
    const folly::dynamic &props,
    folly::dynamic &sentProps,
    NSSet<NSString *> *_Nullable propKeysToSkip)
{
  folly::dynamic changedProps = folly::dynamic::object();
  for (const auto &[key, value] : props.items()) {
    if (propKeysToSkip != nil && [propKeysToSkip containsObject:RCTNSStringFromString(key.asString())]) {
      continue;
    }
    auto sentProp = sentProps.find(key);
    if (sentProp != sentProps.items().end() && sentProp->second == value) {
      continue;
    }
    changedProps[key] = value;
    sentProps[key] = value;
  }
  return changedProps;
}
