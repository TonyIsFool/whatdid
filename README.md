<div align="center">
<h1>whatdid</h1>
<p><strong>Know what the AI changed before you click Accept.</strong></p>
<p>A Claude Code plugin that explains an agent's changes in plain words, for people who don't read code.</p>
<p>
  <img src="https://img.shields.io/badge/Claude_Code-plugin-D97757?style=flat-square" alt="Claude Code plugin">
  <img src="https://img.shields.io/badge/version-2.2.0-167D68?style=flat-square" alt="Version 2.2.0">
  <img src="https://img.shields.io/badge/risk_scan-AI_tokens_0-167D68?style=flat-square" alt="The risk scan and reminder consume 0 AI model tokens">
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/license-PolyForm_Strict_1.0.0-555555?style=flat-square" alt="PolyForm Strict 1.0.0 license"></a>
</p>
<p><a href="#install"><img src="https://img.shields.io/badge/Install-Claude_Code_plugin-0969DA?style=for-the-badge" alt="Install the Claude Code plugin"></a></p>
<p><a href="#quick-start">Quick Start</a> | <a href="#the-replay">Replay</a> | <a href="#example">Example</a> | <a href="#how-it-works">How It Works</a> | <a href="#license">License</a></p>
</div>

**AI edits your project -> fixed-rule risk scan -> plain-words explanation -> animated replay.**

After an AI agent edits a project, you get a wall of red and green diff. If you can't
read it, all you can do is click **Accept** and hope. Type `/whatdid` and get a short,
plain answer instead:

| Question | What whatdid answers |
| --- | --- |
| **What changed?** | Grouped by what was done, not file by file |
| **What's risky?** | Leaked secrets, deleted files, database and deploy changes, new add-ons, things you didn't ask for, marked 🔴 / 🟡 |
| **How do I check it?** | Where to click and what you should see |
| **How do I undo it?** | One copy-paste command, and whether you can get your work back |

whatdid **never changes your project**: no edits, no commits, and it never runs an
undo command for you. The risk scan and the reminder are small local scripts that use
**0 model calls and 0 AI tokens**. Only the explanation itself is written by Claude.

## Quick Start

**Install, make a change, ask.**

```
/plugin marketplace add TonyIsFool/whatdid
/plugin install whatdid@whatdid
```

Start a new session, ask the AI for a change, then type:

```
/whatdid
```

After any turn that changed files, a one-line hint appears, with the risk count already filled in:

> 💡 4 files changed, 🔴 1 risky thing found. Type /whatdid to see what the AI changed, in plain words.

**No git in your folder yet?** whatdid compares before and after with git. Type
`/whatdid setup` once: it turns git on and saves a starting snapshot, keeping secret
files such as `.env` out of it. Nothing is uploaded.

## The Replay

**Your project as a house. Colour only ever means risk.**

`/whatdid` also opens a replay of the agent's work in your browser. A small builder
robot walks to whichever part of the house each step touched:

| Part of the house | What it stands for |
| --- | --- |
| 🧱 Foundation | Secrets, add-ons, data, security. Trouble here affects everything, so it cracks red |
| ⚡ Wiring | Settings and connections to outside websites |
| 🏛️ Structure | The logic behind the walls |
| 🚪 Rooms | Pages people see (each page is a room) |
| 🎨 Decor | Colours, fonts, pictures |
| 🌳 Yard | Docs, notes, tests: doesn't change how the project works |

Every step is 🟢 **Safe**, 🟡 **Caution** or 🔴 **Risky**, and the house lights up in that
colour. On a risky step the screen flashes red, a **RISKY** stamp lands and the speech
box says *why*. A colour strip shows every step at a glance (click one to jump to it),
and a **Details** tab gives a plain timeline. The page is a single offline HTML file.
A ready-made demo is in [examples/replay-demo/](examples/replay-demo/): download the
folder and open `replay.html`.

## Example

Real, unedited output on a demo repo where the agent was asked to add a Contact page:

