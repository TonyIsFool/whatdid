#!/usr/bin/env bash
# whatdid "Stop" hook. Runs after every Claude turn, never uses the AI, finishes in a few seconds.
#
# When the project's files changed since the last check, it:
#   1. runs the risk scan (fixed rules) and saves it to .whatdid/scan.txt
#   2. keeps .whatdid/replay.html up to date, so /whatdid doesn't have to copy it (one permission prompt fewer)
#   3. shows a one-line hint with the number of risky findings  (after_changes = "remind", the default)
#      or asks Claude to explain right away                      (after_changes = "explain")
# In a folder without git it says once how to turn git on (/whatdid setup).
# It only writes inside .whatdid/ (which git ignores) and one small note file in ~/.claude.
#
# Uses bash built-ins wherever it can: on some Windows machines every new process costs ~0.3 s.

IFS= read -r -d '' input   # the hook's JSON from Claude Code

# Claude is already continuing because of this hook: don't loop.
[[ $input == *'"stop_hook_active":true'* || $input == *'"stop_hook_active": true'* ]] && exit 0

here=${BASH_SOURCE[0]%/*}
skill="$here/../skills/whatdid"

# Settings: ~/.claude/whatdid.json (the user's own, survives updates) wins over the plugin defaults.
setting() { # setting <key> <fallback>
  local f content
  for f in "$HOME/.claude/whatdid.json" "$skill/config.json"; do
    [ -f "$f" ] || continue
    IFS= read -r -d '' content < "$f"
    if [[ $content =~ \"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then printf '%s' "${BASH_REMATCH[1]}"; return; fi
  done
  printf '%s' "$2"
}
mode=$(setting after_changes remind)
[ "$mode" = "off" ] && exit 0

say() { printf '{"systemMessage":"%s"}\n' "$1"; exit 0; }

top=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$top" ]; then
  # No git here: whatdid can't see changes. Say so once per folder, never again.
  note="$HOME/.claude/whatdid-nogit-hinted.txt"
  if [ -f "$note" ]; then while IFS= read -r line; do [ "$line" = "$PWD" ] && exit 0; done < "$note"; fi
  [ -d "$HOME/.claude" ] && printf '%s\n' "$PWD" >> "$note"
  say "💡 whatdid can't see what the AI changes in this folder, because git is off here. Type /whatdid setup to turn it on (one time)."
fi

status=$(git -C "$top" -c core.quotepath=false status --porcelain=v1 -uall 2>/dev/null)
dir="$top/.whatdid"
state="$dir/last-seen"
if [ -z "$status" ]; then [ -f "$state" ] && rm -f "$state"; exit 0; fi

# A fingerprint of the current changes; only act when it differs from last time.
fp=$( { printf '%s\n' "$status"; git -C "$top" -c core.safecrlf=false diff HEAD 2>/dev/null; } | git hash-object --stdin )
prev=""; [ -f "$state" ] && IFS= read -r prev < "$state"
[ "$prev" = "$fp" ] && exit 0

[ -d "$dir" ] || mkdir -p "$dir"
printf '*\n' > "$dir/.gitignore"
printf '%s\n' "$fp" > "$state"
[ "$skill/replay/replay.html" -nt "$dir/replay.html" ] && cp "$skill/replay/replay.html" "$dir/replay.html" 2>/dev/null
( cd "$top" && bash "$skill/risk-scan.sh" > "$dir/scan.txt" 2>/dev/null )

n=0; while IFS= read -r line; do n=$((n + 1)); done <<< "$status"
high=0; while IFS= read -r line; do [[ $line == HIGH* ]] && high=$((high + 1)); done < "$dir/scan.txt"
if [ "$n" = 1 ]; then what="1 file changed"; else what="$n files changed"; fi
if [ "$high" = 1 ]; then what="$what, 🔴 1 risky thing found"; elif [ "$high" -gt 1 ]; then what="$what, 🔴 $high risky things found"; fi

if [ "$mode" = "explain" ]; then
  printf '{"decision":"block","reason":"Project files changed during this turn. Use the whatdid skill now to explain the changes to the user in plain words, following its settings."}\n'
  exit 0
fi
say "💡 $what. Type /whatdid to see what the AI changed, in plain words."
