#!/usr/bin/env bash

podman run -it \
  -v ~/docfd:/home/docfd \
  --workdir /home/docfd \
  --env VISUAL=nano \
  --rm \
  localhost/docfd \
  /bin/bash --login
