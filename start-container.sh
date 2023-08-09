#!/bin/bash
podman run -it \
  -v ~/docfd:/home/opam/docfd \
  --userns keep-id:uid=$(id -u),gid=$(id -g) \
  --workdir /home/opam/docfd \
  --rm \
  localhost/docfd
