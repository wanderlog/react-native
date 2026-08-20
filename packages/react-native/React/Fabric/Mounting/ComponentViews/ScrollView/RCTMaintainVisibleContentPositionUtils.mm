/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTMaintainVisibleContentPositionUtils.h"

#include <algorithm>

const std::vector<size_t> &RCTMVCPLayoutOrderCache::sortedIndicesFor(
    const std::vector<RCTMVCPChildLayoutMetrics> &children)
{
  std::vector<std::pair<CGFloat, CGFloat>> snapshot;
  snapshot.reserve(children.size());
  for (const auto &child : children) {
    snapshot.emplace_back(child.start, child.end);
  }

  if (snapshot == lastSnapshot && !sortedIndices.empty()) {
    return sortedIndices;
  }

  sortedIndices.resize(children.size());
  for (size_t i = 0; i < children.size(); ++i) {
    sortedIndices[i] = i;
  }
  std::sort(sortedIndices.begin(), sortedIndices.end(), [&children](size_t a, size_t b) {
    return children[a].start < children[b].start;
  });

  lastSnapshot = std::move(snapshot);
  return sortedIndices;
}

void RCTMVCPLayoutOrderCache::invalidate()
{
  lastSnapshot.clear();
  sortedIndices.clear();
}

static RCTMVCPLayoutOrderCache gTestLayoutOrderCache;

RCTMVCPLayoutOrderCache *RCTMVCPCreateLayoutOrderCache()
{
  return new RCTMVCPLayoutOrderCache();
}

void RCTMVCPLayoutOrderCacheRelease(RCTMVCPLayoutOrderCache *cache)
{
  delete cache;
}

std::optional<size_t> RCTMVCPFindFirstVisibleAnchorIndex(
    const std::vector<RCTMVCPChildLayoutMetrics> &children,
    int minIndexForVisible,
    CGFloat currentScroll,
    RCTMVCPLayoutOrderCache *cache)
{
  if (children.empty() || minIndexForVisible >= static_cast<int>(children.size())) {
    return std::nullopt;
  }

  if (minIndexForVisible == 0) {
    // z-index can reorder subviews. Scan all children and pick the topmost visible anchor by layout position.
    std::optional<size_t> anchorIndex;
    CGFloat firstVisibleEnd = CGFLOAT_MAX;
    for (size_t i = 0; i < children.size(); ++i) {
      const auto &child = children[i];
      if ((child.end > currentScroll && child.end < firstVisibleEnd) ||
          (!anchorIndex.has_value() && i == children.size() - 1)) {
        anchorIndex = child.index;
        firstVisibleEnd = child.end;
      }
    }
    return anchorIndex;
  }

  if (!cache) {
    return std::nullopt;
  }

  const auto &sortedIndices = cache->sortedIndicesFor(children);
  for (size_t i = minIndexForVisible; i < sortedIndices.size(); ++i) {
    const auto &child = children[sortedIndices[i]];
    if (child.end > currentScroll || i == sortedIndices.size() - 1) {
      return child.index;
    }
  }

  return std::nullopt;
}

static std::vector<RCTMVCPChildLayoutMetrics> RCTMVCPChildLayoutMetricsFromNSArray(NSArray<NSDictionary *> *metrics)
{
  std::vector<RCTMVCPChildLayoutMetrics> children;
  children.reserve(metrics.count);
  for (NSUInteger i = 0; i < metrics.count; ++i) {
    NSDictionary *metric = metrics[i];
    children.push_back(
        {i,
         [metric[@"start"] doubleValue],
         [metric[@"end"] doubleValue]});
  }
  return children;
}

NSInteger RCTMVCPTestFindAnchorIndexWithMetrics(
    NSArray<NSDictionary *> *metrics,
    NSInteger minIndexForVisible,
    CGFloat currentScroll)
{
  auto children = RCTMVCPChildLayoutMetricsFromNSArray(metrics);
  RCTMVCPLayoutOrderCache localCache;
  RCTMVCPLayoutOrderCache *cache = minIndexForVisible > 0 ? &localCache : nullptr;
  auto anchorIndex =
      RCTMVCPFindFirstVisibleAnchorIndex(children, static_cast<int>(minIndexForVisible), currentScroll, cache);
  return anchorIndex.has_value() ? static_cast<NSInteger>(anchorIndex.value()) : NSNotFound;
}

NSArray<NSNumber *> *RCTMVCPTestSortedIndicesForMetrics(
    NSArray<NSDictionary *> *metrics,
    BOOL usePersistentCache)
{
  auto children = RCTMVCPChildLayoutMetricsFromNSArray(metrics);
  RCTMVCPLayoutOrderCache localCache;
  RCTMVCPLayoutOrderCache *cache = usePersistentCache ? &gTestLayoutOrderCache : &localCache;
  const auto &sortedIndices = cache->sortedIndicesFor(children);
  NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:sortedIndices.size()];
  for (size_t index : sortedIndices) {
    [result addObject:@(index)];
  }
  return result;
}

void RCTMVCPTestInvalidateLayoutOrderCache()
{
  gTestLayoutOrderCache.invalidate();
}
