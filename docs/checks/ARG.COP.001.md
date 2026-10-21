# ARG.COP.001 — Self-service purchase and trials of Copilot products are disabled

| | |
|---|---|
| Area | Copilot |
| Category | Licence governance |
| Severity | Medium |
| Services | Graph, Commerce |
| Graph permissions (read-only) | — |
| Directory roles (delegated) | Global Reader |
| Licences | — |
| Data sets | CommercePolicies |
| Uses Graph beta | No |
| Tags | Copilot, Licensing, Policy |

## What is checked

Reads the `AllowSelfServicePurchase` policy of every product whose name contains "Copilot" with the MSCommerce module (`Get-MSCommerceProductPolicies`). Fails when a Copilot product is `Enabled` (users can buy it and start trials) or `OnlyTrialsWithoutPaymentMethod` (users can start trials). MSCommerce needs `Connect-Argus -Service Commerce`, interactive sign-in and Windows; otherwise the check is Skipped.

## Why it matters

Self-service purchases create licences, invoices and data-processing commitments outside the IT and procurement process. Copilot licences bought by individuals are not covered by the organisation's rollout plan, readiness work (oversharing, sensitivity labels) or budget.

## How to fix

1. In the Microsoft 365 admin center, go to Settings > Org settings > Self-service trials and purchases.
2. Select each Copilot product and choose Do not allow.
3. Repeat for new Copilot products when they appear: the policy is per product and new products default to allowed.

Portal: <https://admin.microsoft.com/>

```powershell
# Sample only - review before running.
Import-Module MSCommerce
Connect-MSCommerce
Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase |
    Where-Object ProductName -match 'Copilot' |
    ForEach-Object { Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase -ProductId $_.ProductId -Value 'Disabled' }
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.COP.001".Parameters`.

| Name | Default |
|---|---|
| `ProductNamePattern` | Copilot |

## References

- [Use AllowSelfServicePurchase for the MSCommerce PowerShell module](https://learn.microsoft.com/en-us/microsoft-365/commerce/subscriptions/allowselfservicepurchase-powershell)
- [Manage self-service purchases and trials (for admins)](https://learn.microsoft.com/en-us/microsoft-365/commerce/subscriptions/manage-self-service-purchases-admins)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
