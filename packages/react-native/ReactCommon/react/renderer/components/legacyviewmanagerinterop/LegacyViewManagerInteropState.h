/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#pragma once

#import <memory>

#include <react/renderer/core/ReactPrimitives.h>

namespace facebook::react {

/*
 * State for <LegacyViewManagerInterop> component.
 */
class LegacyViewManagerInteropState final {
 public:
  std::shared_ptr<void> coordinator;

  /*
   * The handle this component's descriptor is registered under. Each legacy
   * view manager gets its own handle (see the "Paper Interop" fallback in
   * RCTComponentViewFactory.mm), but they all share one view class, so the
   * view can't get the handle from its class the way other views do.
   */
  ComponentHandle componentHandle{};
};

} // namespace facebook::react
