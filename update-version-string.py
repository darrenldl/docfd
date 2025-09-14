import os
import re

ml_path = "bin/version_string.ml"

version = os.environ.get('DOCFD_VERSION_OVERRIDE')

if version is None or version == "":
    with open("CHANGELOG.md") as f:
        for line in f:
            if line.startswith("## ") and not ("future release" in line.lower()):
                version = line.split(" ")[1].strip()
                break

print(f"Detected version for Docfd: {version}")

print(f"Writing to {ml_path}")

with open(ml_path, "w") as f:
    f.write(f"let s = \"{version}\"")
    f.write("\n")
