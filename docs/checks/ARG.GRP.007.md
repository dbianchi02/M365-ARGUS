# ARG.GRP.007 — Public Microsoft 365 groups

| | |
|---|---|
| Area | GroupsTeams |
| Category | Group governance |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Group.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Groups |
| Uses Graph beta | No |
| Tags | Groups, Teams |

## What is checked

Microsoft 365 (Unified) groups with `visibility` = Public. Anyone in the organisation can join a public group, or its team, and read its conversations, files and site without approval. The Team column shows whether a team is connected.

## Why it matters

Public groups are fine for organisation-wide communities, but projects, departments and customer work usually hold content that should be limited to members. Reviewing them keeps visibility a deliberate choice.

## How to fix

1. Review each public group with its owners and confirm that the content is meant for the whole organisation.
2. Switch the others to Private (members are kept; non-members lose access).
3. Consider sensitivity labels for groups to set privacy by classification.

Portal: <https://admin.microsoft.com/Adminportal/Home#/groups>

```powershell
# Sample only - review before running. Makes one group private.
Connect-MgGraph -Scopes 'Group.ReadWrite.All'
Update-MgGroup -GroupId '<GroupId>' -Visibility 'Private'
```

## References

- [Overview of Microsoft 365 Groups for administrators](https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/office-365-groups)
- [Use sensitivity labels with Microsoft Teams, Microsoft 365 groups, and SharePoint sites](https://learn.microsoft.com/en-us/purview/sensitivity-labels-teams-groups-sites)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
