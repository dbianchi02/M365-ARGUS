## Summary

<!-- What does this change and why? Link the issue or discussion (Closes #123). -->

## Type of change

- [ ] New check
- [ ] Fix to an existing check
- [ ] Report / output
- [ ] Engine, cmdlets or build
- [ ] Documentation

## Checklist

- [ ] Governance scope only, strictly read-only (no write, update or delete calls).
- [ ] Endpoints and properties verified on Microsoft Learn; Graph v1.0, or beta with `UsesBeta = $true`.
- [ ] For a new check: complete metadata, Pester tests for Passed and Failed, `./build/build.ps1 -Task Docs` and `-Task Sample` run.
- [ ] `./build/build.ps1 -Task Lint` and `-Task Test` pass locally.
- [ ] `CHANGELOG.md` updated under `[Unreleased]`.
- [ ] No real tenant data, tokens or reports in the change.
