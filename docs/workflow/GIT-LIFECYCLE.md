# Git lifecycle — the no-skip checkpoints (gitwalk)

Most git messes in a multi-machine, multi-repo setup come from one thing: a step gets
**skipped**. A sync not run on arrival; a propagation run but never committed; a session
left with a dirty tree the next machine then collides with. This file makes the git steps
**explicit and unskippable** by mapping every point of development to the exact commands.

**gitwalk** is the mode that enforces it. It is **on by default in every OGDK repo**
(bound in `AGENTS.md`). An AI agent working here must walk you through the checkpoints
below, gating on each one.

## The mount reality (why the agent narrates, you run)

A sandboxed/synced-mount agent (Cowork) **cannot run git** — git through the mount can
corrupt the index, and writes land at stale offsets (`docs/workflow/AI-PARITY.md` §4). So
in gitwalk the agent's job is to **print the exact command(s) for the checkpoint, say in one
line why, then STOP and wait for you to paste the output.** You run git in a native shell.
The agent reads your output and either advances or routes you into the matching resolve
sub-flow. "Unskippable" means *the agent will not proceed past a checkpoint until you've run
it and pasted the result* — that refusal is the whole mechanism.

## Execution modes — narrate vs. run-it-yourself

gitwalk runs the same checkpoints two ways, depending on the agent's access:

- **Synced-mount / sandbox agent (cannot run git):** narrate the checkpoint's exact commands,
  wait for the human's pasted output, then advance. (The mount reality, above.)
