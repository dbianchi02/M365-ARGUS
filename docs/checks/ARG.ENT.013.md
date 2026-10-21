# ARG.ENT.013 — Security groups without owners

| | |
|---|---|
| Area | EntraID |
| Category | Group governance |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `Group.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Groups |
| Uses Graph beta | No |
| Tags | Groups, Ownership |

## What is checked

Cloud security groups with assigned membership and no owner. Dynamic groups, role-assignable groups, mail-enabled security groups (managed in Exchange) and groups synchronised from on-premises Active Directory are not evaluated.

## Why it matters

Without an owner, nobody is accountable for who is in the group and what the group grants access to.

## How to fix

1. Identify the business owner of each group (what it grants access to tells you who).
2. Add at least one owner (two is better).
3. Delete groups that are no longer used.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Adds an owner to one group.
Connect-MgGraph -Scopes 'Group.ReadWrite.All'
New-MgGroupOwnerByRef -GroupId '<GroupId>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/users/<OwnerObjectId>' }
```

## References

- [How to manage groups (owners)](https://learn.microsoft.com/en-us/entra/fundamentals/how-to-manage-groups)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
