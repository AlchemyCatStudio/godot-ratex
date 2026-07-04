# Changelog

## [1.2.2] — 2026-07-04

### Added
- **BBCode table support** (`[table=N][cell]...[/cell]...[/table]`) using `GridContainer` with `PanelContainer` cell wrappers and `StyleBoxFlat` borders. Empty trailing cells auto-padded. Border color configurable via `table_border_color` export.
- **BBCode ordered/unordered lists** (`[ul bullet=X]...[/ul]`, `[ol type=1|a|A|i|I]...[/ol]`). Compound numbering for nested ordered lists (e.g., `2.1.`). Sublists merge into parent item instead of creating empty items.
- **BBCode indent blocks** (`[indent]...[/indent]`) with recursive block parsing via `MarginContainer`.
- **Inline image support** (`[img=WxH]path[/img]`) with scaling in px, %, and em units.
- **Line break support** (`[br]`).
- **Paragraph alignment** (`[left]`, `[center]`, `[right]`, `[fill]`) via `HFlowContainer.alignment` using lazy line creation and an alignment stack.

### Changed
- **Rewrote `godot_ratex_label.gd`** with a two-phase parsing architecture: block-level structural parser (`_parse_block_structure`) separates tables, lists, and indents from inline content, then inline tokenizer builds `HFlowContainer` paragraphs. LaTeX math rendering works inside all block types.
- Cell borders use `PanelContainer` + `StyleBoxFlat` padding instead of `GridContainer` `h_separation`/`v_separation` overrides.
- `generate()` now delegates to block builders instead of directly building UI from a flat token array.

### Fixed
- Nested list items no longer split into separate top-level items.
- Ordered lists produce correct compound numbering (`1.1.`, `1.a.` etc.) via prefix threading through `_build_block`.
- Empty table cells no longer break `GridContainer` row alignment.

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
[1.2.2]: https://github.com/mikhaelmartin/godot-ratex/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/mikhaelmartin/godot-ratex/compare/v1.1.1...v1.2.1
[1.1.1]: https://github.com/mikhaelmartin/godot-ratex/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/mikhaelmartin/godot-ratex/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/mikhaelmartin/godot-ratex/releases/tag/v1.0.0
