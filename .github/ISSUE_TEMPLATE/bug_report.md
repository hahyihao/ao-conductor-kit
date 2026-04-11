---
name: Bug report
about: Report a problem with scripts, docs, or workflows
title: "[bug] "
labels: ["bug"]
---

## Environment

- Host OS: <Windows 10 21H1 / Windows 11 / other>
- WSL distro + version: <output of `wsl -l -v`>
- Bootstrap stage where it failed: <Phase 1-8 per INSTALL.md>
- Node version: <output of `node --version`>
- pnpm version: <output of `pnpm --version`>
- Codex CLI version: <output of `codex --version`>
- AO version: <output of `ao --version`>
- Commit SHA of this kit: <output of `git rev-parse HEAD`>

## What happened

<!-- One paragraph describing what you expected vs what you got. -->

## Reproduction steps

1.
2.
3.

## Exact error output

```
<paste the full error, not a summary>
```

## Related files / logs

<!-- Point to any relevant log files, tmux session names, ao session ids, or PR numbers. -->

## Have you checked TROUBLESHOOTING.md?

- [ ] Yes, and my issue is not listed there
- [ ] Yes, but the listed fix did not work for my environment
- [ ] No (please check it first)
