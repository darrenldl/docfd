#!/bin/bash

path="bin/version_string.ml"

ver=$(cat CHANGELOG.md \
  | grep '## ' \
  | head -n 1 \
  | sed -n 's/^## \s*\(\S*\)$/\1/p')

echo "Detected version for Docfd:" $ver

echo "Writing to" $path

echo "let s = "\"$ver\" > $path

echo "Replacing version string in dune-project"

sed -i "s/(version .*/(version $ver)/" dune-project
