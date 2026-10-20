function Connect-Argus {
    <#
    .SYNOPSIS
        Connects ARGUS to Microsoft Graph and, optionally, Exchange Online and SharePoint Online.

    .DESCRIPTION
        Opens the sessions ARGUS needs to run its read-only governance checks.

        Microsoft Graph is always connected through Microsoft.Graph.Authentication (Connect-MgGraph).
        Exchange Online (ExchangeOnlineManagement) and SharePoint Online (PnP.PowerShell) are optional:
        when a module is missing or the connection fails, a warning is shown and the checks that depend
        on that service are reported as Skipped.

        Only read scopes are requested: the list comes from Get-ArgusRequiredPermission -Aggregate.

        Interactive (default) is delegated sign-in in the browser. The first time ARGUS is used in a tenant,
        sign in with an account that can grant tenant-wide admin consent for delegated Microsoft Graph
        permissions (Application Administrator, Cloud Application Administrator or Global Administrator)
        and accept "Consent on behalf of your organization". With delegated access the data ARGUS can read
        is limited by the signed-in user's own roles: Global Reader plus Reports Reader is recommended.

        Certificate and ManagedIdentity are app-only (unattended). Their Graph application permissions must
        be granted by a Privileged Role Administrator or Global Administrator.

        After sign-in ARGUS reads the tenant name and domains, detects Entra ID P1/P2 and checks whether
        usage reports conceal names. The Graph token is kept for this PowerShell process only.

    .PARAMETER Service
        Services to connect. Graph is always connected, even if not listed. Valid values: Graph, Exchange, SharePoint, Commerce, All.
        All connects every service whose module and prerequisites are available; the others are skipped with a warning
        (for example SharePoint without -ClientId in Interactive mode, or Commerce outside Windows or app-only).
        Commerce (MSCommerce module) reads the self-service purchase and trial policies; it signs in with its own
        Microsoft app through the Windows broker, so it is available only for Interactive sign-in on Windows.

    .PARAMETER TenantId
        Tenant ID (GUID) or primary domain. Optional for Interactive, mandatory for Certificate.

    .PARAMETER ClientId
        Application (client) ID of the app registration. Mandatory for Certificate. For Interactive it is
        used only for SharePoint through PnP.PowerShell (required there); Graph and Exchange Online always
        sign in with their own Microsoft first-party apps. For ManagedIdentity it selects a user-assigned identity.

    .PARAMETER CertificateThumbprint
        Thumbprint of the certificate (CurrentUser or LocalMachine store) used for app-only authentication.

    .PARAMETER ManagedIdentity
        Use the managed identity of the current host.

    .PARAMETER Organization
        Initial .onmicrosoft.com domain of the tenant (for example contoso.onmicrosoft.com) used for
        app-only Exchange Online connections. Detected from the tenant when omitted.

    .PARAMETER SharePointAdminUrl
        SharePoint admin center URL (for example https://contoso-admin.sharepoint.com). Derived from the
        tenant's initial domain when omitted.

    .EXAMPLE
        Connect-Argus

        Interactive delegated sign-in to Microsoft Graph only.

    .EXAMPLE
        Connect-Argus -Service Graph, Exchange, SharePoint -ClientId 00000000-0000-0000-0000-000000000000

        Interactive sign-in to Graph, Exchange Online and SharePoint Online (PnP needs its own app registration).

    .EXAMPLE
        Connect-Argus -Service All -ClientId 00000000-0000-0000-0000-000000000000

        Interactive sign-in to every service: Graph, Exchange Online, SharePoint (PnP, with the given app
        registration) and MSCommerce (Windows only). Without -ClientId, SharePoint is skipped with a warning.

    .EXAMPLE
        Connect-Argus -Service Graph, Commerce

        Interactive sign-in to Graph and to the MSCommerce policies (Windows only), for the Copilot self-service purchase check.

    .EXAMPLE
        Connect-Argus -TenantId contoso.onmicrosoft.com -ClientId 00000000-0000-0000-0000-000000000000 -CertificateThumbprint 0123456789ABCDEF0123456789ABCDEF01234567 -Service Graph, Exchange

        Unattended app-only connection with a certificate.

    .EXAMPLE
        Connect-Argus -ManagedIdentity

        App-only connection using the system-assigned managed identity of the host.

    .OUTPUTS
        None. Connection details are kept in the module session; see Test-ArgusPrerequisite.

    .NOTES
        ARGUS is strictly read-only: it never requests write scopes and never calls write endpoints.

    .LINK
        Disconnect-Argus

    .LINK
        Get-ArgusRequiredPermission

    .LINK
        Test-ArgusPrerequisite
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    [OutputType([void])]
    param(
        [Parameter()]
        [ValidateSet('Graph', 'Exchange', 'SharePoint', 'Commerce', 'All')]
        [string[]] $Service = @('Graph'),

        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Certificate', Mandatory)]
        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [ValidateNotNullOrEmpty()]
        [string] $TenantId,

        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Certificate', Mandatory)]
        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [ValidateNotNullOrEmpty()]
        [string] $ClientId,

        [Parameter(ParameterSetName = 'Certificate', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $CertificateThumbprint,

        [Parameter(ParameterSetName = 'ManagedIdentity', Mandatory)]
        [switch] $ManagedIdentity,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Organization,

        [Parameter()]
        [ValidatePattern('^https://[a-zA-Z0-9-]+-admin\.sharepoint\.[a-z.]+/?$')]
        [string] $SharePointAdminUrl
    )

    if ('All' -in $Service) { $Service = @($script:ArgusServices.Keys) }
    $mode = if ($ManagedIdentity) { 'ManagedIdentity' } else { $PSCmdlet.ParameterSetName }
    $authMode = @{ Interactive = 'Interactive (delegated)'; Certificate = 'Certificate (app-only)'; ManagedIdentity = 'Managed identity (app-only)' }[$mode]
    $requested = @((Get-ArgusRequiredPermission -Aggregate).GraphPermissions)

    if ($null -ne $script:ArgusConnection) {
        Write-Verbose 'Closing the previous ARGUS session.'
        Disconnect-Argus
    }

    # ---------------------------------------------------------------- Microsoft Graph
    $graph = @{ NoWelcome = $true; ContextScope = 'Process'; ErrorAction = 'Stop' }
    switch ($mode) {
        'Interactive' {
            # Graph always uses the Microsoft Graph Command Line Tools app here; -ClientId is the PnP
            # app registration, which is usually not configured for Graph sign-in.
            $graph.Scopes = $requested
            if ($TenantId) { $graph.TenantId = $TenantId }
        }
        'Certificate' {
            $graph.ClientId = $ClientId
            $graph.TenantId = $TenantId
            $graph.CertificateThumbprint = $CertificateThumbprint
        }
        'ManagedIdentity' {
            $graph.Identity = $true
            if ($ClientId) { $graph.ClientId = $ClientId }
        }
    }
    Write-Verbose "Connecting to Microsoft Graph ($authMode)."
    Connect-MgGraph @graph | Out-Null
    $context = Get-MgContext
    if ($null -eq $context) { throw 'Microsoft Graph sign-in did not complete.' }

    $granted = @($context.Scopes | Where-Object { $_ })
    $state = [ordered]@{
        ConnectedServices    = [string[]]@('Graph')
        OpenedServices       = [string[]]@('Graph')
        GrantedScopes        = if ($granted.Count -gt 0 -or $mode -eq 'Interactive') { [string[]]$granted } else { $null }
        Licenses             = $null
        ConcealedReportNames = $null
        TenantId             = [string]$context.TenantId
        TenantName           = $null
        TenantDefaultDomain  = $null
        TenantInitialDomain  = $null
        Account              = if ($context.Account) { [string]$context.Account } else { '{0} ({1})' -f $context.AppName, $context.ClientId }
        AuthMode             = $authMode
        ConnectedAt          = [datetimeoffset]::Now
    }
    $script:ArgusConnection = [pscustomobject]$state

    if ($mode -eq 'Interactive') {
        $missing = @($requested | Where-Object { $_ -notin $granted -and ($_ -replace '\.Read\.', '.ReadWrite.') -notin $granted })
        if ($missing.Count -gt 0) {
            Write-Warning ("Consent was not granted for: {0}. Checks that need these permissions will be Skipped. " -f ($missing -join ', ') +
                'Sign in again with an Application Administrator or Global Administrator and accept "Consent on behalf of your organization".')
        }
    }

    try {
        $org = @(Invoke-ArgusGraphRequest -Uri '/organization?$select=id,displayName,verifiedDomains' -All) | Select-Object -First 1
        if ($org) {
            $state.TenantName = [string]$org.displayName
            $domains = @($org.verifiedDomains)
            $state.TenantDefaultDomain = ($domains | Where-Object { $_.isDefault } | Select-Object -First 1).name
            $state.TenantInitialDomain = ($domains | Where-Object { $_.isInitial } | Select-Object -First 1).name
        }
    }
    catch {
        Write-Warning "Tenant details could not be read: $($_.Exception.Message)"
    }

    try {
        $skus = @(Invoke-ArgusGraphRequest -Uri '/subscribedSkus?$select=skuId,skuPartNumber,capabilityStatus,servicePlans' -All)
        $state.Licenses = [string[]]@(Get-ArgusLicenseInfo -Sku $skus)
    }
    catch {
        Write-Warning "Licences could not be read, so Entra ID P1/P2 is treated as unknown: $($_.Exception.Message)"
    }

    try {
        $settings = Invoke-ArgusGraphRequest -Uri '/admin/reportSettings'
        if ($settings -and $settings.PSObject.Properties['displayConcealedNames']) {
            $state.ConcealedReportNames = [bool]$settings.displayConcealedNames
        }
    }
    catch {
        Write-Verbose "Report settings could not be read: $($_.Exception.Message)"
    }
    $script:ArgusConnection = [pscustomobject]$state

    # ---------------------------------------------------------------- Exchange Online
    if ('Exchange' -in $Service) {
        $exchangeOrganization = if ($Organization) { $Organization } else { $state.TenantInitialDomain }
        if (-not (Get-ArgusModuleInfo -Name 'ExchangeOnlineManagement').Installed) {
            Write-Warning 'ExchangeOnlineManagement is not installed (Install-Module ExchangeOnlineManagement). Exchange checks will be Skipped.'
        }
        elseif ($mode -ne 'Interactive' -and -not $exchangeOrganization) {
            Write-Warning 'App-only Exchange Online connections need -Organization (initial .onmicrosoft.com domain). Exchange checks will be Skipped.'
        }
        else {
            $exchange = @{ ShowBanner = $false; ErrorAction = 'Stop' }
            switch ($mode) {
                'Interactive' { if ($context.Account) { $exchange.UserPrincipalName = [string]$context.Account } }
                'Certificate' {
                    $exchange.AppId = $ClientId
                    $exchange.CertificateThumbprint = $CertificateThumbprint
                    $exchange.Organization = $exchangeOrganization
                }
                'ManagedIdentity' {
                    $exchange.ManagedIdentity = $true
                    $exchange.Organization = $exchangeOrganization
                    if ($ClientId) { $exchange.ManagedIdentityAccountId = $ClientId }
                }
            }
            try {
                Import-Module ExchangeOnlineManagement -ErrorAction Stop
                # WAM (default since ExchangeOnlineManagement 3.7.0) fails in many PowerShell 7 hosts with a
                # NullReferenceException; -DisableWAM (3.7.2+) uses the browser sign-in instead.
                if ($mode -eq 'Interactive' -and (Get-Command Connect-ExchangeOnline).Parameters.ContainsKey('DisableWAM')) {
                    $exchange.DisableWAM = $true
                }
                Connect-ExchangeOnline @exchange | Out-Null
                $state.ConnectedServices += 'Exchange'
                $state.OpenedServices += 'Exchange'
            }
            catch {
                Write-Warning "Exchange Online connection failed: $($_.Exception.Message). Exchange checks will be Skipped."
            }
        }
    }

    # ---------------------------------------------------------------- SharePoint Online (PnP)
    if ('SharePoint' -in $Service) {
        $adminUrl = if ($SharePointAdminUrl) { $SharePointAdminUrl.TrimEnd('/') }
        elseif ($state.TenantInitialDomain) { 'https://{0}-admin.sharepoint.com' -f ($state.TenantInitialDomain -split '\.')[0] }
        if (-not (Get-ArgusModuleInfo -Name 'PnP.PowerShell').Installed) {
            Write-Warning 'PnP.PowerShell is not installed (Install-Module PnP.PowerShell). Classic site checks will report the sites as not evaluated.'
        }
        elseif ($mode -eq 'Interactive' -and -not $ClientId) {
            Write-Warning 'Interactive PnP.PowerShell sign-in needs -ClientId (your own Entra app registration). SharePoint (PnP) was not connected.'
        }
        elseif (-not $adminUrl) {
            Write-Warning 'The SharePoint admin URL could not be determined; pass -SharePointAdminUrl. SharePoint (PnP) was not connected.'
        }
        else {
            $pnp = @{ Url = $adminUrl; ErrorAction = 'Stop' }
            switch ($mode) {
                'Interactive' { $pnp.Interactive = $true; $pnp.ClientId = $ClientId; if ($TenantId) { $pnp.Tenant = $TenantId } }
                'Certificate' { $pnp.ClientId = $ClientId; $pnp.Thumbprint = $CertificateThumbprint; $pnp.Tenant = $TenantId }
                'ManagedIdentity' { $pnp.ManagedIdentity = $true; if ($ClientId) { $pnp.UserAssignedManagedIdentityClientId = $ClientId } }
            }
            try {
                Import-Module PnP.PowerShell -ErrorAction Stop
                Connect-PnPOnline @pnp | Out-Null
                $state.ConnectedServices += 'SharePoint'
                $state.OpenedServices += 'SharePoint'
            }
            catch {
                Write-Warning "SharePoint (PnP) connection failed: $($_.Exception.Message). Classic site checks will report the sites as not evaluated."
            }
        }
    }

    # ---------------------------------------------------------------- Microsoft 365 commerce (MSCommerce)
    if ('Commerce' -in $Service) {
        if (-not (Get-ArgusModuleInfo -Name 'MSCommerce').Installed) {
            Write-Warning 'MSCommerce is not installed (Install-Module MSCommerce). Self-service purchase checks will be Skipped.'
        }
        elseif ($mode -ne 'Interactive' -or -not $IsWindows) {
            Write-Warning 'MSCommerce supports only interactive sign-in on Windows. Self-service purchase checks will be Skipped.'
        }
        else {
            try {
                # MSCommerce runs in its own pwsh process (its MSAL version conflicts with Graph/EXO/PnP);
                # the policies are read now and kept in memory for the runs of this session.
                $script:ArgusCommercePolicies = @(Get-ArgusCommercePolicy -ErrorAction Stop)
                $state.ConnectedServices += 'Commerce'
                $state.OpenedServices += 'Commerce'
            }
            catch {
                Write-Warning "MSCommerce connection failed: $($_.Exception.Message). Self-service purchase checks will be Skipped."
            }
        }
    }

    $script:ArgusConnection = [pscustomobject]$state
    $script:ArgusDataCache = @{}

    $tenantLabel = if ($state.TenantName) { $state.TenantName } else { $state.TenantId }
    $licenseLabel = if ($null -eq $state.Licenses) { 'unknown' } elseif (@($state.Licenses).Count) { ($state.Licenses | ForEach-Object { $script:ArgusLicenses[$_].DisplayName }) -join ', ' } else { 'no Entra ID P1/P2' }
    # Shown by default; -InformationAction SilentlyContinue hides it.
    $informationAction = if ($PSBoundParameters.ContainsKey('InformationAction')) { $PSBoundParameters['InformationAction'] } else { 'Continue' }
    Write-Information -MessageData ("ARGUS connected to {0} as {1} ({2}). Services: {3}. Licences: {4}." -f $tenantLabel, $state.Account, $authMode, ($state.ConnectedServices -join ', '), $licenseLabel) -InformationAction $informationAction
}
