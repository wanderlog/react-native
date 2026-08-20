/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <React/RCTMaintainVisibleContentPositionUtils.h>
#import <React/RCTScrollViewComponentView.h>
#import <XCTest/XCTest.h>
#import <react/renderer/components/scrollview/ScrollViewProps.h>
#import <react/renderer/components/scrollview/ScrollViewShadowNode.h>

using facebook::react::Props;
using facebook::react::ScrollViewProps;
using facebook::react::ScrollViewShadowNode;

#if TARGET_OS_IOS

static Props::Shared makeScrollViewProps(bool automaticallyAdjustKeyboardInsets)
{
  auto props = std::make_shared<ScrollViewProps>();
  props->automaticallyAdjustKeyboardInsets = automaticallyAdjustKeyboardInsets;
  return props;
}

@interface RCTScrollViewComponentView (Tests)
- (void)_keyboardWillChangeFrame:(NSNotification *)notification;
@end

@interface RCTScrollViewComponentViewTests : XCTestCase
@end

@implementation RCTScrollViewComponentViewTests

- (void)testAutomaticallyAdjustKeyboardInsetsAcrossRecycling
{
  RCTScrollViewComponentView *view = [[RCTScrollViewComponentView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
  auto props = makeScrollViewProps(true);
  [view updateProps:props oldProps:ScrollViewShadowNode::defaultSharedProps()];

  NSNotification *notification = [NSNotification
      notificationWithName:UIKeyboardWillChangeFrameNotification
                    object:nil
                  userInfo:@{
                    UIKeyboardAnimationDurationUserInfoKey : @0,
                    UIKeyboardAnimationCurveUserInfoKey : @(UIViewAnimationCurveLinear),
                    UIKeyboardFrameBeginUserInfoKey : [NSValue valueWithCGRect:CGRectMake(0, 100, 100, 50)],
                    UIKeyboardFrameEndUserInfoKey : [NSValue valueWithCGRect:CGRectMake(0, 50, 100, 50)],
                  }];

  [view _keyboardWillChangeFrame:notification];
  XCTAssertEqual(view.scrollView.contentInset.bottom, 50);

  [view prepareForRecycle];
  UIEdgeInsets insetsAfterRecycle = view.scrollView.contentInset;
  [view _keyboardWillChangeFrame:notification];
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(view.scrollView.contentInset, insetsAfterRecycle));

  [view updateProps:props oldProps:nullptr];
  [view _keyboardWillChangeFrame:notification];
  XCTAssertEqual(view.scrollView.contentInset.bottom, 50);
}

- (NSDictionary *)metricWithStart:(CGFloat)start end:(CGFloat)end
{
  return @{@"start" : @(start), @"end" : @(end)};
}

- (void)testMaintainVisibleContentPositionFindAnchorIndexWithMinIndexZero
{
  NSArray<NSDictionary *> *metrics = @[
    [self metricWithStart:100 end:140],
    [self metricWithStart:0 end:40],
    [self metricWithStart:40 end:80],
  ];

  NSInteger anchorIndex = RCTMVCPTestFindAnchorIndexWithMetrics(metrics, 0, 50);
  XCTAssertEqual(anchorIndex, 2);
}

- (void)testMaintainVisibleContentPositionFindAnchorIndexWithMinIndexGreaterThanZero
{
  NSArray<NSDictionary *> *metrics = @[
    [self metricWithStart:100 end:140],
    [self metricWithStart:0 end:40],
    [self metricWithStart:40 end:80],
    [self metricWithStart:80 end:120],
  ];

  NSInteger anchorIndex = RCTMVCPTestFindAnchorIndexWithMetrics(metrics, 2, 50);
  XCTAssertEqual(anchorIndex, 3);
}

- (void)testMaintainVisibleContentPositionLayoutOrderCacheReusesSnapshot
{
  RCTMVCPTestInvalidateLayoutOrderCache();

  NSArray<NSDictionary *> *metrics = @[
    [self metricWithStart:100 end:140],
    [self metricWithStart:0 end:40],
    [self metricWithStart:40 end:80],
  ];

  NSArray<NSNumber *> *first = RCTMVCPTestSortedIndicesForMetrics(metrics, YES);
  NSArray<NSNumber *> *second = RCTMVCPTestSortedIndicesForMetrics(metrics, YES);

  XCTAssertEqualObjects(first, (@[ @1, @2, @0 ]));
  XCTAssertEqualObjects(second, first);
}

- (void)testMaintainVisibleContentPositionLayoutOrderCacheRecomputesAfterLayoutChange
{
  RCTMVCPTestInvalidateLayoutOrderCache();

  NSArray<NSDictionary *> *initialMetrics = @[
    [self metricWithStart:100 end:140],
    [self metricWithStart:0 end:40],
  ];
  NSArray<NSDictionary *> *updatedMetrics = @[
    [self metricWithStart:0 end:40],
    [self metricWithStart:100 end:140],
  ];

  NSArray<NSNumber *> *initialSorted = RCTMVCPTestSortedIndicesForMetrics(initialMetrics, YES);
  NSArray<NSNumber *> *updatedSorted = RCTMVCPTestSortedIndicesForMetrics(updatedMetrics, YES);

  XCTAssertEqualObjects(initialSorted, (@[ @1, @0 ]));
  XCTAssertEqualObjects(updatedSorted, (@[ @0, @1 ]));
}

@end

#endif
