# Reference coverage manifest

> The lookup table that makes the graduation rule mechanical. **Every shipped
> component has a row.** Plans consult this table in §7: if a plan touches a source
> path listed here, the mapped page goes in the plan as UPDATE — no exceptions.
> New components add a row in the same commit that creates their page.
> Checked by `tools/check-reference-coverage.{ps1,sh}` (exists + staleness vs git history).

## Status values

`current` — page exists and reflects the component ·
`stale` — source changed after the page (fix before next plan archives) ·
`missing` — shipped component with NO page yet (backlog; named in STATUS.md §Next up) ·
`planned` — component not yet built; row reserves the mapping

## Manifest

| Component | Source path(s) | Page | Status |
|-----------|----------------|------|--------|
| _none yet_ | - | - | - |
