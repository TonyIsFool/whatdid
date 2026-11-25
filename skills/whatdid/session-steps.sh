#!/usr/bin/env bash
# whatdid: the AI's real steps, in the order it did them, read from the Claude Code session record.
#
#   bash session-steps.sh <transcript.jsonl> <project folder> [since]
#
#   since: an ISO time in UTC (2026-11-25T07:39:36). Only steps after it are listed.
#
# Output, one step per line, tab-separated:   time  action  target
#   action is read, write (create or overwrite), edit or run. target is a path relative to the
#   project for files, or the command (shortened, with anything that looks like a secret hidden).
# Files outside the project, read-only commands (git status, ls, cat…) and steps that were
# blocked or failed are left out.
# Read-only: it only reads the session record. Plain awk, so it stays fast on large records.
export LC_ALL=C

transcript=${1:?transcript}; top=${2:?project folder}; since=${3:-}
[ -f "$transcript" ] || exit 0

awk -v top="$top" -v since="$since" '
function unesc(s) {                      # JSON string -> text (enough for paths and commands)
  gsub(/\\\\/, "\001", s); gsub(/\\"/, "\"", s); gsub(/\\[nrt]/, " ", s); gsub(/\001/, "\\", s); return s
}
function rel(p,   q, t) {                # absolute path -> path inside the project, or "" if outside
  q = p; gsub(/\\/, "/", q); t = top; gsub(/\\/, "/", t); sub(/\/+$/, "", t)
  if (q ~ /^\/[a-zA-Z]\//) q = substr(q, 2, 1) ":" substr(q, 3)   # /c/Users -> c:/Users
  if (t ~ /^\/[a-zA-Z]\//) t = substr(t, 2, 1) ":" substr(t, 3)
  if (tolower(substr(q, 1, length(t) + 1)) == tolower(t "/")) return substr(q, length(t) + 2)
  if (q !~ /^([a-zA-Z]:)?\//) return q                             # already relative
  return ""
}
function hide(c) {                       # never pass on anything that looks like a secret
  gsub(/(sk-|ghp_|gho_|github_pat_|xox[abprs]-|AKIA)[A-Za-z0-9_\-]+/, "[secret]", c)
  gsub(/=["\x27]?[A-Za-z0-9+\/_\-]{32,}/, "=[hidden]", c)
  gsub(/(Bearer|token|password|passwd)[ :=]+[^ "]+/, "\\1 [hidden]", c)
  gsub(/[ \t]+/, " ", c); sub(/^ /, "", c)
  return length(c) > 80 ? substr(c, 1, 77) "..." : c
}
function quiet(c) {                      # commands that only look, never change anything
  return c ~ /^(cd [^&;]*(&&|;) *)?(git (status|diff|log|show|rev-parse|ls-files|branch|remote -v)|ls|dir|cat|type|head|tail|wc|pwd|echo|grep|rg|find|which|where|Get-ChildItem|Get-Content|Select-String|Test-Path)( |$)/
}
FNR == NR {                              # first pass: which steps were blocked or failed
  if (index($0, "\"is_error\":true")) {   # each tool result is its own record line
    r = $0
    while (match(r, /"tool_use_id":"[^"]*"/)) { failed[substr(r, RSTART + 15, RLENGTH - 16)] = 1; r = substr(r, RSTART + RLENGTH) }
  }
  next
}
/"type":"tool_use"/ {
  ts = ""; if (match($0, /"timestamp":"[^"]*"/)) ts = substr($0, RSTART + 13, RLENGTH - 14)
  if (since != "" && (ts == "" || ts <= since)) next     # no time: cannot tell, so leave it out
  n = split($0, parts, /\{"type":"tool_use"/)
  for (i = 2; i <= n; i++) {
    c = parts[i]
    id = match(c, /"id":"[^"]*"/) ? substr(c, RSTART + 6, RLENGTH - 7) : ""
    if (id != "" && ((id in failed) || (id in seen))) continue   # never ran or failed, or already listed
    if (id != "") seen[id] = 1
    if (!match(c, /"name":"[^"]*"/)) continue
    name = substr(c, RSTART + 8, RLENGTH - 9)
    act = name == "Read" ? "read" : name == "Write" ? "write" : (name == "Edit" || name == "MultiEdit" || name == "NotebookEdit") ? "edit" : (name == "Bash" || name == "PowerShell") ? "run" : ""
    if (act == "") continue
    if (act == "run") {
      if (!match(c, /"command":"(\\.|[^"\\])*"/)) continue
      t = unesc(substr(c, RSTART + 11, RLENGTH - 12)); gsub(/^[ \t]+/, "", t)
      sub(/^cd +("[^"]*"|[^ &;]+) *(&&|;) */, "", t)   # "cd <project> && npm test" -> "npm test"
      if (quiet(t)) continue
      t = hide(t)
    } else {
      if (!match(c, /"(file_path|notebook_path)":"(\\.|[^"\\])*"/)) continue
      t = substr(c, RSTART, RLENGTH); sub(/^"[a-z_]+":"/, "", t); t = rel(unesc(substr(t, 1, length(t) - 1)))
      if (t == "" || t ~ /^\.whatdid\// || t ~ /^\.git\//) continue
    }
    key = act "\t" t
    if (key == last) continue           # the same step twice in a row: keep one
    last = key
    print ts "\t" key
    if (++count >= 120) exit
  }
}' "$transcript" "$transcript"
