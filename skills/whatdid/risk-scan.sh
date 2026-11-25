#!/usr/bin/env bash
# whatdid risk scan: fixed rules that flag risky changes, so nothing important depends on the AI noticing it.
#
#   bash risk-scan.sh                 uncommitted changes (including new files)
#   bash risk-scan.sh <from> <to>     changes between two commits, e.g. HEAD~1 HEAD
#
# Output: one finding per line, tab-separated:   LEVEL  kind  file  detail
#   LEVEL is HIGH or MEDIUM, HIGH lines first. Secret VALUES are never printed, only where they are.
# Read-only: it only runs git, grep and awk.
#
# Kept to a handful of processes on purpose: on some Windows machines every new process
# costs ~0.3 s (antivirus), and the reminder hook that runs this has a time limit.

# Byte-by-byte matching: with a UTF-8 locale, case-insensitive matching can silently skip
# lines that contain non-English text (Chinese, emoji…), which could hide a secret.
export LC_ALL=C

top=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$top" ] || ! cd "$top"; then echo "# not a git repository"; exit 0; fi
g() { git -c core.quotepath=false -c core.safecrlf=false "$@" 2>/dev/null; }

untracked=""; ucontent=""
if [ $# -ge 2 ]; then
  scope="$1..$2"; range=("$1" "$2")
else
  scope="uncommitted"
  if g rev-parse --verify -q HEAD >/dev/null; then range=(HEAD); else range=(4b825dc642cb6eb9a060e54bf8d69288fbee4904); fi  # empty tree
  untracked=$(g ls-files --others --exclude-standard)
  if [ -n "$untracked" ]; then
    ufiles=(); while IFS= read -r f; do ufiles+=("$f"); done <<< "$untracked"   # (no mapfile: macOS ships bash 3.2)
    ucontent=$(grep -I -s -H -n '' -- "${ufiles[@]}")   # file:line:text, text files only
  fi
fi
names=$(g diff --name-status -M "${range[@]}")
numstat=$(g diff --numstat -M "${range[@]}")
patch=$(g diff -U0 --no-color -M "${range[@]}")

echo "# whatdid risk scan · scope: $scope"
S=$'\001'   # section separator: a byte that never appears in text
printf '%s\n' "${S}NAMES" "$names" "${S}NUMSTAT" "$numstat" "${S}PATCH" "$patch" "${S}UNTRACKED" "$untracked" "${S}UCONTENT" "$ucontent" |
awk -F'\t' -v S="$S" '
function out(level, kind, file, detail,   k) {
  k = level SUBSEP kind SUBSEP file
  if (k in seen) return
  seen[k] = 1; n++; L[n] = level; K[n] = kind; F[n] = file; T[n] = detail
}
function touch(f) { if (f != "" && !(f in changed)) { changed[f] = 1; nchanged++ } }
function added(f, t,   lt, h, rest) {      # rules for one added line t of file f
  lt = tolower(t)
  if (lt ~ /(api[_-]?key|secret|passw(or)?d|access[_-]?token|auth[_-]?token|private[_-]?key)["\x27]?[ \t]*[:=][ \t]*["\x27]?[a-z0-9_.\/+=-]{8,}/ ||
      t ~ /sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----/)
    out("HIGH", "secret", f, "contains what looks like a secret key or password (value not shown)")
  if (lt ~ /rm[ \t]+-[a-z]*(rf|fr)|remove-item.*-recurse|del[ \t]+\/[sq]|format[ \t]+[a-z]:|(curl|wget)[^|]*\|[ \t]*(sudo[ \t]+)?(ba|z)?sh|iex[ \t]*\(|chmod[ \t]+(-r[ \t]+)?777/)
    out("HIGH", "dangerous-command", f, "runs a command that can mass-delete files or run downloaded code")
  if (lt ~ /drop[ \t]+(table|database|schema)|delete[ \t]+from|truncate[ \t]+table/)
    out("HIGH", "database", f, "deletes or wipes data in a database")
  rest = lt
  while (match(rest, /https?:\/\/[a-z0-9.-]+/)) {
    h = substr(rest, RSTART, RLENGTH); sub(/^https?:\/\//, "", h); rest = substr(rest, RSTART + RLENGTH)
    if (h !~ /^(localhost|127\.|0\.0\.0\.0|example\.(com|org|net)$|www\.w3\.org$|schemas\.)/) out("MEDIUM", "outside-site", f, "connects to " h)
  }
}
$0 ~ "^" S { sec = substr($0, 2); next }
sec == "NAMES" && NF >= 2 {
  if ($1 ~ /^D/) out("HIGH", "deleted", $2, "file was deleted")
  if ($1 ~ /^R/) out("MEDIUM", "renamed", $3, "renamed from " $2 "; anything using the old name may break")
  touch($NF); next
}
sec == "NUMSTAT" && NF >= 3 {
  f = $3; if (f ~ / => /) { sub(/.* => /, "", f); gsub(/[{}]/, "", f) }
  if ($1 == "-") { out("MEDIUM", "binary", f, "binary file (image, PDF, …): open it to check"); next }
  lines += $1 + $2
  if ($2 >= 100 && $2 > 3 * $1) out("HIGH", "big-removal", f, $2 " lines removed, " $1 " added")
  next
}
sec == "PATCH" {
  if ($0 ~ /^\+\+\+ b\//) { pf = substr($0, 7); next }
  if ($0 ~ /^(\+\+\+|---) /) next
  if ($0 ~ /^\+/) { added(pf, substr($0, 2)); next }
  if (pf == ".gitignore" && $0 ~ /^-/ && tolower($0) ~ /\.env|\.pem|\.key|secret|credential|id_rsa/)
    out("HIGH", "unignored", ".gitignore", "no longer blocks: " substr($0, 2))
  next
}
sec == "UNTRACKED" && $0 != "" { touch($0); next }
sec == "UCONTENT" && match($0, /^[^:]+:[0-9]+:/) {
  f = substr($0, 1, RLENGTH); sub(/:[0-9]+:$/, "", f)
  added(f, substr($0, RLENGTH + 1)); next
}
END {
  for (f in changed) {
    lf = tolower(f); b = lf; sub(/.*\//, "", b)
    if (b !~ /^\.env\.(example|sample|template)$/ && b ~ /^\.env(\..*)?$|\.(pem|key|p12|pfx)$|^id_(rsa|ed25519)$|^credentials|secret/)
      out("HIGH", "secret-file", f, "secret file: if it is not in .gitignore it will be uploaded with everything else")
    if (lf ~ /^\.github\/workflows\/|dockerfile|docker-compose|(^|\/)(vercel\.json|netlify\.toml|procfile|\.gitlab-ci\.yml)$|deploy/)
      out("HIGH", "deploy", f, "changes how the project goes live")
    if (lf ~ /(^|\/)migrations\/|\.(sql|db|sqlite3?)$/) out("HIGH", "database", f, "changes the database")
    if (b ~ /^(package\.json|requirements.*\.txt|pyproject\.toml|pipfile|cargo\.toml|go\.mod|gemfile|composer\.json|build\.gradle|pom\.xml)$/)
      out("MEDIUM", "dependencies", f, "list of add-ons (dependencies) changed")
    if (b ~ /^(claude\.md|agents\.md|\.cursorrules)$/ || lf ~ /^\.claude\//) out("MEDIUM", "ai-rules", f, "the AI assistant'\''s own rules or settings changed")
    else if (lf !~ /^\.github\// && b ~ /^\.env\.example$|^(config|settings)\.|\.(ya?ml|toml|ini|conf)$/) out("MEDIUM", "settings", f, "a settings file changed")
    if (lf ~ /auth|login|password|permission|security|cors|csrf|session/) out("MEDIUM", "security", f, "login / permission / security code: check it carefully")
  }
  if (nchanged > 10 || lines > 500) out("MEDIUM", "large-change", "-", nchanged " files, " lines " lines changed: check several features")
  for (i = 1; i <= n; i++) if (L[i] == "HIGH") print L[i] "\t" K[i] "\t" F[i] "\t" T[i]
  for (i = 1; i <= n; i++) if (L[i] != "HIGH") print L[i] "\t" K[i] "\t" F[i] "\t" T[i]
  print (nchanged ? "# end · " nchanged " files" : "# no changes")
}'
