# ARG.ENT.007 — At least 2 emergency access (break-glass) accounts

| | |
|---|---|
| Area | EntraID |
| Category | Privileged access |
| Severity | High |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `GroupMember.Read.All`, `RoleEligibilitySchedule.Read.Directory`, `RoleManagement.Read.Directory`, `User.Read.All` |
| Directory roles (delegated) | Global Reader |
| Licences | — |
| Data sets | Users, DirectoryRoles |
| Uses Graph beta | No |
| Tags | Roles, Privileged access, Resilience |

## What is checked

Looks for emergency access accounts: the accounts listed in the Accounts parameter (UPNs or object ids) or, when the list is empty, users whose UPN or display name matches NamePatterns. An account is compliant when it follows the configuration requirements Microsoft documents: enabled, member, cloud-only (not synchronised), UPN on a `*.onmicrosoft.com` domain, and an **active** Global Administrator assignment made directly to the account (not only eligible in PIM, not through a group). Fails when fewer than **2** compliant accounts exist. Authentication methods, Conditional Access exclusions and sign-in alerting are part of the same guidance but are security controls outside the scope of ARGUS: verify them separately. Global exclusions are not applied.

## Why it matters

Emergency access accounts prevent the organisation from being locked out of its tenant when federation, MFA or the usual administrators are unavailable. Microsoft recommends two or more, cloud-only, with a permanent active Global Administrator assignment.

## How to fix

1. Create two cloud-only accounts on the *.onmicrosoft.com domain, not tied to a person (for example breakglass01@contoso.onmicrosoft.com).
2. Assign Global Administrator directly and as active permanent (not eligible) in PIM.
3. Register phishing-resistant credentials (passkey/FIDO2 or certificate) different from the ones used by daily administrators, store them in separate safe locations, exclude the accounts from blocking Conditional Access policies and alert on every sign-in.
4. List the accounts in this check's Accounts parameter and test them at least every 90 days.

Portal: <https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.ENT.007".Parameters`.

| Name | Default |
|---|---|
| `Accounts` | — |
| `MinCount` | 2 |
| `NamePatterns` | *breakglass*, *break-glass*, *break.glass*, *emergency* |

## References

- [Manage emergency access admin accounts in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access)
- [Best practices for Microsoft Entra roles](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/best-practices)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
