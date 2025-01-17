#!/usr/bin/env bash

RETAG_CONFIRM_TEXT="retag-docfd"

opam_repo="$HOME/opam-repository"

echo "Checking if $opam_repo exists"

if [ ! -d "$opam_repo" ]; then
  echo "$opam_repo does not exist"
  exit 1
fi

ver=$(cat CHANGELOG.md \
  | grep '## ' \
  | head -n 1 \
  | sed -n 's/^## \s*\(\S*\)$/\1/p')

echo "Detected version for Docfd:" $ver

git_tag="$ver"

echo "Computed git tag for Docfd:" $git_tag

read -p "Are the version and git tag correct [y/n]? " ans

if [[ $ans != "y" ]]; then
  echo "Publishing canceled"
  exit 0
fi

echo "Checking if $git_tag exists in repo already"

if [[ $(git tag -l "$git_tag") == "" ]]; then
  echo "Tagging commit"
  git tag "$git_tag"
else
  read -p "Tag already exists, retag [y/n]? " ans

  if [[ $ans == "y" ]]; then
    read -p "Type \"$RETAG_CONFIRM_TEXT\" to confirm: " ans

    if [[ $ans != "$RETAG_CONFIRM_TEXT" ]]; then
      echo "Publishing canceled"
      exit 0
    fi

    echo "Removing tag"
    git tag -d "$git_tag"
    git push --delete origin "$git_tag"

    echo "Tagging commit"
    git tag "$git_tag"
  fi
fi

echo "Pushing all tags"

git push --tags

archive="$git_tag".tar.gz

echo "Archiving as $archive"

rm -f "$archive"
git archive --output=./"$archive" "$git_tag"

echo "Hashing $archive"

hash_cmd=sha256sum

archive_hash=$("$hash_cmd" "$archive" | awk '{ print $1 }')

echo "Hash from $hash_cmd:" $archive_hash

packages=(
  "docfd"
)

for package in ${packages[@]}; do
  package_dir="$opam_repo"/packages/"$package"/"$package"."$ver"
  dest_opam="$package_dir"/opam

  echo "Making directory $package_dir"
  mkdir -p "$package_dir"

  echo "Copying $package.opam over"
  cp "$package.opam" "$dest_opam"

  echo "Adding url section to $dest_opam"
  echo "
url {
  src:
    \"https://github.com/darrenldl/docfd/releases/download/$git_tag/$archive\"
  checksum:
    \"sha256=$archive_hash\"
}
" >> "$dest_opam"
done
