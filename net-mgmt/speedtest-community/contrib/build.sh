#!/bin/sh
set -eu

root=${1:?Specify an engine build directory}
version=1.2.1
checksum=159e3fbdf7250cbc0466f67d45543d4df49413b5b0f520de80243b59ac282836
mkdir -p "$root/bin"
root=$(cd "$root" && pwd)
archive="$root/librespeed-cli-$version.crate"
if [ ! -f "$archive" ]; then
    curl --fail --location --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 120 \
        "https://static.crates.io/crates/librespeed-cli/librespeed-cli-$version.crate" \
        -o "$archive"
fi
if command -v sha256 >/dev/null 2>&1; then
    actual=$(sha256 -q "$archive")
else
    actual=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
fi
if [ "$actual" != "$checksum" ]; then
    echo "LibreSpeed source checksum mismatch: $archive" >&2
    exit 1
fi
if [ ! -f "$root/librespeed-cli-$version/LICENSE" ]; then
    tar -xzf "$archive" -C "$root"
fi
if [ ! -x "$root/bin/librespeed-cli" ]; then
    if ! command -v cargo >/dev/null 2>&1; then
        echo "Build LibreSpeed on a Rust builder, or supply ENGINE_ROOT with the target binary and pinned source." >&2
        exit 1
    fi
    host=$(rustc -vV | sed -n 's/^host: //p')
    test -n "$host"
    SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-0} \
        cargo build --locked --release --target "$host" --target-dir "$root/target" \
        --manifest-path "$root/librespeed-cli-$version/Cargo.toml"
    install -m 755 "$root/target/$host/release/librespeed-cli" "$root/bin/librespeed-cli"
fi
if ! "$root/bin/librespeed-cli" --version | grep -q "^librespeed-cli v$version "; then
    echo "LibreSpeed binary is not the pinned version or cannot run on this builder." >&2
    exit 1
fi
if [ ! -s "$root/THIRD-PARTY-NOTICES" ]; then
    if ! command -v cargo >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
        echo "Supply THIRD-PARTY-NOTICES from the Rust builder in ENGINE_ROOT." >&2
        exit 1
    fi
    cargo metadata --locked --format-version 1 \
        --manifest-path "$root/librespeed-cli-$version/Cargo.toml" > "$root/metadata.json"
    python3 "$(dirname "$0")/licenses.py" "$root/metadata.json" "$root/THIRD-PARTY-NOTICES"
fi
