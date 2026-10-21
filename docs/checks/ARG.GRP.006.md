# ARG.GRP.006 — Teams with guests and no owner

| | |
|---|---|
| Area | GroupsTeams |
| Category | Ownership |
| Severity | High |
| Services | Graph |
| Graph permissions (read-only) | `Group.Read.All`, `GroupMember.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Groups |
| Uses Graph beta | No |
| Tags | Teams, Guests, Ownership |

## What is checked

Teams (Microsoft 365 groups with a team) that have no owner and at least one guest member. Members of the ownerless Teams are read with JSON batching (`GET /groups/<id>/members/microsoft.graph.user`, first 999 members).

## Why it matters

Guests in a team without owners keep access to its chats, files and site, and nobody reviews or removes them. These Teams are the first to fix among ownerless groups (ARG.GRP.004).

## How to fix

1. Assign at least two owners to each team.
2. Ask the new owners to review the guest members and remove the ones who no longer need access.
3. Consider access reviews for guests in Teams (Microsoft Entra ID Governance).

Portal: <https://admin.teams.microsoft.com/teams/manage>

## References

- [Guest access in Microsoft Teams](https://learn.microsoft.com/en-us/microsoftteams/guest-access)
- [Manage guest access with access reviews](https://learn.microsoft.com/en-us/entra/id-governance/manage-guest-access-with-access-reviews)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
