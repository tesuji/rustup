#!/bin/bash

set -ex

# Disable LTO=fat for non-"stable" builds
# Why?
# On my local machine:
#   - a LTO build (roughly) takes 3m42s.
#   - a non-LTO build takes 1m10s.
# FIXME: Use stabilized cargo named-profiles on futures
# https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#custom-named-profiles
if [[ $(git rev-parse --abbrev-ref HEAD) != stable || $GITHUB_REF != refs/heads/stable ]]; then
  sed -i ".ori" 's@^lto@#lto@; s@^codegen@#codegen@; ' Cargo.toml
  echo '[-] codegen options after changed'
  sed -e '1,/\[profile/d' -- Cargo.toml
fi

# Force use of lld to improve linking time
cat >> Cargo.toml << EOF
[target.${TARGET}]
linker = "lld-link"
EOF
