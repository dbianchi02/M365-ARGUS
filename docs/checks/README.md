# ARGUS check catalogue

73 read-only governance checks. Generated from the check metadata by `./build/build.ps1 -Task Docs`.

## Applications (7)

| Id | Check | Severity | Services |
|---|---|---|---|
| [ARG.APP.001](ARG.APP.001.md) | App registrations without owners | Medium | Graph |
| [ARG.APP.002](ARG.APP.002.md) | Client secrets expiring within 30 days | Medium | Graph |
| [ARG.APP.003](ARG.APP.003.md) | Expired client secrets still present | Low | Graph |
| [ARG.APP.004](ARG.APP.004.md) | Client secrets with a lifetime above 24 months | Low | Graph |
| [ARG.APP.005](ARG.APP.005.md) | Certificates expiring within 30 days | Medium | Graph |
| [ARG.APP.006](ARG.APP.006.md) | Expired certificates still present | Low | Graph |
| [ARG.APP.007](ARG.APP.007.md) | Certificates with a lifetime above 180 days | Low | Graph |

## Copilot (12)

| Id | Check | Severity | Services |
|---|---|---|---|
| [ARG.COP.001](ARG.COP.001.md) | Self-service purchase and trials of Copilot products are disabled | Medium | Graph, Commerce |
| [ARG.COP.002](ARG.COP.002.md) | Users cannot sign up for self-service trials (Copilot Studio, Power Platform) | Medium | Graph |
| [ARG.COP.003](ARG.COP.003.md) | Copilot licences unused for more than 30 days | Medium | Graph |
| [ARG.COP.004](ARG.COP.004.md) | Anthropic models as a Microsoft subprocessor (manual review) | Info | Graph |
| [ARG.COP.005](ARG.COP.005.md) | Anthropic models with Data Retention, independent processor (manual review) | Info | Graph |
| [ARG.COP.006](ARG.COP.006.md) | Web search in Copilot is a deliberate choice | Low | Graph |
| [ARG.COP.007](ARG.COP.007.md) | Copilot enhanced personalization (memory) is a deliberate choice | Low | Graph |
| [ARG.COP.008](ARG.COP.008.md) | Agent creation and access are controlled (manual review) | Info | Graph |
| [ARG.COP.009](ARG.COP.009.md) | Users can register agent identity blueprints | Medium | Graph |
| [ARG.COP.010](ARG.COP.010.md) | Org-wide agent sharing is restricted (manual review) | Info | Graph |
| [ARG.COP.011](ARG.COP.011.md) | Agents from external publishers available to all users | Low | Graph |
| [ARG.COP.012](ARG.COP.012.md) | Agent requests pending for more than 7 days | Low | Graph |

## EntraID (15)

| Id | Check | Severity | Services |
|---|---|---|---|
| [ARG.ENT.001](ARG.ENT.001.md) | Enabled members inactive for more than 90 days | Medium | Graph |
| [ARG.ENT.002](ARG.ENT.002.md) | Licensed users without manager or department | Low | Graph |
| [ARG.ENT.003](ARG.ENT.003.md) | Guest invitations are restricted | Medium | Graph |
| [ARG.ENT.004](ARG.ENT.004.md) | Guests that never accepted the invitation (more than 30 days) | Medium | Graph |
| [ARG.ENT.005](ARG.ENT.005.md) | Guests inactive for more than 90 days | Medium | Graph |
| [ARG.ENT.006](ARG.ENT.006.md) | Guests without a sponsor | Medium | Graph |
| [ARG.ENT.007](ARG.ENT.007.md) | At least 2 emergency access (break-glass) accounts | High | Graph |
| [ARG.ENT.008](ARG.ENT.008.md) | Global Administrator count outside 2 to 4 | High | Graph |
| [ARG.ENT.009](ARG.ENT.009.md) | Directory roles assigned to guests | High | Graph |
| [ARG.ENT.010](ARG.ENT.010.md) | Users can register applications | Medium | Graph |
| [ARG.ENT.011](ARG.ENT.011.md) | Users can create tenants | Low | Graph |
| [ARG.ENT.012](ARG.ENT.012.md) | LinkedIn account connections disabled | Low | Graph |
| [ARG.ENT.013](ARG.ENT.013.md) | Security groups without owners | Low | Graph |
| [ARG.ENT.014](ARG.ENT.014.md) | Stale devices (no sign-in for more than 180 days) | Low | Graph |
| [ARG.ENT.015](ARG.ENT.015.md) | Directory synchronisation is up to date | Medium | Graph |

## Exchange (10)

