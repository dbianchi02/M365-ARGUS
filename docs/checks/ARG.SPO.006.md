# ARG.SPO.006 — Sites that allow Anyone links

| | |
|---|---|
| Area | SharePoint |
| Category | Sharing |
| Severity | Low |
| Services | Graph, SharePoint |
| Graph permissions (read-only) | `SharePointTenantSettings.Read.All` |
| Directory roles (delegated) | Global Reader, SharePoint Administrator |
| Licences | — |
| Data sets | SharePointTenantSettings, SharePointSites |
| Uses Graph beta | No |
| Tags | SharePoint, Sharing, Inventory |

## What is checked

Site collections (PnP.PowerShell `Get-PnPTenantSite`, OneDrive excluded) whose own sharing setting is `ExternalUserAndGuestSharing` (Anyone). Listed as Investigate: Anyone links may be intended on some sites, but each one should be known. Passes without evaluation when the organisation does not allow Anyone links. Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.

## Why it matters

The organisation level sets the maximum; each site inherits it unless an administrator restricts it. Knowing which sites can create Anyone links lets you keep that capability only where it has a business owner and a reason.

## How to fix

1. Review the listed sites with their owners.
2. For sites that do not need Anyone links, lower the site sharing to New and existing guests (SharePoint admin center > Active sites > Sharing).
3. For sites that keep it, check ARG.SPO.004 (link expiration).

Portal: <https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true>

```powershell
# Sample only - review before running.
Connect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'
Set-PnPTenantSite -Identity '<site url>' -SharingCapability ExternalUserSharingOnly
```

## References

- [Change the sharing settings for a site](https://learn.microsoft.com/en-us/sharepoint/change-external-sharing-site)
- [Best practices for unauthenticated sharing](https://learn.microsoft.com/en-us/microsoft-365/solutions/best-practices-anonymous-sharing)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
