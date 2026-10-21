# ARG.SPO.003 — Default sharing link is limited to specific people

| | |
|---|---|
| Area | SharePoint |
| Category | Sharing |
| Severity | Medium |
| Services | Graph, SharePoint |
| Graph permissions (read-only) | — |
| Directory roles (delegated) | Global Reader, SharePoint Administrator |
| Licences | — |
| Data sets | SharePointTenant |
| Uses Graph beta | No |
| Tags | SharePoint, OneDrive, Sharing, Oversharing |

## What is checked

Reads the default link type of the sharing dialog with PnP.PowerShell (`Get-PnPTenant`): `CoreDefaultShareLinkScope` for SharePoint and `OneDriveDefaultShareLinkScope` for OneDrive, falling back to `DefaultSharingLinkType` when they are Uninitialized. Anyone as default fails; People in your organisation (or the widest allowed link) is Investigate; Specific people passes. Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.

## Why it matters

Most people accept the default link. A default of Anyone or of the whole organisation turns every quick share into broad access, which is the main source of oversharing that Copilot later surfaces in answers. Specific people as default keeps sharing intentional.

## How to fix

1. In the SharePoint admin center, go to Policies > Sharing > File and folder links.
2. Set the default link type to Specific people (only the people the user specifies).
3. Set the default permission to View where editing is not the usual need.

Portal: <https://admin.microsoft.com/sharepoint?page=sharing&modern=true>

```powershell
# Sample only - review before running.
Connect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'
Set-PnPTenant -DefaultSharingLinkType Direct
```

## References

- [Change the default link type for SharePoint and OneDrive](https://learn.microsoft.com/en-us/sharepoint/change-default-sharing-link)
- [Set-SPOTenant: DefaultSharingLinkType and CoreDefaultShareLinkScope](https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