```
**In short:** A Contact page was added to the Ming's Coffee site, but three other changes
came with it, and two of them need your attention before you save or upload anything.

**What changed**
- 🆕 Created `contact.html`: a Contact page with a name box, a message box and a Send button.
- ✏️ Edited `style.css`: the text is a little bigger (size 14 → 16).
- ✏️ Edited `config.json`: the site's port changed from 3000 to 8080.
- 🆕 Created `.env`: a file that holds what looks like a secret key.
- 🗑️ Deleted `old-promo.txt`: the old notes about the spring promo.

**⚠️ Watch out**
- 🔴 Your secret key could get uploaded. `.env` was taken off `.gitignore` …
- 🔴 A file was deleted: `old-promo.txt` is gone …
- 🟡 The site's address changed: it now opens at :8080 instead of :3000 …
- 🟡 The Contact form contacts an outside service every time the page opens …

**✅ Check it:** Open `index.html` and click Contact. You should see the form.

**↩️ Undo everything:** `git stash -u` (`git stash pop` brings it all back).
```

Full output: [examples/coffee-shop-demo.md](examples/coffee-shop-demo.md).

## Install

**Claude Code, with git available.** No API key or extra service is required.

Type these in Claude Code, one at a time:

```
/plugin marketplace add TonyIsFool/whatdid
```

```
/plugin install whatdid@whatdid
```

Then start a new session.

<details>
<summary>One-line install (Claude Code 2.1.275 or later)</summary>

```
/plugin install whatdid --marketplace TonyIsFool/whatdid
```

</details>

<details>
<summary>Updating</summary>

```
claude plugin marketplace update whatdid
claude plugin update whatdid@whatdid
```

Then restart Claude Code. Your settings are kept.

</details>

## Usage

| Command | Does |
| --- | --- |
| `/whatdid` | Explain the uncommitted changes |
| `/whatdid full` | More detail, a short glossary and per-file undo |
| `/whatdid no-replay` | Skip the replay |
| `/whatdid last commit` / `last 3 commits` | Explain recent commits |
| `/whatdid index.html` | Only this file |
| `/whatdid setup` | Turn on git in a folder that doesn't have it |

Options combine, for example `/whatdid full last commit`. In the command menu the skill
may appear as `/whatdid:whatdid`.

### Settings

Change a setting by typing it: `/whatdid set detail full`. See all of them with `/whatdid settings`.

| Setting | Values | Default |
| --- | --- | --- |
| `detail` | `brief` (about 12 lines) or `full` | `brief` |
| `replay` | `on` / `off` | `on` |
| `after_changes` | `remind` (one-line hint), `explain` (explain automatically; uses more of your usage), `off` | `remind` |

Settings are saved in `~/.claude/whatdid.json` and survive updates. Explanations are in English.

## How It Works

**Fixed rules find the risks. Claude explains them.**

| Part | Runs | What it does |
| --- | --- | --- |
| `hooks/remind.sh` | After every agent turn | Runs the risk scan and shows the hint |
| `skills/whatdid/risk-scan.sh` | From the hook or the skill | Fixed rules for risky changes, in one pass |
| `skills/whatdid/SKILL.md` | When you type `/whatdid` | Reads the git changes and the scan, writes the explanation and replay data |
| `skills/whatdid/replay/replay.html` | In your browser | Draws the replay, offline |

**The scan is the floor, not the ceiling.** Anything the scan marks high-risk is always
shown in red; Claude can add risks on top but cannot remove them. The scan looks for:

- Secret keys and passwords in changed or new files (the value is never printed)
- Secret files that would be uploaded, including `.env` removed from `.gitignore`
- Deleted files and large removals
- Dangerous commands, database and migration changes, deploy and CI changes
- New or changed add-ons (dependency lists), outside websites, settings, login and security code

**What gets written:** only a hidden `.whatdid/` folder in your project, which ignores
itself in git. Delete it at any time.

<details>
<summary>Limits</summary>

- whatdid needs git to see changes. Without it, the hint suggests `/whatdid setup` once per folder.
- When changes come from git, the replay order is rebuilt from the file changes and is approximate.
- The risk scan uses English keyword rules. It can miss risks and can flag harmless changes; it is an aid, not a security audit.
- Tested on Windows. macOS and Linux are expected to work but have not been verified.

</details>

## License

**Free for personal and noncommercial use.** whatdid is released under the
[PolyForm Strict License 1.0.0](LICENSE.md):

| You may | You may not |
| --- | --- |
| Install and use whatdid for personal, educational and other noncommercial purposes | Use it for commercial purposes |
| Use it in charitable, educational, research and government organisations | Modify it or build new works based on it |
| | Redistribute or republish it, changed or unchanged |

For commercial use or any other permission, please get in touch.

## Contact

**Tony Lu** | [xulunt123@gmail.com](mailto:xulunt123@gmail.com)

Copyright © 2026 Tony Lu. All rights not granted by the license are reserved.
