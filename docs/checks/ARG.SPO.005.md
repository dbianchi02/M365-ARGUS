# ARG.SPO.005 — Guest access to sites and files expires

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
| Tags | SharePoint, OneDrive, Sharing, Guests |

## What is checked

Reads `ExternalUserExpirationRequired` and `ExternalUserExpireInDays` with PnP.PowerShell (`Get-PnPTenant`): whether guests lose access to sites and files after a number of days unless a site owner renews it. Fails when the policy is off. Passes without evaluation when external sharing is disabled (`sharingCapability` = disabled). Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.

## Why it matters

Guests invited for a project keep access long after it ends. An expiration policy makes site owners confirm, periodically, who still needs access; it complements guest reviews in Entra ID (ARG.ENT.005).

## How to fix

1. In the SharePoint admin center, go to Policies > Sharing > More external sharing settings.
2. Select Guest access to a site or OneDrive will expire automatically after this many days and enter a value (for example 90).
3. Tell site owners that they will be asked to extend access for guests who still need it.

Portal: <https://admin.microsoft.com/sharepoint?page=sharing&modern=true>

```powershell
# Sample only - review before running.
Connect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'
Set-PnPTenant -ExternalUserExpirationRequired $true -ExternalUserExpireInDays 90
```

## References

- [Manage guest access expiration for sites and files](https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off#change-the-organization-level-external-sharing-setting)
- [Set-SPOTenant: ExternalUserExpirationRequired](https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
