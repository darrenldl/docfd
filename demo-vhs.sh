#!/bin/bash

podman run --rm -v $PWD:/vhs \
  --env 'VISUAL=nvim' \
  -v $PWD/statically-linked/docfd:/usr/bin/docfd \
  localhost/docfd-demo-vhs \
  "$@"
