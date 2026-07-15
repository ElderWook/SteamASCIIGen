# SteamASCIIGen — Agent Rules

> **App-track OGDK project** (Svelte 5 + Vite + Tailwind). Turns images into Steam-showcase
> Unicode ASCII art. Currently a **dormant scaffold** — no active plan yet. Seeded from OGDK
> `kitVersion v0.2.0-beta`.

> **Session chain:** this file → `docs/STATUS.md` → active plan. The docs chain isn't built yet;
> when you resume real work, scaffold `docs/00-START-HERE.md` + `docs/STATUS.md` from the OGDK
> app-track template first.

## ⚠️ Launch environment
Native filesystem + local git only. Never launch an AI agent from MSYS2 / Git Bash / WSL (NTFS
write corruption). On a synced mount: file tools only, the human runs git.

## Architecture (app track — see OGDK/app/STACK.md §Invariants)
- Stack is fixed: **Vite + Svelte 5 + Tailwind** (see `ogdk.json`). Don't swap frameworks.
- <!-- FILL IN: the 3–6 structural rules once real work resumes. -->

## Invariants
- <!-- FILL IN: ASCII output must be deterministic for a given image + settings — pin the
     character ramp and sizing rules so a showcase render is reproducible. -->

## Verification gate (run before every commit)
- `npm run build` must succeed. Wire `./tools/gate.sh` (integrity → references → build) when the
  OGDK app gate is added.

## Process
- Plans before implementation (`docs/plans/`). Update docs in the same commit as code.
- One concern per commit. Never commit secrets.
