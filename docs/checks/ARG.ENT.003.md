# ARG.ENT.003 — Guest invitations are restricted

| | |
|---|---|
| Area | EntraID |
| Category | External identities |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Policy.Read.All` |
| Directory roles (delegated) | Global Reader |
| Licences | — |
| Data sets | AuthorizationPolicy |
| Uses Graph beta | No |
| Tags | Guests, Policy |

## What is checked

Reads who can invite guests (`authorizationPolicy.allowInvitesFrom`): **none** or **adminsAndGuestInviters** pass; **adminsGuestInvitersAndAllMembers** (all members can invite) needs review; **everyone** (guests can invite other guests too) fails.

## Why it matters

Who can bring external people into the tenant is a governance decision. Letting guests invite other guests removes the organisation from that decision.

## How to fix

1. In the Microsoft Entra admin center, go to External Identities > External collaboration settings.
2. Under Guest invite settings, choose 'Only users assigned to specific admin roles can invite guest users', or at least prevent guests from inviting.
3. Give the Guest Inviter role to the people who need to invite partners.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'
Update-MgPolicyAuthorizationPolicy -AllowInvitesFrom 'adminsAndGuestInviters'
```

## References

- [Configure external collaboration settings](https://learn.microsoft.com/en-us/entra/external-id/external-collaboration-settings-configure)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
