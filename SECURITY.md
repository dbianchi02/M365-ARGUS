# Security policy

ARGUS is a read-only assessment tool: it never writes to a Microsoft 365 tenant. A vulnerability in ARGUS
would typically be a way to make it write or delete data, leak tokens or tenant data, or run script through
the HTML report (for example through a crafted display name or site title).

## Supported versions

Only the latest version published on the [PowerShell Gallery](https://www.powershellgallery.com/packages/ARGUS)
receives fixes. Update with `Update-Module ARGUS` before reporting.

## Reporting a vulnerability

**Do not open a public issue or discussion.** Report it privately through
[GitHub private vulnerability reporting](https://github.com/dbianchi02/M365-ARGUS/security/advisories/new).

Please include:

- the ARGUS version (`(Get-Module ARGUS).Version` and the prerelease tag) and PowerShell version;
- the steps to reproduce, with fictitious data only;
- the impact you expect.

Never attach real tenant data, access tokens, or reports from a real tenant.

You will get an acknowledgement within a few days. Once a fix is published, the advisory is disclosed with
credit to the reporter, unless you prefer to stay anonymous.

## Out of scope

- Findings about the security posture of your own tenant: ARGUS is a governance tool and reports them by design.
- Vulnerabilities in Microsoft modules ARGUS uses (`Microsoft.Graph.Authentication`, `ExchangeOnlineManagement`,
  `PnP.PowerShell`, `MSCommerce`): report them to their maintainers.
