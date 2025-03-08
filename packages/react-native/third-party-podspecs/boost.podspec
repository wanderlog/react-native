# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

Pod::Spec.new do |spec|
  spec.name = 'boost'
  spec.version = '1.76.0'
  spec.license = { :type => 'Boost Software License', :file => "LICENSE_1_0.txt" }
  spec.homepage = 'http://www.boost.org'
  spec.summary = 'Boost provides free peer-reviewed portable C++ source libraries.'
  spec.authors = 'Rene Rivera'
  # Previous source no longer works, so we need to update to new source of the same version.
  # See GitHub thread discussing this issue: https://github.com/boostorg/boost/issues/843#issuecomment-2602280364
  spec.source = { :http => 'https://archives.boost.io/release/1.76.0/source/boost_1_76_0.tar.gz',
                  :sha256 => 'f0397ba6e982c4450f27bf32a2a83292aba035b827a5623a14636ea583318c41' }

  # Pinning to the same version as React.podspec.
  spec.platforms = { :ios => min_ios_version_supported }
  spec.requires_arc = false

  spec.module_name = 'boost'
  spec.header_dir = 'boost'
  spec.preserve_path = 'boost'
end
