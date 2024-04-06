--exts does not intefere with --glob:

Anything with extension from --exts and --single-line-exts are picked:

--single-line-exts does not intefere with --glob:

--exts does not intefere with --single-line-glob:

--single-line-exts does not intefere with --single-line-glob:

Picking via multiple --glob and --single-line-glob:

--single-line-glob takes precedence over --glob:

--single-line-exts takes precedence over --exts:

--exts apply to paths from FILE in --paths-from FILE

--single-line-exts apply to paths from FILE in --paths-from FILE

Default path is not picked if any of the following is used: --paths-from, --glob, --single-glob:

Top-level files do not fall into singe line search group but into the default search group:

Top-level files with non-recognized extensions are still picked:

Top-level files without extensions are still picked:
