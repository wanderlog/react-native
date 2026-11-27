/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <React/RCTLegacyViewManagerInteropComponentView.h>

@interface RCTLegacyViewManagerInteropDiffPropsTests : XCTestCase

@end

@implementation RCTLegacyViewManagerInteropDiffPropsTests

- (void)testSendsOnlyChangedProps
{
  folly::dynamic sentProps = folly::dynamic::object();
  folly::dynamic coordinates = folly::dynamic::array(folly::dynamic::object("latitude", 1)("longitude", 2));

  // First update: every prop is new, so we send all of them
  folly::dynamic firstProps = folly::dynamic::object("coordinates", coordinates)("strokeColor", "#00000000");
  XCTAssertEqual(RCTLegacyViewManagerInteropDiffProps(firstProps, sentProps, nil), firstProps);

  // An Animated frame that only changes strokeColor shouldn't resend coordinates
  folly::dynamic secondProps = folly::dynamic::object("coordinates", coordinates)("strokeColor", "#FF000080");
  XCTAssertEqual(
      RCTLegacyViewManagerInteropDiffProps(secondProps, sentProps, nil),
      folly::dynamic(folly::dynamic::object("strokeColor", "#FF000080")));
  XCTAssertEqual(sentProps, secondProps);
}

- (void)testSkipsPropsManagedByAnimated
{
  folly::dynamic sentProps = folly::dynamic::object("strokeColor", "#FF0000FF")("strokeWidth", 2);

  // A JS commit still carries strokeColor's start value. We keep the animated value and only send strokeWidth.
  folly::dynamic jsCommitProps = folly::dynamic::object("strokeColor", "#FF000000")("strokeWidth", 4);
  XCTAssertEqual(
      RCTLegacyViewManagerInteropDiffProps(jsCommitProps, sentProps, [NSSet setWithObject:@"strokeColor"]),
      folly::dynamic(folly::dynamic::object("strokeWidth", 4)));
  XCTAssertEqual(sentProps, folly::dynamic(folly::dynamic::object("strokeColor", "#FF0000FF")("strokeWidth", 4)));
}

@end
