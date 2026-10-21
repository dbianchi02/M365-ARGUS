# ARG.GRP.004 — Microsoft 365 groups and Teams without owners

| | |
|---|---|
| Area | GroupsTeams |
| Category | Ownership |
| Severity | High |
| Services | Graph |
| Graph permissions (read-only) | `Group.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Groups |
| Uses Graph beta | No |
| Tags | Groups, Teams, Ownership |

## What is checked

Microsoft 365 (Unified) groups, including the ones connected to Teams, with no owner.

## Why it matters

Nobody manages membership, guests or content of an ownerless group, nobody receives its expiration notices, and nobody can approve access requests. Microsoft recommends at least two owners per group.

## How to fix

1. Identify a responsible person for each group (for example among the most active members).
2. Add at least two owners.
3. Archive or delete groups that are no longer needed.
4. Consider the Microsoft 365 ownerless group policy, which asks active members to become owners.

Portal: <https://admin.microsoft.com/Adminportal/Home#/groups>

```powershell
# Sample only - review before running. Adds an owner to one group.
Connect-MgGraph -Scopes 'Group.ReadWrite.All'
New-MgGroupOwnerByRef -GroupId '<GroupId>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/users/<UserId>' }
```

## References

- [Manage ownerless Microsoft 365 groups and teams](https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/ownerless-groups-teams)
- [Add or remove members from Microsoft 365 groups using the admin center](https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/add-or-remove-members-from-groups)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