| Id | Check | Severity | Services |
|---|---|---|---|
| [ARG.EXO.001](ARG.EXO.001.md) | Shared mailboxes with sign-in enabled | Medium | Graph, Exchange |
| [ARG.EXO.002](ARG.EXO.002.md) | Shared mailboxes without delegates | Low | Graph, Exchange |
| [ARG.EXO.003](ARG.EXO.003.md) | Inactive shared mailboxes (more than 90 days) | Low | Graph, Exchange |
| [ARG.EXO.004](ARG.EXO.004.md) | Inactive user mailboxes (more than 90 days) | Low | Graph |
| [ARG.EXO.005](ARG.EXO.005.md) | User mailboxes of disabled accounts | Low | Graph, Exchange |
| [ARG.EXO.006](ARG.EXO.006.md) | Mailboxes near their quota (more than 90% of the warning quota) | Low | Graph |
| [ARG.EXO.007](ARG.EXO.007.md) | Mailboxes with forwarding configured (inventory) | Low | Graph, Exchange |
| [ARG.EXO.008](ARG.EXO.008.md) | User mailboxes without a mailbox hold (informational) | Info | Graph, Exchange |
| [ARG.EXO.009](ARG.EXO.009.md) | Distribution groups without owner | Low | Graph, Exchange |
| [ARG.EXO.010](ARG.EXO.010.md) | Empty distribution groups | Low | Graph, Exchange |

## GroupsTeams (8)

| Id | Check | Severity | Services |
|---|---|---|---|
| [ARG.GRP.001](ARG.GRP.001.md) | Microsoft 365 group creation is restricted | Medium | Graph |
| [ARG.GRP.002](ARG.GRP.002.md) | Group naming policy configured | Low | Graph |
| [ARG.GRP.003](ARG.GRP.003.md) | Group expiration policy configured | Medium | Graph |
| [ARG.GRP.004](ARG.GRP.004.md) | Microsoft 365 groups and Teams without owners | High | Graph |
| [ARG.GRP.005](ARG.GRP.005.md) | Microsoft 365 groups and Teams with a single owner | Low | Graph |
| [ARG.GRP.006](ARG.GRP.006.md) | Teams with guests and no owner | High | Graph |
| [ARG.GRP.007](ARG.GRP.007.md) | Public Microsoft 365 groups | Medium | Graph |
| [ARG.GRP.008](ARG.GRP.008.md) | Inactive Teams (more than 180 days) | Low | Graph |

## Licensing (8)

| Id | Check | Severity | Services |
|---|---|---|---|
| [ARG.LIC.001](ARG.LIC.001.md) | Disabled users that still have licences | High | Graph |
| [ARG.LIC.002](ARG.LIC.002.md) | Enabled licensed users inactive for more than 90 days | High | Graph |
| [ARG.LIC.003](ARG.LIC.003.md) | Paid licences assigned to guest users | Medium | Graph |
| [ARG.LIC.004](ARG.LIC.004.md) | Users with overlapping licences | Medium | Graph |
| [ARG.LIC.005](ARG.LIC.005.md) | Licence assignment errors | Medium | Graph |
| [ARG.LIC.006](ARG.LIC.006.md) | Unused licences per SKU | Medium | Graph |
| [ARG.LIC.007](ARG.LIC.007.md) | Shared mailboxes with a licence | Low | Graph, Exchange |
| [ARG.LIC.008](ARG.LIC.008.md) | Paid licences assigned directly to users | Low | Graph |

## SharePoint (13)

| Id | Check | Severity | Services |
|---|---|---|---|
| [ARG.SPO.001](ARG.SPO.001.md) | SharePoint site creation is restricted | Medium | Graph |
| [ARG.SPO.002](ARG.SPO.002.md) | Tenant external sharing level | Medium | Graph |
| [ARG.SPO.003](ARG.SPO.003.md) | Default sharing link is limited to specific people | Medium | Graph, SharePoint |
| [ARG.SPO.004](ARG.SPO.004.md) | Anyone links expire within 30 days | Medium | Graph, SharePoint |
| [ARG.SPO.005](ARG.SPO.005.md) | Guest access to sites and files expires | Medium | Graph, SharePoint |
| [ARG.SPO.006](ARG.SPO.006.md) | Sites that allow Anyone links | Low | Graph, SharePoint |
| [ARG.SPO.007](ARG.SPO.007.md) | Sites without a sensitivity label | Low | Graph, SharePoint |
| [ARG.SPO.008](ARG.SPO.008.md) | Orphaned SharePoint sites | High | Graph |
| [ARG.SPO.009](ARG.SPO.009.md) | Inactive SharePoint sites (more than 180 days) | Low | Graph |
| [ARG.SPO.010](ARG.SPO.010.md) | Sites near their storage quota (more than 90%) | Low | Graph |
| [ARG.SPO.011](ARG.SPO.011.md) | OneDrive retention for deleted users is at least 90 days | Low | Graph |
| [ARG.SPO.012](ARG.SPO.012.md) | OneDrive of deleted or disabled users with content | Low | Graph |
| [ARG.SPO.013](ARG.SPO.013.md) | OneDrives near their storage quota (more than 90%) | Low | Graph |
