#!/bin/bash
set -euo pipefail

# build.sh — Build godot_ratex GDExtension for all supported platforms
#
# Usage:
#   ./build.sh                          Build for current host only (debug)
#   ./build.sh --release                Build for current host only (release)
#   ./build.sh --all                    Build all supported targets (release)
#   ./build.sh --target linux|x86_64|arm64  Build specific platform+arch
#   ./build.sh --platform linux,windows  Build specific platforms only
#   ./build.sh --clean                  Clean build artifacts after build
#   ./build.sh --verbose                Verbose cargo output
#   ./build.sh -h|--help                Show this help

usage() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# //'
    exit 0
}

PACKAGE_NAME="godot_ratex"
ADDON_DIR="addons/godot_ratex"
BUILD_PROFILE="debug"
CLEAN_AFTER=false
SELECTED_PLATFORM=""
SELECTED_ARCH=""
BUILD_ALL=false
VERBOSE=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --release)    BUILD_PROFILE="release" ;;
        --debug)      BUILD_PROFILE="debug" ;;
        --platform)   SELECTED_PLATFORM="$2"; shift ;;
        --target)     SELECTED_ARCH="$2"; shift ;;
        --all)        BUILD_ALL=true; BUILD_PROFILE="release" ;;
        --clean)      CLEAN_AFTER=true ;;
        --verbose)    VERBOSE=true ;;
        -h|--help)    usage ;;
        *) echo "Error: Unknown parameter '$1'"; usage ;;
    esac
    shift
done

# Platform definitions:
#   key -> "rust_target|lib_prefix|lib_ext|addon_subdir|output_filename"
#
# output_filename is the file placed in addons/godot_ratex/<subdir>/ and
# referenced by the .gdextension file. Each architecture gets its own name
# so they don't overwrite each other in shared platform directories.

declare -A TARGET_DATA=(
    ["linux_x86_64"]="x86_64-unknown-linux-gnu|lib|.so|linux|libgodot_ratex.x86_64.so"
    ["linux_arm64"]="aarch64-unknown-linux-gnu|lib|.so|linux|libgodot_ratex.arm64.so"
    ["windows_x86_64"]="x86_64-pc-windows-msvc||.dll|windows|godot_ratex.x86_64.dll"
    ["windows_arm64"]="aarch64-pc-windows-msvc||.dll|windows|godot_ratex.arm64.dll"
    ["macos_x86_64"]="x86_64-apple-darwin|lib|.dylib|macos|libgodot_ratex.x86_64.dylib"
    ["macos_arm64"]="aarch64-apple-darwin|lib|.dylib|macos|libgodot_ratex.arm64.dylib"
    ["android_arm64"]="aarch64-linux-android|lib|.so|android|libgodot_ratex.arm64.so"
    ["android_x86_64"]="x86_64-linux-android|lib|.so|android|libgodot_ratex.x86_64.so"
    ["ios_arm64"]="aarch64-apple-ios|lib|.a|ios|libgodot_ratex.a"
    ["ios_x86_64"]="x86_64-apple-ios|lib|.a|ios|libgodot_ratex.x86_64.a"
    ["ios_sim"]="aarch64-apple-ios-sim|lib|.a|ios|libgodot_ratex.simulator.a"
)

parse_platform_data() {
    local platform_key="$1"
    local data="${TARGET_DATA[$platform_key]}"
    IFS='|' read -r _target _prefix _ext _subdir _outname <<< "$data"
    echo "$_target|$_prefix|$_ext|$_subdir|$_outname"
}

