# ARG.SPO.008 — Orphaned SharePoint sites

| | |
|---|---|
| Area | SharePoint |
| Category | Ownership |
| Severity | High |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `Group.Read.All`, `Sites.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader, SharePoint Administrator |
| Licences | — |
| Data sets | Groups (optional: SharePointSites, Users) |
| Uses Graph beta | No |
| Tags | SharePoint, Ownership |

## What is checked

Group-connected sites whose Microsoft 365 group has no owner (site URL read with JSON batching, `GET /groups/<id>/sites/root`). When SharePoint is connected through PnP.PowerShell, sites without a Microsoft 365 group (classic team sites, communication sites) are also evaluated: a site is orphaned when its primary site collection administrator (`Owner` in `Get-PnPTenantSite`) is empty, disabled or no longer exists. Without PnP those sites are not evaluated and the summary says so.

## Why it matters

Nobody manages permissions, sharing or content of a site without a responsible owner, and access requests go unanswered. Orphaned sites are also the hardest to clean up later.

## How to fix

1. For group-connected sites, add owners to the Microsoft 365 group (see ARG.GRP.004).
2. For other sites, set a new primary site collection administrator in the SharePoint admin center (Active sites > Permissions).
3. Delete or archive sites that are no longer needed.

Portal: <https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true>

```powershell
# Sample only - review before running. Sets the primary administrator of a site without a group.
Connect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<ClientId>'
Set-PnPTenantSite -Identity '<SiteUrl>' -Owners @('<UserPrincipalName>')
```

## References

- [Manage site admins in the SharePoint admin center](https://learn.microsoft.com/en-us/sharepoint/manage-site-collection-administrators)
- [Manage ownerless Microsoft 365 groups and teams](https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/ownerless-groups-teams)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