- **Agent with native git access (can run git):** runs the commands itself, gating on each. For
  SAVE+push it uses `tools/safe-agent-push`, which chains path-health → sync-repo → gate →
  `git add -A` → commit → `git push` (the current branch's upstream) and ABORTS — never forces —
  on any failure or divergence. It carries a mount guard that refuses to run if it detects a
  synced mount, so it can only ever run where git is safe. A panic save still uses `checkpoint`,
  not safe-agent-push. On **any** abort/STOP (divergence, dirty tree, mid-merge, gate-fail, or a
  mount detected) it hands the matching sub-flow back to the human and does **not** auto-resolve —
  full autonomy up to the first stop, then a human.

## The contract (binding — mirrored in AGENTS.md)

1. At each checkpoint, the agent presents the exact commands + one line of why, then **waits
   for your pasted output**. Nothing new — no edits, no next checkpoint — happens until the
   current one clears.
2. **No work crosses a checkpoint with an uncommitted tree.** Finish a concern → SAVE it
   before starting the next, switching repos, or stopping.
3. The agent **never assumes** a command succeeded. It reads your output; any STOP, conflict,
   or non-zero exit routes into a resolve sub-flow (below) before anything else.
4. Default-on in every OGDK repo. To suspend it for throwaway scratch work, say
   **"pause gitwalk"**; resume with **"resume gitwalk"**.

## The checkpoints

Commands show Windows first, Linux in parentheses. "Good" = the result that lets you proceed.

### C0 · ARRIVE — every repo, every session start
```
.\tools\sync-repo.ps1          (./tools/sync-repo.sh)
```
Good: ends **"SAFE TO WORK"** (exit 0). Anything else (STOP, exit 2) → the matching sub-flow
below before you touch a single file. Working across several repos this session? Run the
fleet sweep first (see *Multi-repo arrival*).

### C1 · GROUND — before the first edit
```
git status
git rev-parse --abbrev-ref HEAD          # confirm the intended branch
```
Good: "working tree clean" on the branch you mean to work on. A dirty tree here means a
**previous** session left state — resolve it (S2/S5) before new work; never edit on top of it.

### C2 · SAVE — after each finished concern (one logical change)
```
.\tools\gate.ps1               (./tools/gate.sh)        # exit 0 or no commit
git add -A
git commit -m "type: message"  # types: feat fix docs chore refactor
```
Good: gate exits 0, commit created. Push now or at C5. One concern per commit — don't let
two unrelated changes share a commit.

### C3 · PROPAGATE — whenever kit tools/skills change (the #1 mess-maker)
Do this from **one** machine only, kit committed+pushed first, and **never walk away with a
target's tool files uncommitted**. Per target:
```
cd <target> ; .\tools\sync-repo.ps1                     (cd <target> ; ./tools/sync-repo.sh)
cd <kit>    ; .\tools\propagate-tools.ps1 <target> -Skills   (./tools/propagate-tools.sh <target> --skills)
cd <target> ; .\tools\gate.ps1 ; git add -A ; git commit -m "chore(tools): sync to <kit-hash>" ; git push
```
Good: each target ends clean, committed, and pushed before you move to the next. If a target
won't fast-forward because it has its own uncommitted propagation, that's sub-flow **S5**.

### C4 · HANDOFF — switching repos, or stopping mid-task
```
.\tools\checkpoint.ps1 "what I was doing"      (./tools/checkpoint.sh "what I was doing")
```
Good: a `wip:` commit exists (and pushed if online; a failed push still saved it locally).
Never switch context with a dirty tree.

### C5 · DEPART — session end
```
.\tools\gate.ps1               (./tools/gate.sh)
git add -A ; git commit -m "..." ; git push
# then update docs/STATUS.md (handoff); if interrupted instead, use C4
```
Good: gate green, work pushed, STATUS.md updated for the next session.

### C6 · SWITCH MACHINE — first thing on the other clone, before any work
```
git pull --ff-only             # in every repo you'll touch this session
```
Good: clean fast-forward. If it refuses, you have local state to deal with first (S1–S5).
**Fresh clones on this machine?** `tools/TARGETS.list` is per-machine and gitignored, so a newly
cloned project is invisible to the fleet tooling until you register it. Run it once:
`.\tools\track-projects.ps1` (`./tools/track-projects.sh`) auto-discovers every OGDK project
under the kit's parent dir (a git repo carrying `tools/KIT-VERSION`) and adds the missing ones.
(`new-project` already auto-registers projects on the machine that scaffolds them.)

## Resolve sub-flows (when a checkpoint says STOP)

**S1 — behind only** (remote ahead, tree clean):
```
git pull --ff-only
```

**S2 — dirty + behind** (your own uncommitted work + remote ahead): commit it as its own
change, *then* sync —
```
git add -A ; git commit -m "type: <your work>"     # or .\tools\checkpoint.ps1 "<wip>"
git pull --no-rebase        # merges the remote in (resolve if it conflicts), or --rebase for linear
```

**S3 — diverged** (both sides have commits the other lacks): for **your code**,
`git pull --no-rebase` and resolve. For **propagated `tools/*` files**, the *kit-files rule*:
a conflict there is never a real merge — take either side and re-propagate from the kit
(`git checkout --ours <file>` ; `git add <file>` ; finish ; then re-run propagate from the kit).

**S4 — mid-merge / mid-rebase**:
```
.\tools\rescue.ps1             (./tools/rescue.sh)     # aborts cleanly back to your last commit
# or explicitly: git merge --abort   /   git rebase --abort
```

**S5 — dirty tree is ONLY kit tools/skills** (an uncommitted propagation, with the remote
also ahead — the classic multi-machine collision): set it aside, get current, re-propagate
from the kit (kit wins), then drop the stale copy —
```
git stash push -u -m "stale local propagation"
git pull --ff-only
cd <kit> ; .\tools\propagate-tools.ps1 <this-repo> -Skills
cd <this-repo> ; .\tools\gate.ps1 ; git add -A ; git commit -m "chore(tools): sync to <kit-hash>" ; git push
git stash show -p stash@{0} --stat     # confirm it was ONLY tools/ + .claude/skills/
git stash drop stash@{0}               # only AFTER the fresh propagation is committed + pushed
```

**S6 — leftover stashes** (from past mess-fixing):
```
git stash list
git stash show -p stash@{N} --stat     # inspect before dropping
git stash drop stash@{N}               # drop stale ones once confirmed redundant
```

## Multi-repo arrival (the fleet sweep)

Before a session that touches several repos — especially a propagation session — get the
whole-fleet picture in one read-only command (no changes, just fetch + report):
```
.\tools\fleet-status.ps1       (./tools/fleet-status.sh)
```
It prints branch / ahead / behind / dirty / stash / state / KIT-VERSION for every repo in
your `tools/TARGETS.list` plus the kit. Resolve any non-clean repo (sub-flows above) **before**
propagating, so you never propagate onto a stale or tangled base.

## Why C0 and C3 matter most

The recurring multi-machine git mess is almost always one of two skips: arriving without a
**C0** sync (so you work on a stale base), or running a **C3** propagation and not committing
it before the other machine pushes its own (so the two diverge). Hold those two and the
"hours of git every session" largely disappears.
