#!/bin/bash

set -ex

# Disable LTO=fat for non-"stable" builds
# Why?
# On my local machine:
#   - a LTO build (roughly) takes 3m42s.
#   - a non-LTO build takes 1m10s.
# FIXME: Use stabilized cargo named-profiles on futures
# https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#custom-named-profiles
if [[ $GITHUB_REF != refs/heads/stable || $(git rev-parse --abbrev-ref HEAD) != stable ]]; then
  sed -e 's@^lto@#lto@; s@^codegen@#codegen@; ' -i.ori Cargo.toml
  echo '[-] codegen options after changed'
  sed -e '1,/\[profile/d' -- Cargo.toml
fi

TARGET_UNDERSCORE=$(echo $TARGET | sed 's/-/_/g')
# Force use of lld to improve linking time
cat >> Cargo.toml << EOF
[target.${TARGET_UNDERSCORE}]
linker = "lld-link"
EOF
