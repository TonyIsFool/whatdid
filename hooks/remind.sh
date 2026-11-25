#!/usr/bin/env bash
# whatdid "Stop" hook. Runs after every Claude turn, never uses the AI, finishes in a few seconds.
#
# It notices two kinds of change:
#   - uncommitted changes to the project's files (new since the last check)
#   - commits the AI made during this turn (turn-start.sh noted where the turn began)
# For each, it runs the risk scan (fixed rules) and saves it in .whatdid/:
#   scan.txt          uncommitted changes
#   scan-commits.txt  this turn's commits; new-commits says which ones ("<from> <to> <count>")
#   steps.tsv         the AI's real steps in order, read from the session record (session-steps.sh)
# Then it keeps .whatdid/replay.html up to date (one permission prompt fewer for /whatdid),
# writes .whatdid/tree.js (the project's file list, which the replay uses to shape its 3D building) and
#   shows a one-line hint with the number of risky findings  (after_changes = "remind", the default)
#   or asks Claude to explain right away                      (after_changes = "explain")
# In a folder without git it says once how to turn git on (/whatdid setup).
# It only writes inside .whatdid/ (which git ignores), one note in .git/ and one in ~/.claude.
#
# Uses bash built-ins wherever it can: on some Windows machines every new process costs ~0.3 s.

IFS= read -r -d '' input   # the hook's JSON from Claude Code

# Claude is already continuing because of this hook: don't loop.
[[ $input == *'"stop_hook_active":true'* || $input == *'"stop_hook_active": true'* ]] && exit 0

here=${BASH_SOURCE[0]%/*}
skill="$here/../skills/whatdid"
EMPTY_TREE=4b825dc642cb6eb9a060e54bf8d69288fbee4904

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
plural() { if [ "$1" = 1 ]; then printf '1 %s' "$2"; else printf '%s %ss' "$1" "$2"; fi; }   # plural 3 file → "3 files"
count_high() { local line k=0; while IFS= read -r line; do [[ $line == HIGH* ]] && k=$((k + 1)); done < "$1"; printf '%s' "$k"; }

# One git call: project folder, git's own folder, current commit.
out=$(git rev-parse --show-toplevel --absolute-git-dir HEAD 2>/dev/null)
{ IFS= read -r top; IFS= read -r gitdir; IFS= read -r head; } <<< "$out"
if [ -z "$top" ]; then
  # No git here: whatdid can't see changes. Say so once per folder, never again.
  note="$HOME/.claude/whatdid-nogit-hinted.txt"
  if [ -f "$note" ]; then while IFS= read -r line; do [ "$line" = "$PWD" ] && exit 0; done < "$note"; fi
  [ -d "$HOME/.claude" ] && printf '%s\n' "$PWD" >> "$note"
  say "💡 whatdid can't see what the AI changes in this folder, because git is off here. Type /whatdid setup to turn it on (one time)."
fi
[[ $head =~ ^[0-9a-f]{40,64}$ ]] || head=none

dir="$top/.whatdid"
prepare() { # make .whatdid/ (ignored by git) and keep the replay page fresh
  [ -d "$dir" ] || mkdir -p "$dir"
  printf '*\n' > "$dir/.gitignore"
  [ "$skill/replay/replay.html" -nt "$dir/replay.html" ] && cp "$skill/replay/replay.html" "$dir/replay.html" 2>/dev/null
  write_tree
}
write_tree() { # .whatdid/tree.js: the project's real files (path + size), which the replay uses to shape its 3D building
  [ -n "$tree_done" ] && return; tree_done=1
  { git -C "$top" -c core.quotepath=false ls-tree -r -l HEAD 2>/dev/null; printf '%s\n' "$status"; } |
  LC_ALL=C awk -v name="${top##*/}" '
    function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); gsub(/[\001-\037]/, " ", s); return s }
    function add(p, size) {
      if (p ~ /^".*"$/) p = substr(p, 2, length(p) - 2)      # git quotes unusual names
      if (p == "" || (p in seen) || n >= 600) return
      seen[p] = 1; printf "%s[\"%s\",%d]", (n++ ? "," : ""), esc(p), size
    }
    BEGIN { printf "window.WHATDID_TREE={\"project\":\"%s\",\"files\":[", esc(name) }
    /^[0-9]+ blob [0-9a-f]+ / { add(substr($0, index($0, "\t") + 1), $4 + 0); next }       # committed files
    /^[0-9]+ / { next }
    length($0) > 3 && substr($0, 3, 1) == " " { p = substr($0, 4); k = index(p, " -> "); if (k) p = substr(p, k + 4); add(p, 0) }   # new, not committed yet
    END { print "]};" }
  ' > "$dir/tree.js" 2>/dev/null
}

