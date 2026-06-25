# Changelog

## [1.2.1] — 2026-06-25

### Changed
- Updated to Godot 4.7 (godot-rust 0.5.3 → 0.5.4)
- Updated RaTeX dependency to 0.1.12

### Fixed
- Cleaned up unused local variable in `build.sh`

## [1.2.0] — 2026-06-05

### Added
- `render_png()`, `render_svg()`, and `render_pdf()` methods — replaces the old `render_latex()` with separate format-specific methods
- SVG output now includes background fill via `<rect>` and converts `rgba()` → hex for Godot's ThorVG compatibility
- `convert_rgba_to_hex()` utility to fix ThorVG colour parsing for embedded glyph paths
- Demo scene now has an **Image Source** dropdown for switching between PNG Buffer and SVG String
- First LaTeX preset is auto-selected on demo launch

## [1.1.1] — 2026-06-01

### Added
- iOS Simulator on Apple Silicon (`aarch64-apple-ios-sim`) build target
- Release zips now include `demo/`, `README.md`, `LICENSE`, and `.gdextension.uid`

### Fixed
- iOS SDK detection in CI — device target correctly uses `iphoneos`, sim targets use `iphonesimulator`

### Changed
- Compiled binaries are no longer tracked in git — they're build artifacts produced by `./build.sh` or CI
- Added `.gitignore` patterns for all GDExtension binary types (`*.so`, `*.dylib`, `*.dll`, `*.a`)
- Removed previously committed LFS pointer files for platform binaries
- Updated icon

## [1.1.0] — 2026-03-15

### Added
- Windows ARM64 support in CI and `.gdextension`
- Demo scene (`addons/godot_ratex/demo/`) with presets, LaTeX input field, and property controls
- LICENSE (MIT)
- Comprehensive README with API docs, usage examples, and supported platforms table

### Changed
- Renderer refactored to property-based API (`font_size`, `padding`, `background_color`, `font_color`)
- `render_latex()` now reads settings from properties instead of method arguments
- `.gitattributes` configured for Godot Asset Library convention (`export-ignore` rules)

## [1.0.0] — 2026-02-14

### Added
- Initial release — LaTeX rendering Godot 4.2+ GDExtension powered by [RaTeX](https://github.com/erweixin/RaTeX)
- Platform binaries: Linux (x86_64, arm64), Windows (x86_64), macOS (x86_64, arm64), Android (arm64, x86_64), iOS (arm64, x86_64 sim)
- CI pipeline building all platforms via GitHub Actions
- Automatic release packaging and artifact upload
- Static library support for iOS
- Simple `render_latex(latex_string)` GDScript API

[1.1.1]: https://github.com/mikhaelmartin/godot-ratex/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/mikhaelmartin/godot-ratex/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/mikhaelmartin/godot-ratex/releases/tag/v1.0.0
