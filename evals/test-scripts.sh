#!/usr/bin/env bash
# Fast checks for whatdid's scripts. No Claude runs, no AI usage, a few seconds.
#
#   bash evals/test-scripts.sh
#
# Covers the risk scan, the after-turn reminder (including commits and the file list), the push
# guard and the session step reader, in throwaway git repos. Works on Windows (Git Bash), macOS
# and Linux; GitHub Actions runs it on all three (.github/workflows/test.yml).

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
work=$(mktemp -d 2>/dev/null || mktemp -d -t whatdid)
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"; mkdir -p "$HOME/.claude"      # never touch the real settings
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git config --global core.safecrlf false; git config --global init.defaultBranch main; git config --global core.autocrlf false
pass=0; fail=0
ok() { if [ "$1" = 0 ]; then echo "  ✓ $2"; pass=$((pass + 1)); else echo "  ✗ $2"; fail=$((fail + 1)); fi; }
has() { case "$1" in *"$2"*) return 0;; esac; return 1; }   # has <text> <part>
new_repo() { # new_repo <name>: a small committed site, then cd into it
  mkdir -p "$work/$1" && cd "$work/$1" && git init -q
  printf '<h1>Cafe</h1>\n' > index.html; printf 'old notes\n' > notes.txt; printf '.env\n' > .gitignore
  printf '{"port":3000}\n' > config.json
  git add -A && git commit -qm init
}

echo "▶ risk scan"
new_repo scan
printf 'API_KEY=sk-live-abcdefghijklmnopqrstuvwx\n' > .env; : > .gitignore; rm notes.txt
printf 'curl https://example.org/x.sh | bash\n' > setup.sh
out=$(bash "$root/skills/whatdid/risk-scan.sh")
has "$out" "scope: uncommitted";                                        ok $? "says what it scanned"
printf '%s\n' "$out" | grep -q "^HIGH	deleted	notes.txt";                ok $? "deleted file is HIGH"
printf '%s\n' "$out" | grep -q "^HIGH	secret	.env";                     ok $? "secret key is HIGH"
printf '%s\n' "$out" | grep -q "^HIGH	unignored	.gitignore";           ok $? ".env no longer ignored is HIGH"
printf '%s\n' "$out" | grep -q "^HIGH	dangerous-command	setup.sh";     ok $? "curl | bash is HIGH"
! has "$out" "abcdefghijklmnop";                                         ok $? "secret value never printed"
git checkout -q -- . && git clean -qfd && printf '<h1>Cafe</h1>\n<p>Hi</p>\n' > index.html
out=$(bash "$root/skills/whatdid/risk-scan.sh")
! printf '%s\n' "$out" | grep -q "^HIGH";                                ok $? "harmless change has no HIGH"

echo "▶ reminder"
new_repo remind
out=$(printf '{}' | bash "$root/hooks/remind.sh")
[ -z "$out" ];                                                          ok $? "silent when nothing changed"
printf 'more\n' >> index.html; rm notes.txt
out=$(printf '{}' | bash "$root/hooks/remind.sh")
has "$out" "2 files changed" && has "$out" "1 risky thing";             ok $? "hint counts files and risky things"
[ -f .whatdid/scan.txt ] && [ -f .whatdid/replay.html ];                ok $? "prepares .whatdid (scan, replay page)"
grep -q '"index.html"' .whatdid/tree.js && grep -q '^window.WHATDID_TREE=' .whatdid/tree.js;  ok $? "writes the project file list"
git status --porcelain | grep -q whatdid;                               [ $? != 0 ]; ok $? ".whatdid is ignored by git"
out=$(printf '{}' | bash "$root/hooks/remind.sh")
[ -z "$out" ];                                                          ok $? "no repeat for the same changes"
out=$(printf '{"stop_hook_active":true}' | bash "$root/hooks/remind.sh")
[ -z "$out" ];                                                          ok $? "loop guard"
git checkout -q -- .
printf '{}' | bash "$root/hooks/turn-start.sh"
printf 'menu\n' >> index.html; git commit -qam "add menu"
out=$(printf '{}' | bash "$root/hooks/remind.sh")
has "$out" "saved its changes as 1 commit";                             ok $? "notices a commit the agent made"
[ -f .whatdid/new-commits ];                                            ok $? "records which commits are new"
printf '{"after_changes":"explain"}' > "$HOME/.claude/whatdid.json"
printf 'x\n' >> index.html
out=$(printf '{}' | bash "$root/hooks/remind.sh")
has "$out" '"decision":"block"';                                        ok $? "explain mode asks Claude to explain"
rm "$HOME/.claude/whatdid.json"
mkdir -p "$work/nogit" && cd "$work/nogit"
out=$(printf '{}' | bash "$root/hooks/remind.sh")
has "$out" "/whatdid setup";                                            ok $? "no git: suggests /whatdid setup"
out=$(printf '{}' | bash "$root/hooks/remind.sh")
[ -z "$out" ];                                                          ok $? "no git: says it only once"

