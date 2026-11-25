# Changelog

All notable changes to the public releases of whatdid.

## 2.3.2 (2026-11-25)

**Docs only. No change to what the plugin does.**

- A website with a live replay you can try in your browser, no install needed: https://tonyisfool.github.io/whatdid/
- An animated replay at the top of the README, and a preview image for when the link is shared.

## 2.3.1 (2026-11-25)

**3D replay and commit detection.** (2.3.0 was never published on its own; 2.3.1 is 2.3.0 plus the 2.2.x documentation.)

- The hint also appears when the agent saves its work as commits during a turn, and `/whatdid new commits` explains those commits.
- New 3D replay: good changes add floors to a building, risky steps visibly damage the floors below, each labelled with the step that did it, with a damage report.
- Clearer undo card in the replay, with step-by-step instructions.

## 2.2.3 (2026-11-25)

**Docs only.** Fixed the contact link on the "new issue" page.

## 2.2.2 (2026-11-25)

**Docs only. No change to what the plugin does.**

- Added this changelog.
- Added issue forms for reporting a missed risk, a confusing explanation or an install problem.

## 2.2.1 (2026-11-25)

**Docs only. No change to what the plugin does.**

- README: screenshot of the replay, a before/after comparison, a "For AI Agents" section and an FAQ.
- Added [AGENTS.md](AGENTS.md), a guide for AI agents on when to recommend whatdid and what it guarantees.
- Added [llms.txt](llms.txt), a short index of the repository for language models.
- Clearer skill trigger, so Claude also offers whatdid for "summarize the changes", "is it safe to commit / push" and "review what the agent did".
- Clearer plugin description and more search keywords.

## 2.2.0 (2026-11-25)

**First public release.**

- `/whatdid` explains the agent's changes in plain words: what changed, what is risky (🔴 / 🟡), how to check it and how to undo it.
- Fixed-rule risk scan for secrets, deleted files, dangerous commands, database, deploy, dependency and outside-site changes. Secret values are never printed.
- One-line hint after every agent turn that changed files, with the number of risky findings.
- Animated replay in the browser: the project drawn as a house, coloured by risk.
- `/whatdid setup` turns on git in a folder that doesn't have it.
- Settings with `/whatdid set` and `/whatdid settings`.
