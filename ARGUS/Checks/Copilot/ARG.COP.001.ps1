Register-ArgusCheck @{
    Id          = 'ARG.COP.001'
    Title       = 'Self-service purchase and trials of Copilot products are disabled'
    Area        = 'Copilot'
    Category    = 'Licence governance'
    Severity    = 'Medium'
    Description = 'Reads the `AllowSelfServicePurchase` policy of every product whose name contains "Copilot" with the MSCommerce module (`Get-MSCommerceProductPolicies`). Fails when a Copilot product is `Enabled` (users can buy it and start trials) or `OnlyTrialsWithoutPaymentMethod` (users can start trials). MSCommerce needs `Connect-Argus -Service Commerce`, interactive sign-in and Windows; otherwise the check is Skipped.'
    Rationale   = 'Self-service purchases create licences, invoices and data-processing commitments outside the IT and procurement process. Copilot licences bought by individuals are not covered by the organisation''s rollout plan, readiness work (oversharing, sensitivity labels) or budget.'
    Remediation = @{
        Steps      = "1. In the Microsoft 365 admin center, go to Settings > Org settings > Self-service trials and purchases.`n2. Select each Copilot product and choose Do not allow.`n3. Repeat for new Copilot products when they appear: the policy is per product and new products default to allowed."
        PowerShell = "# Sample only - review before running.`nImport-Module MSCommerce`nConnect-MSCommerce`nGet-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase |`n    Where-Object ProductName -match 'Copilot' |`n    ForEach-Object { Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase -ProductId `$_.ProductId -Value 'Disabled' }"
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Use AllowSelfServicePurchase for the MSCommerce PowerShell module'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/commerce/subscriptions/allowselfservicepurchase-powershell' }
        @{ Title = 'Manage self-service purchases and trials (for admins)'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/commerce/subscriptions/manage-self-service-purchases-admins' }
    )
    Requires    = @{
        Services = @('Graph', 'Commerce')
        DataSets = @('CommercePolicies')
    }
    Parameters  = @{ ProductNamePattern = 'Copilot' }
    Tags        = @('Copilot', 'Licensing', 'Policy')
    Test        = {
        param($Context)
        $pattern = [string]$Context.Parameters.ProductNamePattern
        $products = @($Context.Data['CommercePolicies'] | Where-Object { $_ -and [string](Get-ArgusProperty $_ 'ProductName' '') -match $pattern })
        if ($products.Count -eq 0) {
            return New-ArgusResult -Status Investigate -EvaluatedCount 0 -Summary "No product matching '$pattern' was returned by the self-service purchase policies; check the list in the Microsoft 365 admin center."
        }
        $findings = @($products | Where-Object { [string](Get-ArgusProperty $_ 'PolicyValue' '') -ne 'Disabled' } | ForEach-Object {
                $value = [string](Get-ArgusProperty $_ 'PolicyValue' '')
                [pscustomobject]@{
                    ProductName = Get-ArgusProperty $_ 'ProductName' ''
                    ProductId   = Get-ArgusProperty $_ 'ProductId' ''
                    PolicyValue = $value
                    Allows      = if ($value -eq 'OnlyTrialsWithoutPaymentMethod') { 'Trials without payment method' } else { 'Purchases and trials' }
                }
            } | Sort-Object ProductName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $products.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} Copilot products allow self-service purchases or trials.'
    }
}
