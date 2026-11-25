#!/usr/bin/env bash
# whatdid "UserPromptSubmit" hook. Runs when the user sends a message, before the AI starts working.
#
# It notes which commit the project is on right now, so the reminder at the end of the turn
# (remind.sh) can tell whether the AI saved its changes as commits during this turn.
# The note goes inside git's own hidden folder (.git/whatdid-turn-start), never into project files.
# Prints nothing: anything printed here would be shown to the AI.
#
# One git call only: on some Windows machines every new process costs ~0.3 s.

IFS= read -r -d '' _   # the hook's JSON; not needed

out=$(git rev-parse --absolute-git-dir HEAD 2>/dev/null)   # line 1: git folder, line 2: current commit
{ IFS= read -r gitdir; IFS= read -r head; } <<< "$out"
[ -n "$gitdir" ] && [ -d "$gitdir" ] || exit 0
[[ $head =~ ^[0-9a-f]{40,64}$ ]] || head=none   # no commits yet
printf '%s\n' "$head" > "$gitdir/whatdid-turn-start" 2>/dev/null
exit 0
