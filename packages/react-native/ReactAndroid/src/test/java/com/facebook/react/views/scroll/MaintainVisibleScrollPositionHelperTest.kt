/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.facebook.react.views.scroll

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class MaintainVisibleScrollPositionHelperTest {

  @Test
  fun `findAnchorIndex with minIndex 0 picks topmost visible child by layout order`() {
    // Hierarchy index 0 is visually below index 1 due to z-index reordering.
    val children =
        listOf(
            ChildLayoutMetrics(index = 0, start = 100f, end = 140f),
            ChildLayoutMetrics(index = 1, start = 0f, end = 40f),
            ChildLayoutMetrics(index = 2, start = 40f, end = 80f),
        )

    val anchorIndex = findAnchorIndex(children, minIndexForVisible = 0, currentScroll = 50f, null)

    assertThat(anchorIndex).isEqualTo(2)
  }

  @Test
  fun `findAnchorIndex with minIndex 0 falls back to last child when none visible`() {
    val children =
        listOf(
            ChildLayoutMetrics(index = 0, start = 0f, end = 40f),
            ChildLayoutMetrics(index = 1, start = 40f, end = 80f),
        )

    val anchorIndex = findAnchorIndex(children, minIndexForVisible = 0, currentScroll = 200f, null)

    assertThat(anchorIndex).isEqualTo(1)
  }

  @Test
  fun `findAnchorIndex with minIndex greater than 0 skips early layout-order children`() {
    val children =
        listOf(
            ChildLayoutMetrics(index = 0, start = 100f, end = 140f),
            ChildLayoutMetrics(index = 1, start = 0f, end = 40f),
            ChildLayoutMetrics(index = 2, start = 40f, end = 80f),
            ChildLayoutMetrics(index = 3, start = 80f, end = 120f),
        )
    val cache = LayoutOrderCache()

    val anchorIndex = findAnchorIndex(children, minIndexForVisible = 2, currentScroll = 50f, cache)

    assertThat(anchorIndex).isEqualTo(3)
  }

  @Test
  fun `findAnchorIndex returns null for empty children`() {
    assertThat(findAnchorIndex(emptyList(), minIndexForVisible = 0, currentScroll = 0f, null))
        .isNull()
  }

  @Test
  fun `findAnchorIndex returns null when minIndex is out of range`() {
    val children = listOf(ChildLayoutMetrics(index = 0, start = 0f, end = 40f))

    assertThat(findAnchorIndex(children, minIndexForVisible = 1, currentScroll = 0f, LayoutOrderCache()))
        .isNull()
  }

  @Test
  fun `LayoutOrderCache reuses sorted indices when layout snapshot is unchanged`() {
    val children =
        listOf(
            ChildLayoutMetrics(index = 0, start = 100f, end = 140f),
            ChildLayoutMetrics(index = 1, start = 0f, end = 40f),
            ChildLayoutMetrics(index = 2, start = 40f, end = 80f),
        )
    val cache = LayoutOrderCache()

    val first = cache.sortedIndices(children)
    val second = cache.sortedIndices(children)

    assertThat(first).containsExactly(1, 2, 0)
    assertThat(second).isSameAs(first)
  }

  @Test
  fun `LayoutOrderCache recomputes when child layout changes`() {
    val cache = LayoutOrderCache()
    val initialChildren =
        listOf(
            ChildLayoutMetrics(index = 0, start = 100f, end = 140f),
            ChildLayoutMetrics(index = 1, start = 0f, end = 40f),
        )
    val updatedChildren =
        listOf(
            ChildLayoutMetrics(index = 0, start = 0f, end = 40f),
            ChildLayoutMetrics(index = 1, start = 100f, end = 140f),
        )

    val initialSorted = cache.sortedIndices(initialChildren)
    val updatedSorted = cache.sortedIndices(updatedChildren)

    assertThat(initialSorted).containsExactly(1, 0)
    assertThat(updatedSorted).containsExactly(0, 1)
    assertThat(updatedSorted).isNotSameAs(initialSorted)
  }

  @Test
  fun `LayoutOrderCache invalidate clears cached snapshot`() {
    val cache = LayoutOrderCache()
    val children =
        listOf(
            ChildLayoutMetrics(index = 0, start = 100f, end = 140f),
            ChildLayoutMetrics(index = 1, start = 0f, end = 40f),
        )

    val first = cache.sortedIndices(children)
    cache.invalidate()
    val second = cache.sortedIndices(children)

    assertThat(first).containsExactly(1, 0)
    assertThat(second).containsExactly(1, 0)
    assertThat(second).isNotSameAs(first)
  }
}
