function Get-ArgusCommercePolicy {
    <#
    .SYNOPSIS
        Reads the AllowSelfServicePurchase product policies with MSCommerce in a separate pwsh process.

    .DESCRIPTION
        MSCommerce loads its own Microsoft.Identity.Client (MSAL) version, which cannot be loaded next to the
        MSAL already loaded by Microsoft.Graph.Authentication, ExchangeOnlineManagement or PnP.PowerShell
        ("Assembly with same name is already loaded"). The child process runs in the same console, so the
        Windows broker (WAM) sign-in stays visible; it signs in, reads the policies (Get-* only) and writes
        ProductName / ProductId / PolicyValue as JSON to a temporary file, which is read and deleted here.
        The MSCommerce token never enters the ARGUS session.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $file = Join-Path ([System.IO.Path]::GetTempPath()) ('argus-commerce-{0}.json' -f [guid]::NewGuid().ToString('N'))
    $childScript = @"
`$ErrorActionPreference = 'Stop'
Import-Module MSCommerce
Connect-MSCommerce
Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase |
    Select-Object ProductName, ProductId, PolicyValue |
    ConvertTo-Json -Depth 3 -AsArray |
    Set-Content -LiteralPath '$($file.Replace("'", "''"))' -Encoding utf8
"@
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($childScript))
    $pwsh = (Get-Process -Id $PID).Path
    try {
        # Child output (MSCommerce prints "Connection established successfully") is shown only with -Verbose.
        & $pwsh -NoLogo -NoProfile -EncodedCommand $encoded 2>&1 | ForEach-Object { Write-Verbose "MSCommerce: $_" }
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $file)) {
            throw "the MSCommerce process ended with exit code $LASTEXITCODE (sign-in cancelled or policies not readable)"
        }
        # Emit item by item; callers wrap the result in @().
        Get-Content -LiteralPath $file -Raw | ConvertFrom-Json | ForEach-Object { $_ }
    }
    finally {
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
}
