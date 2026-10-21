# ARG.SPO.004 — Anyone links expire within 30 days

| | |
|---|---|
| Area | SharePoint |
| Category | Sharing |
| Severity | Medium |
| Services | Graph, SharePoint |
| Graph permissions (read-only) | `SharePointTenantSettings.Read.All` |
| Directory roles (delegated) | Global Reader, SharePoint Administrator |
| Licences | — |
| Data sets | SharePointTenantSettings, SharePointTenant |
| Uses Graph beta | No |
| Tags | SharePoint, OneDrive, Sharing |

## What is checked

When the organisation allows Anyone links (`sharingCapability` = externalUserAndGuestSharing), reads `RequireAnonymousLinksExpireInDays` with PnP.PowerShell (`Get-PnPTenant`). Fails when Anyone links never expire (0 or not set) or expire after more than **30** days. Passes without evaluation when Anyone links are not allowed. Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.

## Why it matters

An Anyone link works for whoever has it, for as long as it exists. An expiration limit bounds how long a forwarded or leaked link stays usable, without forbidding Anyone links where the business needs them.

## How to fix

1. In the SharePoint admin center, go to Policies > Sharing.
2. Under Choose expiration and permissions options for Anyone links, select These links must expire within this many days and enter a value (for example 30).
3. Consider View as the default permission for Anyone links.

Portal: <https://admin.microsoft.com/sharepoint?page=sharing&modern=true>

```powershell
# Sample only - review before running.
Connect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'
Set-PnPTenant -RequireAnonymousLinksExpireInDays 30
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.SPO.004".Parameters`.

| Name | Default |
|---|---|
| `MaxDays` | 30 |

## References

- [Best practices for unauthenticated sharing](https://learn.microsoft.com/en-us/microsoft-365/solutions/best-practices-anonymous-sharing)
- [Set-SPOTenant: RequireAnonymousLinksExpireInDays](https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
