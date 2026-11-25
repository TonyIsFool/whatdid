#!/usr/bin/env bash
# Runs the whatdid test scenarios directly with `claude -p` and checks the answers with fixed rules.
#
#   bash evals/run-local.sh
#
# Why this exists: `claude plugin eval` refuses to let the AI run shell commands on Windows
# (it can't sandbox them there), and whatdid needs git. On macOS / Linux you can also run
#   claude plugin eval . --scaffold --allow-tools "Bash(git:*)" "Bash(bash:*)"
# Each scenario is one Claude run, so this uses a little of your Claude usage.

export LC_ALL=C                     # byte-wise grep: safe with emoji and non-English text
export MSYS_NO_PATHCONV=1           # Git Bash on Windows: don't turn "/whatdid" into a file path
here=$(cd "$(dirname "$0")" && pwd)
plugin=$(cd "$here/.." && pwd)
tmp=$(mktemp -d)
pass=0; fail=0

check() { # check "<what it checks>" <command...>
  if "${@:2}" >/dev/null 2>&1; then echo "  ✓ $1"; pass=$((pass + 1)); else echo "  ✗ $1"; fail=$((fail + 1)); fi
}
run_case() { # run_case <name> <scaffold script>
  local dir="$tmp/$1"
  mkdir -p "$dir" && (cd "$dir" && bash "$here/scaffolds/$2" >/dev/null 2>&1)
  echo "▶ $1 (running Claude…)"
  (cd "$dir" && claude --plugin-dir "$plugin" -p "/whatdid:whatdid no-replay" \
    --allowedTools Read Glob Grep "Bash(git:*)" "Bash(bash:*)" "PowerShell(git:*)" "PowerShell(bash:*)" > "$tmp/$1.md" 2>&1)
  out="$tmp/$1.md"
}
red_line_with() { grep -F "🔴" "$out" | grep -E -i "$1"; }

run_case planted-risks coffee-shop.sh
check "secret key being uploaded is red"        red_line_with '\.env|secret|key'
check "deleted old-promo.txt is red"            red_line_with 'old-promo'
check "port change is mentioned"                grep -F "8080" "$out"
check "outside website is mentioned"            grep -F "mailer-service" "$out"
check "secret value is never shown"             bash -c "! grep -F 'sk-test-51HxQ2' '$out'"
check "gives the undo command"                  grep -F "git stash" "$out"

run_case safe-change safe-change.sh
check "no red warnings for a harmless change"   bash -c "! grep -F '🔴' '$out'"
check "says nothing risky was found"            grep -E -i "🟢|nothing risky" "$out"
check "stays short (under 25 lines)"            bash -c "[ \$(grep -c '' '$out') -lt 25 ]"

echo
echo "$pass passed, $fail failed. Answers are in: $tmp"
[ "$fail" -eq 0 ]
