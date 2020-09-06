#!/bin/bash

set -ex

export RUST_BACKTRACE=1

rustc -vV
cargo -vV

FEATURES=()
case "$(uname -s)" in
  *NT* ) ;; # Windows NT
  * ) FEATURES=('--features' 'vendored-openssl') ;;
esac

# Disable LTO=fat for non-"stable" builds
# Why?
# On my local machine:
#   - a LTO build (roughly) takes 3m42s.
#   - a non-LTO build takes 1m10s.
# FIXME: Use stabilized cargo named-profiles on futures
# https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#custom-named-profiles
if [[ $(git rev-parse --abbrev-ref HEAD) != stable || $GITHUB_REF != refs/heads/stable ]]; then
  sed -i 's@^lto@#lto@; s@^codegen@#codegen@;' Cargo.toml
  echo '[-] codegen after changed'
  sed '1,/\[profile/d' Cargo.toml
fi

# Force use of lld to improve linking time
cat >> Cargo.toml << EOF
[target.${TARGET}]
linker = "lld-link"
EOF

# rustc only supports armv7: https://forge.rust-lang.org/release/platform-support.html
if [ "$TARGET" = arm-linux-androideabi ]; then
  export CFLAGS='-march=armv7'
fi

cargo build --locked --release --target "$TARGET" "${FEATURES[@]}"

runtest () {
  cargo test --locked --release --target "$TARGET" "${FEATURES[@]}" "$@"
}

if [ -z "$SKIP_TESTS" ]; then
  cargo run --locked --release --target "$TARGET" "${FEATURES[@]}" -- --dump-testament
  runtest -p download
  runtest --bin rustup-init
  runtest --lib --all
  runtest --doc --all

  runtest --test dist -- --test-threads 1

  find tests -maxdepth 1 -type f ! -path '*/dist.rs' -name '*.rs' \
  | sed -e 's@^tests/@@;s@\.rs$@@g' \
  | while read -r test; do
    runtest --test "${test}"
  done
fi
