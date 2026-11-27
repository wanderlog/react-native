/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <react/renderer/components/legacyviewmanagerinterop/RCTLegacyViewManagerInteropCoordinator.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTLegacyViewManagerInteropCoordinatorAdapter : NSObject

- (instancetype)initWithCoordinator:(RCTLegacyViewManagerInteropCoordinator *)coordinator reactTag:(NSInteger)tag;

@property (strong, nonatomic) UIView *paperView;

@property (nonatomic, copy, nullable) void (^eventInterceptor)(std::string eventName, folly::dynamic &&event);

/**
 * Sends the paper view only the props that changed since the last call, leaving out `propKeysToSkip`, which
 * native-driver Animated owns.
 */
- (void)setProps:(const folly::dynamic &)props propKeysToSkip:(nullable NSSet<NSString *> *)propKeysToSkip;

- (void)handleCommand:(NSString *)commandName args:(NSArray *)args;

@end

/**
 * Returns the props that differ from `sentProps`, and records them in `sentProps`. Leaves out `propKeysToSkip`, which
 * native-driver Animated owns.
 */
folly::dynamic RCTLegacyViewManagerInteropDiffProps(
    const folly::dynamic &props,
    folly::dynamic &sentProps,
    NSSet<NSString *> *_Nullable propKeysToSkip);

NS_ASSUME_NONNULL_END
