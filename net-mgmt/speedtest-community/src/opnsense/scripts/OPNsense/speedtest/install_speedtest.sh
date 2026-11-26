#!/bin/sh
# Copyright (C) 2021 Miha Kralj
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

remove_legacy_python_client() {
  pkg info -x '^py3[0-9]+-speedtest-cli-' 2>/dev/null |
    while IFS= read -r package; do
      [ -z "${package}" ] || pkg delete -y "${package}" >/dev/null
    done
}

install_native_client() {
  OOKLA_URL=$(
    curl -fsSL "https://www.speedtest.net/apps/cli" |
      xmllint --html --xpath "string(//*[@id='freebsd']/pre/code[7]/text())" - 2>/dev/null |
      awk -F'"' '{print $2}'
  )
  case "${OOKLA_URL}" in
    https://install.speedtest.net/*.pkg) ;;
    *)
      echo "Unable to determine the current FreeBSD Speedtest package URL." >&2
      exit 1
      ;;
  esac
  remove_legacy_python_client
  pkg install -y libidn2
  pkg add -f "${OOKLA_URL}"
}

install_rust_engine() {
  if /usr/local/bin/librespeed-cli-rust --version 2>/dev/null |
      grep -q '^librespeed-cli v1\.2\.1 '; then
    echo "Native Rust transfer engine 1.2.1 is already installed."
    return 0
  fi
  RUST_REMOVE=0
  if ! pkg info -e rust >/dev/null 2>&1; then
    pkg install -y rust
    RUST_REMOVE=1
  fi
  cleanup_rust_build() {
    rm -rf /var/tmp/opnsense-librespeed-rust
    if [ "${RUST_REMOVE}" -eq 1 ]; then
      pkg delete -y rust >/dev/null 2>&1 || true
    fi
  }
  trap cleanup_rust_build EXIT HUP INT TERM
  rm -rf /var/tmp/opnsense-librespeed-rust
  mkdir -p /var/tmp/opnsense-librespeed-rust/home \
    /var/tmp/opnsense-librespeed-rust/root \
    /var/tmp/opnsense-librespeed-rust/target
  CARGO_HOME=/var/tmp/opnsense-librespeed-rust/home \
    CARGO_TARGET_DIR=/var/tmp/opnsense-librespeed-rust/target \
    cargo install --locked --version 1.2.1 librespeed-cli \
      --root /var/tmp/opnsense-librespeed-rust/root
  install -m 0755 -o root -g wheel \
    /var/tmp/opnsense-librespeed-rust/root/bin/librespeed-cli \
    /usr/local/bin/librespeed-cli-rust
}

case "$1" in
  http|socket|native)
    install_native_client
    ;;
  rust)
    install_rust_engine
    ;;
  delete)
    pkg delete -y speedtest >/dev/null 2>&1 || true
    remove_legacy_python_client
    rm -f /usr/local/bin/librespeed-cli-rust
    ;;
  *)
    echo "Usage: $0 {native|rust|delete}" >&2
    exit 64
    ;;
esac

