# Reference — the SDK documentation tier

This folder is the **finished-product documentation**: one polished page per shipped
component or feature, written for someone who has never seen the session chain and
never will. Think official SDK docs — if a stranger (or a future you, or a model with
zero context) needs to *use* something this project built, the answer lives here.

## How it differs from the other tiers

| Tier | Audience | Question it answers | Freshness |
|------|----------|---------------------|-----------|
| `STATUS.md` / plans | working sessions | "what's in flight, what was decided?" | live |
| `core/` specs | architects/maintainers | "how is it built and why?" | per change |
| **`reference/`** | **consumers of the work** | **"how do I use it?"** | per shipped feature |

## The graduation rule (non-negotiable)

**A plan is not COMPLETE until its reference pages exist.** When a plan graduates
(content → `core/`, file → `plans/archive/`), the same commit creates or updates the
reference page for every component the plan shipped. The plan-writer skill requires a
"Documentation impact" section naming those pages up front, so nothing is discovered
missing at the end. No reference page, no archive — the plan stays open.

## The coverage manifest (how plans discover existing pages)

`COVERAGE.md` maps every shipped component's source paths to its page. Plans MUST
check the manifest in their §Documentation impact step: touch a mapped path → its
page is an UPDATE entry; ship a new component → new row + new page, same commit.
`tools/check-reference-coverage.{ps1,sh}` verifies pages exist and flags STALE ones
(source committed after its page) — run at session end.

## Writing a page

Scaffold with `tools/new-reference-page.{ps1,sh}` (creates the page from
`COMPONENT-TEMPLATE.md` AND its COVERAGE.md row in one command), or copy the template
by hand — kebab-case name, fill every section, delete none. Keep it self-contained:
a reader should succeed without opening any other doc.

**There is no separate index — `COVERAGE.md` IS the index.** One manifest, machine-
checked; a second hand-maintained list would only drift.
