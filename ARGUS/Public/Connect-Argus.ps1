function Connect-Argus {
    <#
    .SYNOPSIS
        Connects ARGUS to Microsoft Graph and, optionally, Exchange Online and SharePoint Online.

    .DESCRIPTION
        Opens the sessions ARGUS needs to run its read-only governance checks.

        Microsoft Graph is always connected through Microsoft.Graph.Authentication (Connect-MgGraph).
        Exchange Online (ExchangeOnlineManagement) and SharePoint Online (PnP.PowerShell) are optional:
        when a service is not connected, the checks that depend on it are reported as Skipped.

        Only read scopes are requested. The scope list is taken from Get-ArgusRequiredPermission,
        so it always matches the checks shipped with the module.

        Three authentication modes are supported:
        - Interactive (default): delegated sign-in in the browser. Recommended role: Global Reader (+ Reports Reader).
        - Certificate: app-only, using an app registration and a certificate in the local certificate store.
        - ManagedIdentity: app-only, using the system- or user-assigned managed identity of the host (Azure Automation, Functions, VM).

    .PARAMETER Service
        Services to connect. Graph is always connected, even if not listed. Valid values: Graph, Exchange, SharePoint.

    .PARAMETER TenantId
        Tenant ID (GUID) or primary domain. Optional for Interactive, mandatory for Certificate.

    .PARAMETER ClientId
        Application (client) ID of the app registration. Mandatory for Certificate. For Interactive it is
        optional for Graph but required when connecting SharePoint through PnP.PowerShell. For ManagedIdentity
        it selects a user-assigned identity.

    .PARAMETER CertificateThumbprint
        Thumbprint of the certificate (CurrentUser or LocalMachine store) used for app-only authentication.

    .PARAMETER ManagedIdentity
        Use the managed identity of the current host.

    .PARAMETER Organization
        Primary .onmicrosoft.com domain of the tenant (for example contoso.onmicrosoft.com). Required for
        app-only connections to Exchange Online.

    .PARAMETER SharePointAdminUrl
        SharePoint admin center URL (for example https://contoso-admin.sharepoint.com). Required when
        SharePoint is included in -Service.

    .EXAMPLE
        Connect-Argus

        Interactive delegated sign-in to Microsoft Graph only.

    .EXAMPLE
        Connect-Argus -Service Graph, Exchange, SharePoint -ClientId 00000000-0000-0000-0000-000000000000 -SharePointAdminUrl https://contoso-admin.sharepoint.com

        Interactive sign-in to Graph, Exchange Online and SharePoint Online.

    .EXAMPLE
        Connect-Argus -TenantId contoso.onmicrosoft.com -ClientId 00000000-0000-0000-0000-000000000000 -CertificateThumbprint 0123456789ABCDEF0123456789ABCDEF01234567 -Service Graph, Exchange -Organization contoso.onmicrosoft.com

        Unattended app-only connection with a certificate.

    .EXAMPLE
        Connect-Argus -ManagedIdentity

        App-only connection using the system-assigned managed identity of the host.

    .OUTPUTS
        None. Connection details are kept in the module session and can be inspected with Test-ArgusPrerequisite.

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
        [ValidateSet('Graph', 'Exchange', 'SharePoint')]
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

    Write-Verbose "Connect-Argus called with parameter set '$($PSCmdlet.ParameterSetName)' and parameters: $($PSBoundParameters.Keys -join ', ')"
    throw [System.NotImplementedException]::new('Connect-Argus is not implemented yet (planned for Phase 4).')
}
