/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.facebook.react.views.scroll

import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UIManager
import com.facebook.react.bridge.UIManagerListener
import com.facebook.react.bridge.UiThreadUtil.runOnUiThread
import com.facebook.react.common.annotations.UnstableReactNativeAPI
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.common.UIManagerType
import com.facebook.react.views.scroll.ReactScrollViewHelper.HasScrollEventThrottle
import com.facebook.react.views.scroll.ReactScrollViewHelper.HasSmoothScroll
import com.facebook.react.views.view.ReactViewGroup
import java.lang.ref.WeakReference

/**
 * Manage state for the maintainVisibleContentPosition prop.
 *
 * This uses UIManager to listen to updates and capture position of items before and after layout.
 */
@OptIn(UnstableReactNativeAPI::class)
internal class MaintainVisibleScrollPositionHelper<ScrollViewT>(
    private val scrollView: ScrollViewT,
    private val horizontal: Boolean,
) : UIManagerListener
    where
        ScrollViewT : HasScrollEventThrottle?,
        ScrollViewT : HasSmoothScroll?,
        ScrollViewT : ViewGroup? {

  var config: Config? = null
  private var firstVisibleViewRef: WeakReference<View>? = null
  private var prevFirstVisibleFrame: Rect? = null
  private var isListening = false
  private val layoutOrderCache = LayoutOrderCache()

  private val contentView: ReactViewGroup?
    get() = scrollView?.getChildAt(0) as ReactViewGroup?

  private val uIManager: UIManager
    get() = checkNotNull(
        UIManagerHelper.getUIManager(
            checkNotNull(scrollView?.context as ReactContext?),
            UIManagerType.FABRIC,
        ),
    )

  class Config
  internal constructor(val minIndexForVisible: Int, val autoScrollToTopThreshold: Int?) {
    companion object {
      @JvmStatic
      fun fromReadableMap(value: ReadableMap): Config {
        val minIndexForVisible = value.getInt("minIndexForVisible")
        val autoScrollToTopThreshold =
            if (value.hasKey("autoscrollToTopThreshold")) value.getInt("autoscrollToTopThreshold")
            else null
        return Config(minIndexForVisible, autoScrollToTopThreshold)
      }
    }
  }

  /** Start listening to view hierarchy updates. Should be called when this is created. */
  fun start() {
    if (isListening) {
      return
    }
    isListening = true
    uIManager.addUIManagerEventListener(this)
  }

  /** Stop listening to view hierarchy updates. Should be called before this is destroyed. */
  fun stop() {
    if (!isListening) {
      return
    }
    isListening = false
    firstVisibleViewRef = null
    layoutOrderCache.invalidate()
    uIManager.removeUIManagerEventListener(this)
  }

  private fun updateScrollPositionInternal() {
    val config = config ?: return
    val firstVisibleViewRef = firstVisibleViewRef ?: return
    val prevFirstVisibleFrame = prevFirstVisibleFrame ?: return
    val firstVisibleView = firstVisibleViewRef.get() ?: return
    val scrollView = scrollView ?: return

    val newFrame = Rect()
    firstVisibleView.getHitRect(newFrame)

    if (horizontal) {
      val deltaX = newFrame.left - prevFirstVisibleFrame.left
      if (deltaX != 0) {
        val scrollX = scrollView.scrollX
        scrollView.scrollToPreservingMomentum(scrollX + deltaX, scrollView.scrollY)
        this.prevFirstVisibleFrame = newFrame
        if (config.autoScrollToTopThreshold != null && scrollX <= config.autoScrollToTopThreshold) {
          scrollView.reactSmoothScrollTo(0, scrollView.scrollY)
        }
      }
    } else {
      val deltaY = newFrame.top - prevFirstVisibleFrame.top
      if (deltaY != 0) {
        val scrollY = scrollView.scrollY
        scrollView.scrollToPreservingMomentum(scrollView.scrollX, scrollY + deltaY)
        this.prevFirstVisibleFrame = newFrame
        if (config.autoScrollToTopThreshold != null && scrollY <= config.autoScrollToTopThreshold) {
          scrollView.reactSmoothScrollTo(scrollView.scrollX, 0)
        }
      }
    }
  }

  private fun computeTargetView() {
    val config = config ?: return
    val scrollView = scrollView ?: return
    val contentView = contentView ?: return

    val currentScroll = if (horizontal) scrollView.scrollX else scrollView.scrollY
    val childCount = contentView.childCount
    if (childCount == 0) {
      return
    }

    val children =
        (0 until childCount).map { i ->
          val child = contentView.getChildAt(i)
          ChildLayoutMetrics(
              index = i,
              start = if (horizontal) child.x else child.y,
              end =
                  if (horizontal) child.x + child.width else child.y + child.height,
          )
        }

    val cache = if (config.minIndexForVisible > 0) layoutOrderCache else null
    val anchorIndex =
        findAnchorIndex(
            children,
            config.minIndexForVisible,
            currentScroll.toFloat(),
            cache,
        ) ?: return

    val firstVisibleView = contentView.getChildAt(anchorIndex)
    firstVisibleViewRef = WeakReference(firstVisibleView)
    val frame = Rect()
    firstVisibleView.getHitRect(frame)
    prevFirstVisibleFrame = frame
  }

  // UIManagerListener
  override fun willDispatchViewUpdates(uiManager: UIManager) {
    runOnUiThread { computeTargetView() }
  }

  override fun willMountItems(uiManager: UIManager) {
    computeTargetView()
  }

  override fun didMountItems(uiManager: UIManager) {
    updateScrollPositionInternal()
  }

  override fun didDispatchMountItems(uiManager: UIManager) {
    // noop
  }

  override fun didScheduleMountItems(uiManager: UIManager) {
    // noop
  }
}

