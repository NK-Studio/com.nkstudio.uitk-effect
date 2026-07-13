# Changelog
All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-07-13

### Added

- Added `UITKEffectsMarginPatcher`, a runtime margin patcher that computes read/write margins for the Drop Shadow, Outer Glow, and Outline filters dynamically from their effect parameters (offset, blur radius, glow radius, outline width), clamped to the GPU's max texture size. Previously each filter used fixed static margins, so large offsets/radii/widths were clipped to the element's inflated rect.
- Added width-scaled sample density to the Outline shader's dilation/erosion loop so large outline widths no longer scallop into a blob-like silhouette.

### Fixed

- Fixed Drop Shadow and Inner Shadow shaders to clamp `blur-radius` to a minimum of 0, so negative values collapse to a crisp, undistorted hard-edged shadow instead of sampling a mirrored (and potentially distorted) disk.
- Fixed Outer Glow shader to skip rendering entirely when `radius` or `intensity` is zero or negative, instead of computing a zero-strength halo.
- Fixed Outline shader to skip rendering entirely when `width` is zero or negative, or when `mode` is outside the valid 0–2 (Outside/Center/Inside) range.

## [1.0.0] - 2026-07-12

### Added

- Initial release of UITK Effects.
- Added UI Toolkit filter assets for Drop Shadow, Inner Shadow, Outer Glow, and Outline effects.
- Added duplicate Drop Shadow and Inner Shadow filter definition assets for chaining the same effect type multiple times.
- Added UI Toolkit-compatible shaders and materials for shadow, glow, outline, and gradient rendering.
- Added a gradient material for `-unity-material` with start color, end color, angle, and step controls.
- Added a runtime assembly definition for package assets.
