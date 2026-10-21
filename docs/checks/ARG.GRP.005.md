# ARG.GRP.005 — Microsoft 365 groups and Teams with a single owner

| | |
|---|---|
| Area | GroupsTeams |
| Category | Ownership |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `Group.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Groups (optional: Users) |
| Uses Graph beta | No |
| Tags | Groups, Teams, Ownership |

## What is checked

Microsoft 365 (Unified) groups, including Teams, with exactly one owner. The Owner column shows who it is and OwnerEnabled whether that account is still enabled; groups whose only owner is disabled are listed first.

## Why it matters

A single owner is a single point of failure: when that person leaves or changes role the group becomes ownerless. Microsoft recommends at least two owners.

## How to fix

1. Ask each owner to add a second owner (a colleague or a team lead).
2. Start with the groups whose only owner is disabled.
3. Make two owners a requirement of your group request process.

Portal: <https://admin.microsoft.com/Adminportal/Home#/groups>

## References

- [Add or remove members from Microsoft 365 groups using the admin center](https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/add-or-remove-members-from-groups)
- [Manage ownerless Microsoft 365 groups and teams](https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/ownerless-groups-teams)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
