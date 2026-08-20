Setup:
  $ set -o pipefail
  $ mkdir -p xdg-empty
  $ export XDG_CONFIG_HOME="$TESTCASE_ROOT/xdg-empty"
  $ touch test.md test.txt

Explicit --config with whitespace and comments:
  $ printf '  # comment\n\n  --exts=md  \n' > explicit.config
  $ docfd --config explicit.config --debug-log - --cache-dir .cache-explicit --index-only . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'

Explicit --config=FILE:
  $ printf '%s\n' '--exts=md' > explicit-equals.config
  $ docfd --config=explicit-equals.config --debug-log - --cache-dir .cache-explicit-equals --index-only . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'

Repeatable config and command-line arguments are combined:
  $ printf '%s\n' '--exts=' '--add-exts=txt' > combined.config
  $ docfd --config combined.config --add-exts md --debug-log - --cache-dir .cache-combined --index-only . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'

--no-config disables project config loading:
  $ mkdir no-config-project
  $ touch no-config-project/test.md no-config-project/test.txt
  $ printf '%s\n' '--exts=txt' > no-config-project/.docfd-config
  $ (cd no-config-project && docfd --no-config --exts md --debug-log - --cache-dir .cache --index-only . 2>&1) | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/no-config-project/test.md'

Arguments after -- are not interpreted by config bootstrap parsing:
  $ touch no-config-project/--config=missing
  $ (cd no-config-project && docfd --no-config --debug-log - --cache-dir .cache-delimiter --index-only -- --config=missing 2>&1) | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/no-config-project/--config=missing'

Config discovery traverses ancestors and uses the nearest config:
  $ mkdir -p project/nested
  $ touch project/nested/test.md project/nested/test.txt
  $ printf '%s\n' '--exts=txt' > project/.docfd-config
  $ printf '%s\n' '--exts=md' > project/nested/.docfd-config
  $ (cd project/nested && docfd --debug-log - --cache-dir .cache --index-only . 2>&1) | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/project/nested/test.md'
  $ rm project/nested/.docfd-config
  $ (cd project/nested && docfd --debug-log - --cache-dir .cache-parent --index-only . 2>&1) | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/project/nested/test.txt'

Global config is used as a fallback:
  $ mkdir -p xdg/docfd
  $ printf '%s\n' '--exts=md' > xdg/docfd/config
  $ export XDG_CONFIG_HOME="$TESTCASE_ROOT/xdg"
  $ docfd --help=plain | grep -A3 'config'
  $ global_project=$(mktemp -d)
  $ touch "$global_project/test.md" "$global_project/test.txt"
  $ (cd "$global_project" && docfd --debug-log - --cache-dir .cache --index-only . 2>&1) | grep '^Using .* search mode' | sed "s|$global_project|GLOBAL_PROJECT|" | sort
  Using multiline search mode for document 'GLOBAL_PROJECT/test.md'
