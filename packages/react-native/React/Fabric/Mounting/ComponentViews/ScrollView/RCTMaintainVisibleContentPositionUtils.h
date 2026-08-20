/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

#include <cstddef>
#include <optional>
#include <utility>
#include <vector>

struct RCTMVCPChildLayoutMetrics {
  size_t index;
  CGFloat start;
  CGFloat end;
};

struct RCTMVCPLayoutOrderCache {
  std::vector<std::pair<CGFloat, CGFloat>> lastSnapshot;
  std::vector<size_t> sortedIndices;

  const std::vector<size_t> &sortedIndicesFor(const std::vector<RCTMVCPChildLayoutMetrics> &children);
  void invalidate();
};

RCTMVCPLayoutOrderCache *RCTMVCPCreateLayoutOrderCache(void);
void RCTMVCPLayoutOrderCacheRelease(RCTMVCPLayoutOrderCache *cache);

std::optional<size_t> RCTMVCPFindFirstVisibleAnchorIndex(
    const std::vector<RCTMVCPChildLayoutMetrics> &children,
    int minIndexForVisible,
    CGFloat currentScroll,
    RCTMVCPLayoutOrderCache *cache);

NS_ASSUME_NONNULL_BEGIN

NSInteger RCTMVCPTestFindAnchorIndexWithMetrics(
    NSArray<NSDictionary *> *metrics,
    NSInteger minIndexForVisible,
    CGFloat currentScroll);
NSArray<NSNumber *> *RCTMVCPTestSortedIndicesForMetrics(
    NSArray<NSDictionary *> *metrics,
    BOOL usePersistentCache);
void RCTMVCPTestInvalidateLayoutOrderCache(void);

NS_ASSUME_NONNULL_END