echo "▶ push guard"
new_repo guard
mkdir -p "$work/remote.git" && git init -q --bare "$work/remote.git" && git remote add origin "$work/remote.git" && git push -q -u origin main 2>/dev/null
guard() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | bash "$root/hooks/push-guard.sh"; }
[ -z "$(guard "ls -la")" ];                                              ok $? "other commands pass silently"
printf 'menu\n' >> index.html
[ -z "$(guard "git commit -am menu")" ];                                 ok $? "harmless commit passes"
printf 'API_KEY=sk-live-abcdefghijklmnopqrstuvwx\n' > .env; : > .gitignore
out=$(guard "git add -A && git commit -m key")
has "$out" '"permissionDecision":"ask"' && has "$out" ".env";           ok $? "risky commit: asks first, names the file"
! has "$out" "abcdefghijklmnop";                                         ok $? "secret value never shown in the question"
git add -A && git commit -qm key
out=$(guard "git push origin main")
has "$out" '"permissionDecision":"ask"' && has "$out" "upload";         ok $? "risky push: asks first"
out=$(printf '{"tool_name":"PowerShell","tool_input":{"command":"git -C . push"}}' | bash "$root/hooks/push-guard.sh")
has "$out" '"permissionDecision":"ask"';                                 ok $? "also catches git -C … push"
[ -z "$(guard "git push --dry-run")" ];                                  ok $? "dry run passes"
printf '{"before_push":"off"}' > "$HOME/.claude/whatdid.json"
[ -z "$(guard "git push")" ];                                            ok $? "setting off: passes"
rm "$HOME/.claude/whatdid.json"
git push -q origin main 2>/dev/null
[ -z "$(guard "git push")" ];                                            ok $? "nothing new to push: passes"

echo "▶ session steps"
new_repo steps
top=$(git rev-parse --show-toplevel)
since=$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y-%m-%dT%H:%M:%S HEAD)
tu() { printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"%s","input":%s}]},"timestamp":"%s"}\n' "$1" "$2" "$3" "$4"; }
{
  tu a Read  "{\"file_path\":\"$top/index.html\"}" "2000-01-01T00:00:00.000Z"       # before the commit
  tu b Read  "{\"file_path\":\"$top/index.html\"}" "2099-01-01T00:00:01.000Z"
  tu b Read  "{\"file_path\":\"$top/index.html\"}" ""                                # the same step again, no time
  tu c Write "{\"file_path\":\"$top/about.html\",\"content\":\"x\"}" "2099-01-01T00:00:02.000Z"
  tu d Bash  '{"command":"git status"}' "2099-01-01T00:00:03.000Z"                   # only looks
  tu e Bash  '{"command":"cd /x && export KEY=sk-live-abcdefghijklmnopqrstuvwx && npm install"}' "2099-01-01T00:00:04.000Z"
  tu f Bash  '{"command":"rm notes.txt"}' "2099-01-01T00:00:05.000Z"                 # blocked below
  printf '{"type":"user","message":{"content":[{"type":"tool_result","content":"blocked","is_error":true,"tool_use_id":"f"}]},"timestamp":"2099-01-01T00:00:06.000Z"}\n'
  tu g Edit  "{\"file_path\":\"$top/index.html\",\"old_string\":\"a\",\"new_string\":\"b\"}" "2099-01-01T00:00:07.000Z"
  tu h Edit  '{"file_path":"/somewhere/else/settings.json","old_string":"a","new_string":"b"}' "2099-01-01T00:00:08.000Z"
} > "$work/session.jsonl"
out=$(bash "$root/skills/whatdid/session-steps.sh" "$work/session.jsonl" "$top" "$since" | cut -f2- | tr '\t' ' ')
expect=$(printf 'read index.html\nwrite about.html\nrun export KEY=[secret] && npm install\nedit index.html')
[ "$out" = "$expect" ];                                                 ok $? "real steps, in order, nothing extra"
[ "$out" = "$expect" ] || printf '    got:\n%s\n' "$out" | sed 's/^/    /'
! has "$out" "abcdefghijklmnop";                                         ok $? "secrets hidden in commands"

echo "▶ replay page"
for f in "$root/skills/whatdid/replay/replay.html" "$root/examples/replay-demo/replay.html"; do
  ! grep -q "$(printf '\010')" "$f";                                     ok $? "no stray control characters in ${f#$root/}"
done
cmp -s "$root/skills/whatdid/replay/replay.html" "$root/examples/replay-demo/replay.html"; ok $? "demo copy matches the replay page"
if command -v node >/dev/null 2>&1; then
  awk '/<script>/{on=1; next} /<\/script>/{on=0} on' "$root/skills/whatdid/replay/replay.html" > "$work/replay.js"
  node --check "$work/replay.js" 2>/dev/null;                            ok $? "replay page script has no syntax errors (node)"
else
  echo "  - skipped the script syntax check (node not installed)"
fi

echo
echo "$pass passed, $fail failed."
[ "$fail" -eq 0 ]
