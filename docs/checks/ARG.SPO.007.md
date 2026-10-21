# ARG.SPO.007 — Sites without a sensitivity label

| | |
|---|---|
| Area | SharePoint |
| Category | Site governance |
| Severity | Low |
| Services | Graph, SharePoint |
| Graph permissions (read-only) | — |
| Directory roles (delegated) | Global Reader, SharePoint Administrator |
| Licences | — |
| Data sets | SharePointSites |
| Uses Graph beta | No |
| Tags | SharePoint, Classification, Inventory |

## What is checked

Site collections (PnP.PowerShell `Get-PnPTenantSite`, OneDrive and system sites excluded) without a sensitivity label (`SensitivityLabel` empty). When no site has a label at all, sensitivity labels are probably not used for sites and groups: the result is To review instead of Failed. Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.

## Why it matters

A container label sets the privacy, external sharing and guest access of a site in one place and tells users and Copilot how sensitive its content is. Once labels are in use, unlabelled sites are the ones that escape those controls and the classification.

## How to fix

1. If labels are not used for sites yet, plan container labels with the compliance team (Microsoft Purview > Information protection).
2. Apply the appropriate label to each listed site (SharePoint admin center > Active sites > site > Settings > Sensitivity), or to its Microsoft 365 group.
3. Consider a default label and requiring a label when sites and groups are created.

Portal: <https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true>

```powershell
# Sample only - review before running.
Connect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'
Set-PnPTenantSite -Identity '<site url>' -SensitivityLabel '<label id>'
```

## References

- [Use sensitivity labels to protect content in Microsoft Teams, Microsoft 365 groups, and SharePoint sites](https://learn.microsoft.com/en-us/purview/sensitivity-labels-teams-groups-sites)
- [Get-SPOSite: SensitivityLabel](https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/get-sposite)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
