#!/usr/bin/env bash

podman run --rm -v $PWD:/vhs \
  --env 'VISUAL=nvim' \
  -v $PWD/release/docfd:/usr/bin/docfd \
  localhost/docfd-demo-vhs \
  "$@"
