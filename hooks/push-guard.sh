#!/usr/bin/env bash
# whatdid "PreToolUse" hook for shell commands. Runs before the AI runs a command.
#
# If the command is a `git commit` or `git push`, it runs the risk scan on exactly what would be
# saved or uploaded. When the scan finds something high-risk (a secret key, a secret file that is
# no longer protected, a deleted file, a deploy or database change…), it pauses and asks the user,
# in plain words, before the command runs. Anything else passes straight through.
#
# Setting `before_push`: "ask" (default) or "off".
# Every other command exits within a few milliseconds: no git, no new process.

IFS= read -r -d '' input   # the hook's JSON from Claude Code

# Fast path: only git commit / git push are interesting.
re='git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+|[[:space:]]+--?[a-z-]+(=[^[:space:]]+)?)*[[:space:]]+(commit|push)([^a-z-]|$)'
[[ $input =~ $re ]] || exit 0
what=${BASH_REMATCH[3]}
[[ $input == *--dry-run* ]] && exit 0

here=${BASH_SOURCE[0]%/*}
skill="$here/../skills/whatdid"
EMPTY_TREE=4b825dc642cb6eb9a060e54bf8d69288fbee4904

setting() { # setting <key> <fallback>: ~/.claude/whatdid.json wins over the plugin defaults
  local f content
  for f in "$HOME/.claude/whatdid.json" "$skill/config.json"; do
    [ -f "$f" ] || continue
    IFS= read -r -d '' content < "$f"
    if [[ $content =~ \"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then printf '%s' "${BASH_REMATCH[1]}"; return; fi
  done
  printf '%s' "$2"
}
[ "$(setting before_push ask)" = "off" ] && exit 0

# The command runs in the session's folder, which is where this hook runs too.
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$top" ] || exit 0
cd "$top" || exit 0

if [ "$what" = push ]; then
  # Commits that are on this branch but not yet on any remote: exactly what a push uploads.
  oldest=$(git rev-list --reverse HEAD --not --remotes 2>/dev/null | head -n 1)
  [ -n "$oldest" ] || exit 0
  from=$(git rev-parse -q --verify "$oldest^" 2>/dev/null) || from=$EMPTY_TREE
  scan=$(bash "$skill/risk-scan.sh" "$from" HEAD 2>/dev/null)
  verb="upload"; noun="push"
else
  scan=$(bash "$skill/risk-scan.sh" 2>/dev/null)
  verb="save"; noun="commit"
fi

# Collect the high-risk findings, in plain words.
n=0; list=""
while IFS=$'\t' read -r level kind file detail; do
  [ "$level" = HIGH ] || continue
  n=$((n + 1))
  [ "$n" -le 4 ] && list="$list\n• $file: $detail"
done <<< "$scan"
[ "$n" -gt 0 ] || exit 0
[ "$n" -gt 4 ] && list="$list\n• …and $((n - 4)) more"

if [ "$n" = 1 ]; then things="1 risky thing"; else things="$n risky things"; fi
reason="🛑 whatdid: this $noun would $verb $things:$list\nIf you're not sure, choose No and type /whatdid to see what changed in plain words."

esc() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; s=${s//\\\\n/\\n}; s=${s//$'\t'/ }; printf '%s' "$s"; }
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$(esc "$reason")"
exit 0
