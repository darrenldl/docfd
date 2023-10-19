#!/bin/bash
podman run -it \
  -v ~/docfd:/home/opam/docfd \
  --userns keep-id:uid=1000,gid=1000 \
  --workdir /home/opam/docfd \
  --env VISUAL=nano \
  --rm \
  localhost/docfd
