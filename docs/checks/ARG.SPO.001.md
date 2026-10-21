# ARG.SPO.001 — SharePoint site creation is restricted

| | |
|---|---|
| Area | SharePoint |
| Category | Site governance |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `SharePointTenantSettings.Read.All` |
| Directory roles (delegated) | Global Reader, SharePoint Administrator |
| Licences | — |
| Data sets | SharePointTenantSettings |
| Uses Graph beta | No |
| Tags | SharePoint, Policy |

## What is checked

Reads `admin/sharepoint/settings.isSiteCreationEnabled` ("Users can create SharePoint sites" in the SharePoint admin center) and `isSiteCreationUIEnabled`. When users can create sites, communication sites and team sites without a group can be created by anyone, even if Microsoft 365 group creation is restricted (ARG.GRP.001): Investigate, as it is a valid choice for some organisations.

## Why it matters

Self-service sites multiply quickly, often without a clear owner, classification or lifecycle. Restricting creation, or routing it through a request process with a template, keeps the site estate governable and the Copilot index clean.

## How to fix

1. Decide whether site creation is open or goes through a request process.
2. To restrict it, in the SharePoint admin center go to Settings > Site creation and turn off Users can create SharePoint sites.
3. Keep ARG.GRP.001 aligned: group-connected sites are governed by the Microsoft 365 group creation policy.

Portal: <https://admin.microsoft.com/sharepoint?page=settings&modern=true>

## References

- [Manage site creation in SharePoint](https://learn.microsoft.com/en-us/sharepoint/manage-site-creation)
- [sharepointSettings resource type](https://learn.microsoft.com/en-us/graph/api/resources/sharepointsettings)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
