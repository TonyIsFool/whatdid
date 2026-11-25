# Risk checklist

Check the changes against this list. Every hit goes in "Watch out" with **what the problem is, why it matters, and what the user can do**. Merge hits of the same kind into one line. The "How to say it" column is only a guide: rephrase it in the chosen language and keep it short.

## 🔴 High: always flag, suggest confirming before accepting

| Check for | How to spot it | How to say it |
|---|---|---|
| **Deleted files** | `D` in `git status` | "Deleted N files: …. If you still need them, don't accept yet." |
| **Big removals** | A file loses far more lines than it gains (e.g. 100+ removed) | "A big chunk (about N lines) was removed from `file`. Make sure you meant that." |
| **Secrets in files** | Names: `.env`, `*.pem`, `*.key`, `id_rsa`, `credentials*`, `secrets*`. Content: `api_key`, `secret`, `password`, `token`, or long strings starting with `sk-`, `ghp_`, `AKIA` | "`file` contains what looks like a secret key. If it's uploaded to GitHub, anyone can see it." (**never show the value**) |
| **Secrets no longer ignored** | `.gitignore` loses rules like `.env` or `*.key` | "Files that were set to never upload may now get uploaded." |
| **Data deleted or changed** | `DROP`, `DELETE FROM`, `TRUNCATE`; migrations (`migrations/`); `*.db`, `*.sqlite` changed | "This changes or deletes data in the database. Deleted data may be gone for good." |
| **Dangerous commands** | Scripts with `rm -rf`, `Remove-Item -Recurse`, `del /s`, `format`, `curl … \| sh`, `chmod 777` | "A script contains a command that mass-deletes files (or downloads and runs a program)." |
| **Auto-deploy settings** | `.github/workflows/`, `Dockerfile`, deploy scripts, `vercel.json`, `netlify.toml` | "Changed how the site goes live automatically. The next upload may behave differently." |
| **Login, permissions, security** | Code around `auth`, `login`, `permission`, `cors`, `csrf`, encryption | "Touched login or security code. Mistakes here can let people see things they shouldn't." |

## 🟡 Medium: mention it so the user knows

| Check for | How to spot it | How to say it |
|---|---|---|
| **New add-ons (dependencies)** | New or changed entries in `package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `composer.json` | "Added N ready-made add-ons: …. You may need to run `install command` first." |
| **Settings changed** | `config.*`, `settings.*`, `*.yaml`, `*.toml`, `.env.example`, ports, URLs, on/off switches | "Changed a setting: X from A to B, which means …" |
| **The AI's own rules changed** | `CLAUDE.md`, `.claude/`, `AGENTS.md`, hook settings | "Changed the AI assistant's rules. It may behave differently from now on." |
| **Talks to outside websites** | New URLs, or `fetch`, `requests`, `axios`, `http` calls | "Now connects to `domain`." |
| **Large change** | More than 10 files or 500 lines | "This is a big change, so check a few different features." |
| **Not what you asked for** | Compare with the user's request in the conversation | "You didn't ask for this: …. You can undo just this part." |
| **Can't see inside** | Images, PDFs, archives, `.exe` and other binary files | "`file` is an image (or other file) I can't look inside. Open it to check." |
| **Renamed or moved** | `R` in `git status` | "Renamed `old` to `new`. Anything still using the old name may break." |

## 🟢 Low: usually nothing to worry about (don't list these under "Watch out")

Docs and text (`*.md`, `*.txt`) · comments (notes in the code that don't affect how it runs) · styling (`*.css`: colors, fonts, spacing) · tests (`test`, `spec`) · formatting only (spaces, line breaks) · auto-generated lock files (`package-lock.json`, `yarn.lock`, `poetry.lock`)

If everything is low risk, write "🟢 Nothing risky found."