status=$(git -C "$top" -c core.quotepath=false status --porcelain=v1 -uall 2>/dev/null)

# --- Commits made during this turn ---
ncommits=0; high_c=0
startf="$gitdir/whatdid-turn-start"
if [ -f "$startf" ] && [ "$head" != none ]; then
  IFS= read -r start < "$startf"
  printf '%s\n' "$head" > "$startf"   # report each commit once, even if the turn goes on
  if [ -n "$start" ] && [ "$start" != "$head" ]; then
    if [ "$start" = none ]; then from=$EMPTY_TREE; ncommits=$(git -C "$top" rev-list --count HEAD 2>/dev/null)
    else from=$start; ncommits=$(git -C "$top" rev-list --count "$start..$head" 2>/dev/null); fi
    # 0 means the AI moved back to an older commit (no new commits): nothing to explain here.
    if [[ $ncommits =~ ^[1-9][0-9]*$ ]]; then
      prepare
      ( cd "$top" && bash "$skill/risk-scan.sh" "$from" "$head" > "$dir/scan-commits.txt" 2>/dev/null )
      printf '%s %s %s\n' "$from" "$head" "$ncommits" > "$dir/new-commits"
      high_c=$(count_high "$dir/scan-commits.txt")
      cfiles=0
      while IFS= read -r line; do [[ $line =~ ^\#\ end\ ·\ ([0-9]+)\ files ]] && cfiles=${BASH_REMATCH[1]}; done < "$dir/scan-commits.txt"
    else
      ncommits=0
    fi
  fi
fi

# --- Uncommitted changes ---
nfiles=0; high_u=0
state="$dir/last-seen"
if [ -z "$status" ]; then
  [ -f "$state" ] && rm -f "$state"
else
  # A fingerprint of the current changes; only act when it differs from last time.
  fp=$( { printf '%s\n' "$status"; git -C "$top" -c core.safecrlf=false diff HEAD 2>/dev/null; } | git hash-object --stdin )
  prev=""; [ -f "$state" ] && IFS= read -r prev < "$state"
  if [ "$prev" != "$fp" ]; then
    prepare
    printf '%s\n' "$fp" > "$state"
    ( cd "$top" && bash "$skill/risk-scan.sh" > "$dir/scan.txt" 2>/dev/null )
    while IFS= read -r line; do nfiles=$((nfiles + 1)); done <<< "$status"
    high_u=$(count_high "$dir/scan.txt")
  fi
fi

[ "$nfiles" = 0 ] && [ "$ncommits" = 0 ] && exit 0

# --- The AI's real steps, in order, from this session's record (for the replay) ---
# Steps after the commit these changes start from: this turn's first new commit's parent, or HEAD.
if [[ $input =~ \"transcript_path\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  transcript=${BASH_REMATCH[1]//\\\\/\/}
  base=$head; [ "$ncommits" != 0 ] && base=$from
  since=""
  [ "$base" != none ] && [ "$base" != "$EMPTY_TREE" ] && since=$(TZ=UTC git -C "$top" log -1 --format=%cd --date=format-local:%Y-%m-%dT%H:%M:%S "$base" 2>/dev/null)
  bash "$skill/session-steps.sh" "$transcript" "$top" "$since" > "$dir/steps.tsv" 2>/dev/null
fi

if [ "$mode" = "explain" ]; then
  printf '{"decision":"block","reason":"Project files changed during this turn. Use the whatdid skill now to explain the changes to the user in plain words, following its settings."}\n'
  exit 0
fi

high=$((high_u + high_c))
risk=""; [ "$high" -gt 0 ] && risk=", 🔴 $(plural "$high" "risky thing") found"
commits="$(plural "$ncommits" commit) ($(plural "$cfiles" file))"
if [ "$ncommits" = 0 ]; then
  say "💡 $(plural "$nfiles" file) changed$risk. Type /whatdid to see what the AI changed, in plain words."
elif [ "$nfiles" = 0 ]; then
  say "💡 The AI saved its changes as $commits$risk. Type /whatdid to see what it changed, in plain words."
else
  say "💡 $(plural "$nfiles" file) changed, and the AI also made $commits$risk. Type /whatdid for the uncommitted changes, or /whatdid new commits for the commits."
fi
