import re

ml_path = "bin/version_string.ml"

version = ""

with open("CHANGELOG.md") as f:
    for line in f:
        if line.startswith("## "):
            version = line.split(" ")[1].strip()
            break

print(f"Detected version for Docfd: {version}")

print(f"Writing to {ml_path}")

with open(ml_path, "w") as f:
    f.write(f"let s = \"{version}\"")
    f.write("\n")
