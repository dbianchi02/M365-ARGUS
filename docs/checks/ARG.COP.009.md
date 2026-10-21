# ARG.COP.009 — Users can register agent identity blueprints

| | |
|---|---|
| Area | Copilot |
| Category | Agent governance |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Policy.Read.All` |
| Directory roles (delegated) | Global Reader |
| Licences | — |
| Data sets | AuthorizationPolicyBeta |
| Uses Graph beta | Yes |
| Tags | Copilot, Agents, Policy |

## What is checked

Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints` ("Users can register agent identity blueprints" in Entra ID > Users > User settings) from the beta endpoint (`GET /beta/policies/authorizationPolicy`); v1.0 does not return it and Learn does not document it yet. Fails when every user without an admin role can create agent identity blueprints, the default from the November 2026 rollout. The setting is independent of "Users can register applications" (ARG.ENT.010). Skipped when the tenant does not return the property yet.

## Why it matters

An agent identity blueprint is the template and credential holder for the agent identities created from it. Blueprints created by any user have no reviewed owner, purpose or permission scope, and every agent built on them inherits that gap. Restricting creation to administrators keeps agent identities inventoried and governed.

## How to fix

1. In the Microsoft Entra admin center, go to Entra ID > Users > User settings.
2. Set 'Users can register agent identity blueprints' to No and save.
3. Let administrators (or a dedicated role) create blueprints, and review the existing ones (GET /applications/microsoft.graph.agentIdentityBlueprint) for owner and purpose.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'
$body = @{ defaultUserRolePermissions = @{ allowedToCreateAgentIdentityBlueprints = $false } }
Invoke-MgGraphRequest -Method PATCH -Uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -Body ($body | ConvertTo-Json)
```

## References

- [Overview of agent identities in Microsoft Entra](https://learn.microsoft.com/en-us/entra/agent-id/agent-identities)
- [Best practices for Microsoft Entra Agent ID](https://learn.microsoft.com/en-us/entra/agent-id/best-practices-agent-id)
- [agentIdentityBlueprint resource type](https://learn.microsoft.com/en-us/graph/api/resources/agentidentityblueprint)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
