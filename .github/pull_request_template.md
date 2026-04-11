<!-- Thanks for contributing to the AO Conductor Kit. Please fill in every section before requesting review. -->

## Summary

<!-- 1-3 sentences describing what this PR changes and why. -->

## Type of change

- [ ] Documentation (INSTALL.md / FLOW.md / TROUBLESHOOTING.md / README.md / CLAUDE.md)
- [ ] Script (scripts/* or tools/*)
- [ ] Template (templates/*)
- [ ] Skill (skills/*)
- [ ] CI / workflow (.github/workflows/*)
- [ ] Brief (briefs/*)
- [ ] Other (explain)

## Which brief did this originate from?

<!-- If this PR was produced via `ao batch-spawn`, reference the brief filename under briefs/. If this is a human-authored change, write "human". -->

## Checklist

- [ ] I updated `CHANGELOG.md` under the relevant unreleased section (or confirmed no user-visible change).
- [ ] I updated `VERSION` if this PR is part of a release.
- [ ] I did not commit any real API keys, tokens, passwords, or production endpoints.
- [ ] I ran `gitleaks detect` locally (or trust the CI to catch leaks).
- [ ] I ran the relevant linters locally (super-linter, shellcheck, PSScriptAnalyzer) if I touched scripts.
- [ ] I added or updated tests where applicable.
- [ ] I verified the change against the CEO → PM → Worker doctrine in `FLOW.md`.

## How this was tested

<!-- Commands run, expected outputs, environment used. If dispatched via AO, include the `ao status` summary and PR number. -->

## Follow-up work

<!-- Anything intentionally left out of this PR. -->
