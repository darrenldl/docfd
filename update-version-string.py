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

print(f"Replacing version string in dune-project")

dune_project_lines = []
dune_project_new_lines = []

with open("dune-project") as f:
    dune_project_lines = f.readlines()

for line in dune_project_lines:
    dune_project_new_lines.append(re.sub(r"\(version.*", f"(version {version})", line))

with open("dune-project", "w") as f:
    for line in dune_project_new_lines:
        f.write(line)
