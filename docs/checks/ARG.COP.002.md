# ARG.COP.002 — Users cannot sign up for self-service trials (Copilot Studio, Power Platform)

| | |
|---|---|
| Area | Copilot |
| Category | Licence governance |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Policy.Read.All` |
| Directory roles (delegated) | Global Reader |
| Licences | — |
| Data sets | AuthorizationPolicy |
| Uses Graph beta | No |
| Tags | Copilot, Licensing, Policy |

## What is checked

Reads `authorizationPolicy.allowedToSignUpEmailBasedSubscriptions`. When it is true, users can sign themselves up for email-based ("viral") subscriptions such as the Copilot Studio and Power Apps trials, and start building agents and apps without an assigned licence. `allowEmailVerifiedUsersToJoinOrganization` is shown for context.

## Why it matters

Self-service sign-ups put agent and app creation outside any licence, environment or data policy decision. Agents built on trial licences are hard to inventory and often stop working, or keep running, after the trial ends.

## How to fix

1. Decide who may build agents with Copilot Studio and assign them licences or a governed environment.
2. Turn off self-service sign-up by setting allowedToSignUpEmailBasedSubscriptions to false in the authorization policy (PowerShell below).
3. In the Power Platform admin center, also review who can create environments and trial environments.

Portal: <https://admin.powerplatform.microsoft.com/>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'
Update-MgPolicyAuthorizationPolicy -AllowedToSignUpEmailBasedSubscriptions:$false
```

## References

- [authorizationPolicy resource type](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)
- [Copilot Studio licensing and subscriptions: self-service trials](https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-licensing-subscriptions)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
