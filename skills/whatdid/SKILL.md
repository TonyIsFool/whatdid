---
name: whatdid
description: Explain "what did the AI just change?" in plain words for people who can't read code. Reads the git changes and says what was done, what's risky, how to check it worked, and how to undo it, and can play an animated replay of the agent's actions in the browser. Use when the user asks "what did you change", "what do these changes mean", "is it safe to accept this", "explain this diff", or seems unable to read a code change.
argument-hint: "[brief|full] [no-replay] [last commit | <file>] · setup · set <setting> <value> · settings"
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git show:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git ls-files:*), Read, Grep, Glob, Edit(.whatdid/**)
---

# whatdid: explain AI changes in plain words

Your reader **can't read code**. They want four answers, fast:

1. What changed?
2. Could it break something?
3. How do I check it worked?
4. How do I undo it?

Translate the change into everyday language. Don't read the code back to them.

**Never modify the project.** Don't edit project files, commit, or run any undo command. Undo commands are for the user to read and run if they choose. The only files you may write are the replay files in the project's `.whatdid/` folder (step 5), which git ignores, and the user's settings file when they ask to change a setting. The one exception is `/whatdid setup`, which the user runs on purpose.

---

## Setup command (`setup`)

If `$ARGUMENTS` starts with `setup`, **only** do this and stop. It turns on git so whatdid can see changes. Many people who don't code have never heard of git, so keep every message short and friendly, and never say "repository", "commit" or "staging" without a 2–5 word explanation.

1. Run `git rev-parse --is-inside-work-tree` and `git rev-parse --verify HEAD`. If both succeed, say "✅ Already set up. After the AI changes something, type /whatdid." and stop.
2. Say in two short lines what will happen: "I'll turn on git here and save a starting snapshot of your files, so next time I can show you exactly what the AI changed. Nothing gets uploaded anywhere."
3. If it isn't a git repo yet: `git init`.
4. **Keep secrets and junk out of the snapshot.** If there is no `.gitignore`, Write one containing these lines: `.env`, `.env.*`, `!.env.example`, `*.pem`, `*.key`, `node_modules/`, `__pycache__/`, `.venv/`, `venv/`, `.DS_Store`, `Thumbs.db`. If a `.gitignore` already exists, only add whichever of `.env`, `.env.*`, `!.env.example`, `*.pem`, `*.key` are missing, and leave everything else in it alone.
5. `git add -A`, then `git status --short` to see what will go into the snapshot. **Stop and ask the user first** if it lists more than about 2,000 files, any file that looks like a secret (`.env`, keys, `credentials`), or any file bigger than 50 MB.
6. Check `git config user.name`. If it's empty, commit with a local stand-in name so it works: `git -c user.name="whatdid" -c user.email="whatdid@localhost" commit -q -m "Starting snapshot (whatdid setup)"`. Otherwise: `git commit -q -m "Starting snapshot (whatdid setup)"`.
7. Finish with: "✅ Done! From now on, after the AI changes something, type /whatdid to see what changed. If you ever want to share this project online, git is ready for that too."

## Settings commands (`set` / `settings`)

If `$ARGUMENTS` starts with `set` or `settings`, **only** handle the settings and stop. Don't explain any changes.

The user's settings live in `whatdid.json` in their Claude folder: `~/.claude/whatdid.json` (on Windows `%USERPROFILE%\.claude\whatdid.json`). It survives plugin updates. The defaults live in `config.json` next to this SKILL.md.

| Setting | Values | Default | Meaning |
|---|---|---|---|
| `detail` | `brief` / `full` | `brief` | How long the explanation is |
| `replay` | `on` / `off` | `on` | Open the animated replay |
| `after_changes` | `remind` / `explain` / `off` | `remind` | After the AI changes files: show a one-line hint to run /whatdid, explain automatically, or do nothing |

- **`settings`**: read both files and show the current value of every setting in a short table (user file wins), plus one line on how to change one, e.g. `/whatdid set detail full`.
- **`set <setting> <value>`**: check the name and value against the table (accept close spellings and `true`/`false` for on/off; store `replay` as `true`/`false`). Read the user's file if it exists, change only that one setting, and Write the whole file back as JSON, keeping the other settings. Then confirm in one line. If the name or value isn't valid, show the table instead and change nothing.

## Step 0: Settings

1. Read the defaults from `config.json` next to this SKILL.md, then the user's `~/.claude/whatdid.json` if it exists. Anything in the user's file wins. Defaults if both are missing: `{"detail": "brief", "replay": true}`.
2. Words in `$ARGUMENTS` override the settings for this run only:
   - Detail: `brief` or `full`.
   - Replay: `replay` turns it on, `no-replay` turns it off.
   - Everything else picks **which changes** to explain (see the table below).
3. **Always write in English**: the answer and the replay, even when the user chats in another language. Command text and file names stay as they are.

| Scope words | What to explain | Commands |
|---|---|---|
| (none, default) | Uncommitted changes, including new files | Step 1 |
| "last commit" | The latest commit | `git show HEAD --stat`, then `git show HEAD` |
| "last N commits" | The last N commits | `git log -N --stat`, then `git diff HEAD~N HEAD` |
| A file name | Only that file | Add `-- <file>` to the default commands |

If the default scope has **no uncommitted changes**, explain the last commit instead and say so in one short line.

## Step 1: Gather the facts (read-only)

1. `git rev-parse --is-inside-work-tree`: is this a git repo? If not, see "Special cases".
2. `git rev-parse --verify HEAD`: are there any commits? If not, this is a brand-new repo and every file counts as new.
3. `git status --porcelain=v1 -uall -z`: the changed files. `-z` keeps non-English file names readable; entries are separated by NUL. The two-letter codes mean `M` modified, `A` added, `D` deleted, `R` renamed, `??` new (untracked).
4. `git diff HEAD --stat`: lines changed per file. With no commits, use `git diff --cached --stat`.
5. `git diff HEAD`: the actual changes. With no commits, use `git diff --cached`.
6. **New files** (`??`) don't appear in the diff, so read them with the Read tool. Don't open binary files (images, archives); just name the file type.
7. **Risk scan** (fixed rules, so nothing important depends on you noticing it). For uncommitted changes, first Read `.whatdid/scan.txt` at the top of the project: the reminder hook writes it after every turn that changed files, so no command is needed. Use it if its first line says `scope: uncommitted` and the files it covers match the changed files from step 3. Otherwise (missing, out of date, or you're explaining commits) run `bash "<this skill's folder>/risk-scan.sh"`, adding `<from> <to>` for commits (e.g. `HEAD~1 HEAD`). Each finding is one line: `LEVEL  kind  file  detail`.

Notes:
- `--stat` and diff may show non-English names escaped, like `"\346\227\247..."`. Always use the readable names from step 3.
- Ignore `LF will be replaced by CRLF` warnings and never mention them.
- **Big changes** (diff over about 800 lines, or more than 15 files): use `--stat` to find the important files and read those one at a time with `git diff HEAD -- <file>`. For generated files (`package-lock.json`, `*.lock`, `dist/`, `build/`), just say "auto-generated, nothing to check".

## Step 2: Check the risks

**Start from the risk scan (step 1.7). It is the floor, not the ceiling:**
- Every `HIGH` line must show up as a 🔴 bullet in "Watch out" and as a `"risk": "high"` step in the replay. Never drop or soften one. If you're sure it's a false alarm (e.g. the "secret" is clearly a placeholder like `your-key-here`), still mention it, as 🟡, and say why you think it's harmless.
- Every `MEDIUM` line becomes at least a 🟡, unless it's plainly harmless (e.g. a settings file where only a comment changed).

Then compare the changes against [risk-checklist.md](risk-checklist.md) for anything the scan can't see, and tag each extra finding 🔴 / 🟡.

Also check: **does the change match what the user asked for?** If this conversation shows the user's original request, compare against it. Anything the AI did that wasn't asked for (touching other files, deleting code, extra features) is 🟡 "You didn't ask for this".

## Step 3: Understand before you explain

- Group changes by **goal**, not by file. Five files edited to add one button is **one thing**.
- For each thing, what will the user **notice**? (A new link on the page? A different address to open?)
- Say the effect, not the mechanism: "a pop-up appears when you click the button", not "added an onClick handler".

## Step 4: Write the answer

### `brief` (default)

Keep it to **about 12 lines or fewer** for a normal change. **At most 5 bullets under "What changed"** and at most 4 under "Watch out": merge files that serve the same goal into one bullet (a new page plus the menu link to it is *one* thing). One line per bullet, roughly 20 words at most. Use everyday words instead of jargon, and if a technical word can't be avoided, explain it in 2–5 words in parentheses. Leave out any section that has nothing to say, except "Watch out", which is always shown.

```
**In short:** <one sentence, no jargon>

**What changed**
- 🆕 Created `<file>`: <what it is / does>
- ✏️ Edited `<file>`: <what's different>
- 🗑️ Deleted `<file>`
(One bullet per *thing*. If several files serve one thing, name the main one and add "+2 files".)

**⚠️ Watch out**
- 🔴 <problem>: <why it matters>. <what to do, with a command if one helps>
- 🟡 <problem>: <why it matters>
(If nothing was found: "🟢 Nothing risky found. Still worth a quick check below.")

**✅ Check it:** <where to click or open> → <what you should see>

**↩️ Undo everything:** `git stash -u` (changed your mind? `git stash pop` brings it back)

<N> files · +<added> −<removed>
```

For the footer, `<N>` counts every changed file including new and deleted ones, and `<added>` includes the lines of new (`??`) files, which `--stat` leaves out. Count them from what you read.


### `full`

Same sections, but each one can take a few sentences. Add a "Undo just one part" list (see below) and a short glossary of the technical words you used. Use this when the user asks for more detail.

### Undo commands

- **Undo everything, recoverable (default):** `git stash -u`. Mention once that this also tucks away the user's own uncommitted edits. `git stash pop` brings everything back.
  - **Brand-new repo with no commits:** `git stash` fails there ("You do not have the initial commit yet"). Instead say: delete the new files you don't want (they go to the Recycle Bin / Trash).
- **Undo one modified or deleted file:** `git restore --staged --worktree <file>`. Warn that this throws away the changes and they **can't be recovered**.
- **Undo one new file:** delete it in the file explorer (it goes to the Recycle Bin / Trash).
- **Undo a commit** (when explaining a commit): `git revert HEAD`. This is safe: it adds an "opposite" commit, keeps history, and works even after pushing to GitHub.

## Step 5: Animated replay (when `replay` is on)

Keep every shell command in this step **simple**: one command per call, absolute paths, no `&&`, no `$(...)`, no variables. Simple commands are easy for the user to approve.

The replay is a small web page that plays back, step by step, what the agent did: which files it read, created, edited, or deleted, which commands it ran, and what risks came up. It shows the project as **a house**, and a little builder robot hops to the part of the house each step touched, with a speech box explaining it. Risky parts get warning signs (a change to the foundation shows red cracks). Tapping a part lists what changed there. A "Details" tab switches to a timeline view.

**The house parts (`zone`).** Give every step the zone that best fits what the file *does* for the project:

| `zone` | Part of the house | Files that belong here |
|---|---|---|
| `foundation` | Foundation: problems here affect everything | Secrets (`.env`, keys), `.gitignore`, dependency lists (`package.json`, `requirements.txt`, lock files), databases and migrations, auth / login / permissions / security code, deploy and CI (`Dockerfile`, `.github/workflows`) |
| `wiring` | Wiring & pipes | Settings and config (`config.*`, `*.yaml`, `*.toml`, ports, URLs), code that talks to outside services (APIs, servers), build tool config. Every `run` step goes here |
| `structure` | Load-bearing structure | Program logic: scripts, functions, data handling (`*.js`, `*.ts`, `*.py`, … that aren't pages) |
| `rooms` | Rooms (each page gets its own room) | Pages and screens people see (`*.html`, components, templates, views) |
| `decor` | Decor | Looks: styles (`*.css`), images, fonts, icons |
| `yard` | Yard: doesn't change how the house works | Docs and notes (`*.md`, `*.txt`), tests, the AI's own rules (`CLAUDE.md`, `.claude/`) |

If you leave `zone` out, the page guesses from the file name, but your choice is better: you know what the file actually does.

1. **Build the step list.**
   - If this conversation shows the agent's own actions (its tool calls), use those **in the order they happened**: reads, edits, new files, deletions, commands. Set `"source": "session"`. Merge repeated edits to the same file into one step. Leave out the steps of running this skill itself.
   - Otherwise reconstruct the steps from git: one step per changed file, ordered so related files sit together. Set `"source": "git"` (the page then says the order is approximate). Don't invent reads or commands.
   - At most about 25 steps. Merge trivial ones.
2. **The replay folder is `.whatdid/` at the top of the project** (the folder `git rev-parse --show-toplevel` prints). It sits inside the project because many setups only allow writing there, and git ignores it, so it never shows up as a change and never gets uploaded. Each run replaces the previous replay.
   - **`.whatdid/.gitignore` must exist**, containing just one line: `*`. This makes git ignore the whole folder, the `.gitignore` itself included. The reminder hook normally creates it; if it's missing, Write it before anything else.
3. **Write** `.whatdid/data.js` with the Write tool. Use the shape below.
4. **The page itself:** the reminder hook keeps `.whatdid/replay.html` up to date, so usually there's nothing to do. Only if it's missing (Glob `.whatdid/replay.html`), copy this skill's `replay/replay.html` there in one plain copy command with absolute paths (`cp "<from>" "<to>"`; PowerShell `Copy-Item "<from>" "<to>"`). If the copy is blocked, Read the template and Write it to `.whatdid/replay.html` unchanged instead.

`data.js` shape:

```js
window.WHATDID = {
  "title": "<the one-sentence summary>",
  "project": "<project folder name>",
  "source": "session",
  "stats": { "files": 7, "added": 8, "removed": 5 },
  "steps": [
    { "action": "read",   "zone": "rooms",      "target": "index.html",    "note": "Looked at the home page" },
    { "action": "create", "zone": "rooms",      "target": "contact.html",  "note": "New Contact page with a message form", "added": 4, "removed": 0 },
    { "action": "edit",   "zone": "rooms",      "target": "index.html",    "note": "Added a Contact link to the menu", "added": 1, "removed": 1 },
    { "action": "edit",   "zone": "wiring",     "target": "config.json",   "note": "Changed the port 3000 → 8080", "added": 1, "removed": 1, "risk": "medium", "why": "The site now opens at a different address" },
    { "action": "edit",   "zone": "foundation", "target": ".gitignore",    "note": "Took .env off the never-upload list", "added": 0, "removed": 1, "risk": "high", "why": "Your secret key file will be uploaded with everything else" },
    { "action": "delete", "zone": "yard",       "target": "old-promo.txt", "note": "Removed old promo notes", "risk": "high", "why": "You didn't ask for this, and the file is gone" },
    { "action": "run",    "zone": "wiring",     "target": "npm install",   "note": "Installed the add-ons the project needs" }
  ],
  "risks": [
    { "level": "high", "text": "A secret key may get uploaded: .env is no longer ignored" }
  ],
  "check": "Open index.html → click Contact → you should see a form",
  "undo": { "command": "git stash -u", "note": "Changed your mind? git stash pop brings it back" }
};
```

- `zone` is one of `foundation`, `wiring`, `structure`, `rooms`, `decor`, `yard` (see the table above).
- `action` is one of `read`, `create`, `edit`, `delete`, `rename`, `run`. For `rename`, write `target` as `"old → new"`. For `run`, `target` is the command, shortened to about 60 characters.
- **Every step has a risk level, and the page colours everything by it**: green = safe, yellow = caution, red = risky. So be deliberate:
  - `"risk": "high"` (red) for every 🔴 item from the risk checklist, `"risk": "medium"` (yellow) for every 🟡 item. Leave `risk` out for safe steps (green) and for `read` steps (grey, "just looked").
  - The step levels must match the answer's "Watch out" list: each 🔴 / 🟡 bullet there belongs to at least one step marked `high` / `medium`.
  - For every `high` or `medium` step, add `"why"`: one short plain sentence on what could go wrong (about 12 words), e.g. "Your secret key file will be uploaded with everything else". The replay shows it in red.
- `risks` repeats the Watch-out items in short form.
- `undo.command` is the same command as in the answer (for a no-commit repo, set `command` to `""` and put the advice in `note`).
- **Never put secrets in `data.js`** (key values, passwords, tokens). Name the file instead.
- It must be valid JavaScript: escape quotes and backslashes in strings.

5. **Open it** in the default browser (`<folder>` is the absolute path of `.whatdid`):
   - Windows PowerShell: `Start-Process "<folder>\replay.html"` · Git Bash: `start "" "<folder>/replay.html"`
   - macOS: `open "<folder>/replay.html"` · Linux: `xdg-open "<folder>/replay.html"`
6. Add one line at the end of the answer: "▶️ Replay opened in your browser: `<full path to replay.html>`". If opening failed, give the path and say to double-click it.

If the user declines a permission prompt for any of this, or something is blocked even after the fallback, skip the replay and say so in one short line. The text answer is the main result.

Skip the replay when the folder isn't a git repo (there would be nothing to make git ignore `.whatdid/`).

## Rules

- Write in English.
- **Don't paste code.** If you really must, show at most 3 lines and explain them right away.
- **Be honest.** If you're unsure what something does, say so. Don't make things up.
- **Don't exaggerate.** Make real risks clear, but don't make small things sound scary.
- **Never repeat secrets.** If you find a password, key, or token, write "a file contains what looks like a secret key". **Never show the value**, in the answer or in the replay.

## Special cases

- **Not a git repo:** say "This folder doesn't have git version tracking turned on, so I can't compare before and after." If the AI changed files earlier in this conversation, explain those from the conversation and say it may be incomplete. Then offer the one-step fix: "Type **/whatdid setup** and I'll turn it on for you, so next time you can see exactly what changed."
- **No changes and no commits:** say "Nothing has changed yet." Skip the replay.
- **Only binary files changed** (images, PDFs): name them, say whether each was added, replaced, or deleted, and suggest opening them to look.
