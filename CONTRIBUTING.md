# Contributing to ARGUS

Thanks for your interest in ARGUS. Please read [docs/ARGUS-SPEC.md](docs/ARGUS-SPEC.md) before any non-trivial change.

## Ground rules

- **Governance only.** ARGUS is not a security baseline: CIS / CISA / MFA / Conditional Access / Defender-style checks are out of scope.
- **Read-only.** Never call a Graph / Exchange / PnP endpoint or cmdlet that writes, updates or deletes. Remediation is text and sample code in the report.
- **PowerShell 7.2+**, cross-platform (Windows, macOS, Linux).
- Graph access only through `Microsoft.Graph.Authentication` and the private helper `Invoke-ArgusGraphRequest`. Prefer v1.0; mark checks using beta with `UsesBeta = $true`.
- Verify every endpoint and property on Microsoft Learn (permissions, licence requirements, `$select`) before using it.
- Never commit real tenant data, tokens or reports from real tenants.

## Development setup

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser

./build/build.ps1 -Task Lint, Test
```

## Coding rules

- Approved verbs only; public cmdlets are prefixed `Argus`, one function per file (`Public/`, `Private/`).
- Full comment-based help on every public function.
- PSScriptAnalyzer must be clean (`PSScriptAnalyzerSettings.psd1`).
- No `Write-Host` (except the optional console banner/summary); use `Write-Verbose`, `Write-Progress`, `Write-Warning`, `Write-Information`.
- Thresholds live in configuration, never hardcoded in check code. No hardcoded tenant IDs, UPNs or secrets.
- Tenant strings rendered in HTML must be escaped (`textContent`, never `innerHTML`).

## Adding a check

Each check lives in `ARGUS/Checks/<Area>/ARG.<AREA>.<NNN>.ps1` and needs:

1. complete metadata (spec §4);
2. a Pester test with mocked data for Passed and Failed (and Skipped where prerequisites apply);
3. an entry in the generated docs (`./build/build.ps1 -Task Docs`);
4. an appearance in `samples/sample-report.html` (`./build/build.ps1 -Task Sample`).

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/), one logical change per commit, for example:

```
feat(checks): add ARG.ENT.004 inactive guests
fix(report): escape site titles in findings table
```