internal data class ChildLayoutMetrics(val index: Int, val start: Float, val end: Float)

internal fun findAnchorIndex(
    children: List<ChildLayoutMetrics>,
    minIndexForVisible: Int,
    currentScroll: Float,
    layoutOrderCache: LayoutOrderCache?,
): Int? {
  if (children.isEmpty() || minIndexForVisible >= children.size) {
    return null
  }

  if (minIndexForVisible == 0) {
    // z-index can reorder children in the ViewGroup. Scan all children and pick the
    // topmost visible anchor by layout position.
    var anchorIndex: Int? = null
    var firstVisibleEnd = Float.MAX_VALUE
    for (i in children.indices) {
      val child = children[i]
      if ((child.end > currentScroll && child.end < firstVisibleEnd) ||
          (anchorIndex == null && i == children.lastIndex)) {
        anchorIndex = child.index
        firstVisibleEnd = child.end
      }
    }
    return anchorIndex
  }

  val sortedIndices = layoutOrderCache?.sortedIndices(children) ?: return null

  // minIndexForVisible applies in layout order rather than hierarchy order.
  for (i in minIndexForVisible until sortedIndices.size) {
    val child = children[sortedIndices[i]]
    if (child.end > currentScroll || i == sortedIndices.lastIndex) {
      return child.index
    }
  }
  return null
}

internal class LayoutOrderCache {
  private var lastSnapshot: List<Pair<Float, Float>>? = null
  private var sortedIndices: IntArray? = null

  fun sortedIndices(children: List<ChildLayoutMetrics>): IntArray {
    val snapshot = children.map { it.start to it.end }
    val cachedIndices = sortedIndices
    if (snapshot == lastSnapshot && cachedIndices != null) {
      return cachedIndices
    }

    val indices = children.indices.sortedBy { children[it].start }.toIntArray()
    lastSnapshot = snapshot
    sortedIndices = indices
    return indices
  }

  fun invalidate() {
    lastSnapshot = null
    sortedIndices = null
  }
}