build_target() {
    local platform_key="$1"
    local data
    data="$(parse_platform_data "$platform_key")"
    IFS='|' read -r rust_target lib_prefix lib_ext subdir output_name <<< "$data"

    echo ""
    echo "================================================"
    echo " Building: $platform_key"
    echo " Target : $rust_target"
    echo " Profile: $BUILD_PROFILE"
    echo " Output : $ADDON_DIR/$subdir/$output_name"
    echo "================================================"

    local cargo_cmd="cargo build --target $rust_target"
    if [ "$BUILD_PROFILE" = "release" ]; then
        cargo_cmd="$cargo_cmd --release"
    fi
    if [ "$VERBOSE" = true ]; then
        cargo_cmd="$cargo_cmd --verbose"
    fi

    echo "Running: $cargo_cmd"
    eval "$cargo_cmd"

    local src_lib="target/${rust_target}/${BUILD_PROFILE}/${lib_prefix}${PACKAGE_NAME}${lib_ext}"
    if [ ! -f "$src_lib" ]; then
        echo "Error: Compiled library not found at $src_lib"
        return 1
    fi

    mkdir -p "$ADDON_DIR/$subdir"
    cp "$src_lib" "$ADDON_DIR/$subdir/$output_name"
    echo "Copied -> $ADDON_DIR/$subdir/$output_name"

    if [ "$CLEAN_AFTER" = true ]; then
        echo "Cleaning $rust_target..."
        cargo clean --target "$rust_target" --release 2>/dev/null || cargo clean --target "$rust_target"
    fi
}

# Determine what to build
if [ "$BUILD_ALL" = true ]; then
    echo "Building ALL supported targets (release mode)..."
    echo ""

    TARGETS_TO_BUILD=(
        "linux_x86_64"
        "linux_arm64"
        "windows_x86_64"
        "windows_arm64"
        "macos_x86_64"
        "macos_arm64"
        "android_arm64"
        "android_x86_64"
        "ios_arm64"
        "ios_x86_64"
        "ios_sim"
    )

    for t in "${TARGETS_TO_BUILD[@]}"; do
        rust_target="$(parse_platform_data "$t" | cut -d'|' -f1)"

        case "$(uname -s)" in
            Linux)
                if [[ "$rust_target" == *"-apple-"* ]] || [[ "$rust_target" == *"-pc-windows-"* ]]; then
                    echo "Skipping $t (cross-compilation from Linux — use CI for this target)"
                    continue
                fi
                ;;
            Darwin)
                if [[ "$rust_target" == *"-linux-"* ]] || [[ "$rust_target" == *"-pc-windows-"* ]] || [[ "$rust_target" == *"-android"* ]]; then
                    echo "Skipping $t (cross-compilation from macOS — use CI for this target)"
                    continue
                fi
                ;;
        esac

        build_target "$t" || echo "Warning: Build failed for $t, continuing..."
    done

elif [ -n "$SELECTED_PLATFORM" ]; then
    IFS=',' read -ra PLATFORMS <<< "$SELECTED_PLATFORM"
    case "$(uname -s)" in
        Linux)   HOST_ARCH="x86_64" ; [[ "$(uname -m)" == "aarch64" ]] && HOST_ARCH="arm64" ;;
        Darwin)  HOST_ARCH="arm64"  ; [[ "$(uname -m)" == "x86_64" ]] && HOST_ARCH="x86_64" ;;
        *)       HOST_ARCH="x86_64" ;;
    esac

    for plat in "${PLATFORMS[@]}"; do
        case "$plat" in
            linux)   build_target "linux_${HOST_ARCH}" || true ;;
            windows) build_target "windows_x86_64" || true ;;
            macos)   build_target "macos_${HOST_ARCH}" || true ;;
            android) build_target "android_arm64" || true ;;
            *) echo "Unknown platform: $plat";;
        esac
    done
elif [ -n "$SELECTED_ARCH" ]; then
    build_target "$SELECTED_ARCH" || exit 1
else
    HOST_OS=$(uname -s)
    HOST_ARCH=$(uname -m)

    case "$HOST_OS" in
        Linux)
            case "$HOST_ARCH" in
                x86_64)  build_target "linux_x86_64" ;;
                aarch64) build_target "linux_arm64" ;;
                *) echo "Error: Unsupported arch $HOST_ARCH"; exit 1 ;;
            esac
            ;;
        Darwin)
            case "$HOST_ARCH" in
                x86_64) build_target "macos_x86_64" ;;
                arm64)  build_target "macos_arm64" ;;
                *) echo "Error: Unsupported arch $HOST_ARCH"; exit 1 ;;
            esac
            ;;
        MINGW*|CYGWIN*|MSYS*)
            build_target "windows_x86_64"
            ;;
        *)
            echo "Error: Unknown host OS. Use --target or --platform."; exit 1
            ;;
    esac
fi

echo ""
echo "================================================"
echo " Build complete. Output in: $ADDON_DIR/"
echo "================================================"
ls -la "$ADDON_DIR/"*/ 2>/dev/null || true
