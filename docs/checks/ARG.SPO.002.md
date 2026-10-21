# ARG.SPO.002 — Tenant external sharing level

| | |
|---|---|
| Area | SharePoint |
| Category | Sharing |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `SharePointTenantSettings.Read.All` |
| Directory roles (delegated) | Global Reader, SharePoint Administrator |
| Licences | — |
| Data sets | SharePointTenantSettings |
| Uses Graph beta | No |
| Tags | SharePoint, OneDrive, Sharing |

## What is checked

Reads the organisation-level sharing setting for SharePoint and OneDrive (`admin/sharepoint/settings.sharingCapability`). **Anyone** (`externalUserAndGuestSharing`: links that do not require sign-in) is reported as Investigate; New and existing guests, Existing guests only and Only people in your organisation pass. The findings also show the domain restriction mode and whether guests can reshare. Individual sites can only be more restrictive than this setting.

## Why it matters

Anyone links can be forwarded to people outside the organisation without any record of who opened them. Many organisations allow them on purpose for a few sites; the tenant-wide level should be a conscious decision with site-level restrictions where needed.

## How to fix

1. Decide which external sharing level the organisation needs.
2. If Anyone links are required only for some sites, lower the organisation level to New and existing guests and allow Anyone only on those sites, or keep Anyone with link expiration and View-only defaults.
3. Review the domain allow/block list and guest resharing.

Portal: <https://admin.microsoft.com/sharepoint?page=sharing&modern=true>

## References

- [Manage sharing settings for SharePoint and OneDrive](https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off)
- [sharepointSettings resource type](https://learn.microsoft.com/en-us/graph/api/resources/sharepointsettings)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
