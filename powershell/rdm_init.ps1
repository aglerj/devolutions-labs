param(
    [Parameter(Position=0)]
    [string] $DataSourceName,
    [string] $LabName,
    [string[]] $VMAliases
)

. .\common.ps1

Import-Module Devolutions.PowerShell -Force

$Refresh = $true
$ErrorActionPreference = "Stop"

if (-not $LabName) {
    $LabName = "$LabPrefix-LAB"
}

if (-not $VMAliases) {
    $VMAliases = @("DC", "DVLS", "GW", "GW2")
}

if ([string]::IsNullOrEmpty($DataSourceName)) {
    $DataSourceName = $LabName
}

if (-Not (Get-RDMDataSource | Select-Object -ExpandProperty Name).Contains($DataSourceName)) {
    $DBFileName = ($DataSourceName -Replace ' ', '') + ".db"
    $DBFilePath = "$Env:LocalAppData\Devolutions\RemoteDesktopManager\$DBFileName"
    Remove-Item -Path $DBFilePath -ErrorAction SilentlyContinue | Out-Null
    $Params = @{
        Name = $DataSourceName;
        SQLite = $true;
        Database = $DBFilePath;
    }
    $DataSource = New-RDMDataSource @Params
    Set-RDMDataSource -DataSource $DataSource
}

$LabDataSource = Get-RDMDataSource -Name $DataSourceName
Set-RDMCurrentDataSource -DataSource $LabDataSource

function Test-RDMGroup
{
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$true,Position=0)]
        [string] $Name
    )

	[bool] $(Get-RDMSession -GroupName $Name -ErrorAction SilentlyContinue)
}

# Lab Folder
$LabFolderName = $LabCompanyName
$LabGroupName = $LabFolderName
if (-Not (Test-RDMGroup $LabGroupName)) {
    $LabFolder = New-RDMSession -Type "Group" -Name $LabFolderName
    $LabFolder.Group = $LabGroupName
    Set-RDMSession -Session $LabFolder -Refresh:$Refresh
}

# Active Directory Folder
$ADFolderName = "Active Directory"
$ADGroupName = "$LabFolderName\$ADFolderName"
if (-Not (Test-RDMGroup $ADGroupName)) {
    $ADFolder = New-RDMSession -Type "Group" -Name $ADFolderName
    $ADFolder.Group = $ADGroupName
    Set-RDMSession -Session $ADFolder -Refresh:$Refresh
}

# Local Network Folder
$LANFolderName = "Local Network"
$LANGroupName = "$LabFolderName\$LANFolderName"
if (-Not (Test-RDMGroup $LANGroupName)) {
    $LANFolder = New-RDMSession -Type "Group" -Name $LANFolderName
    $LANFolder.Group = $LANGroupName
    Set-RDMSession -Session $LANFolder -Refresh:$Refresh
}

# RD Gateway Folder
$RDGFolderName = "RD Gateway"
$RDGGroupName = "$LabFolderName\$RDGFolderName"
if (-Not (Test-RDMGroup $RDGGroupName)) {
    $RDGFolder = New-RDMSession -Type "Group" -Name $RDGFolderName
    $RDGFolder.Group = $RDGGroupName
    Set-RDMSession -Session $RDGFolder -Refresh:$Refresh
}

# Devolutions Gateway Folder
$DGWFolderName = "Devolutions Gateway"
$DGWGroupName = "$LabFolderName\$DGWFolderName"
if (-Not (Test-RDMGroup $DGWGroupName)) {
    $DGWFolder = New-RDMSession -Type "Group" -Name $DGWFolderName
    $DGWFolder.Group = $DGWGroupName
    Set-RDMSession -Session $DGWFolder -Refresh:$Refresh
}

# Hyper-V Folder
$HVFolderName = "Hyper-V Host"
$HVGroupName = "$LabFolderName\$HVFolderName"
if (-Not (Test-RDMGroup $HVGroupName)) {
    $HVFolder = New-RDMSession -Type "Group" -Name $HVFolderName
    $HVFolder.Group = $HVGroupName
    Set-RDMSession -Session $HVFolder -Refresh:$Refresh
}

# WAC Folder
$WACFolderName = "Windows Admin Center"
$WACGroupName = "$LabFolderName\$WACFolderName"
if (-Not (Test-RDMGroup $WACGroupName)) {
    $WACFolder = New-RDMSession -Type "Group" -Name $WACFolderName
    $WACFolder.Group = $WACGroupName
    Set-RDMSession -Session $WACFolder -Refresh:$Refresh
}

# Domain Administrator

$DomainAdminUPN = "Administrator@$DomainDnsName"

$Params = @{
    Name = $DomainAdminUPN
    Type = "Credential";
}

$Session = New-RDMSession @Params
$Session.Group = $ADGroupName
$Session.MetaInformation.UPN = $DomainAdminUPN
$Session | Set-RDMSessionUsername -UserName "Administrator"
$Session | Set-RDMSessionDomain -Domain $DomainDnsName
$Session | Set-RDMSessionPassword -Password (ConvertTo-SecureString $DomainPassword -AsPlainText -Force)
Set-RDMSession -Session $Session -Refresh:$Refresh

$DomainAdminEntry = Get-RDMSession -GroupName $ADGroupName -Name $DomainAdminUPN
$DomainAdminId = $DomainAdminEntry.ID

# Protected User

$ProtectedUserUPN = "ProtectedUser@$DomainDnsName"

$Params = @{
    Name = $ProtectedUserUPN
    Type = "Credential";
}

$Session = New-RDMSession @Params
$Session.Group = $ADGroupName
$Session.MetaInformation.UPN = $ProtectedUserUPN
$Session | Set-RDMSessionUsername -UserName $ProtectedUserName
$Session | Set-RDMSessionDomain -Domain $DomainDnsName
$Session | Set-RDMSessionPassword -Password (ConvertTo-SecureString $ProtectedUserPassword -AsPlainText -Force)
Set-RDMSession -Session $Session -Refresh:$Refresh

# RD Gateway

$RDGatewayFQDN = "rdg.$DnsZoneName"

$Params = @{
    Name = $RDGatewayFQDN
    Host = $RDGatewayFQDN
    Type = "Gateway";
}

$Session = New-RDMSession @Params
$Session.Group = $RDGGroupName
$Session.CredentialConnectionID = $DomainAdminId
$Session.RDP.GatewayCredentialsSource = "UserPassword"
$Session.RDP.GatewayProfileUsageMethod = "Explicit"
$Session.RDP.GatewaySelection = "SpecificGateway"
$Session.RDP.GatewayUsageMethod = "ModeDirect"
Set-RDMSession -Session $Session -Refresh:$Refresh

$RDGatewayEntry = Get-RDMSession -GroupName $RDGGroupName -Name $RDGatewayFQDN | Select-Object -First 1

# Windows Admin Center

$WacFQDN = "wac.$DnsZoneName"
$WacURL = "https://$WacFQDN`:6516"

$Params = @{
    Name = $WacFQDN
    Host = $WacURL
    Type = "WebBrowser";
}

$Session = New-RDMSession @Params
$Session.Group = $WACGroupName
$Session.WebBrowserURL = $WacURL
$Session.OpenEmbedded = $false
$Session.Web.AutoFillLogin = $false
$Session.Web.AutoSubmit = $false
Set-RDMSession -Session $Session -Refresh:$Refresh

# RDP (Regular)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $MachineName = $VMName
    $MachineFQDN = "$MachineName.$DnsZoneName"

    $Params = @{
        Name = "$MachineName";
        Host = $MachineFQDN;
        Type = "RDPConfigured";
    }

    $Session = New-RDMSession @Params
    $Session.Group = "$LabFolderName\$LANFolderName"
    $Session.CredentialConnectionID = $DomainAdminId
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# RDP (Hyper-V)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $VMId = $(Get-VM $VMName).Id
    $VMHost = "localhost"

    $Params = @{
        Name = "$VMName";
        Host = $VMHost;
        Type = "RDPConfigured";
    }

    $Session = New-RDMSession @Params
    $Session.Group = "$LabFolderName\$HVFolderName"
    $Session.RDP.RDPType = "HyperV"
    $Session.RDP.HyperVInstanceID = $VMId
    $Session.RDP.FrameBufferRedirection = $false
    $Session.RDP.UseEnhancedSessionMode = $true
    $Session.RDP.VMConnectImplicitCredentials = $true
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# RDP (RD Gateway)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $MachineName = $VMName
    $MachineFQDN = "$MachineName.$DnsZoneName"

    $Params = @{
        Name = "$MachineName";
        Host = $MachineFQDN;
        Type = "RDPConfigured";
    }

    $Session = New-RDMSession @Params
    $Session.Group = $RDGGroupName
    $Session.CredentialConnectionID = $DomainAdminId
    $Session.VPN.Application = "Gateway"
    $Session.VPN.Enabled = $true
    $Session.VPN.Mode = "AlwaysConnect"
    $Session.VPN.ExistingGatewayID = $RDGatewayEntry.ID
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# RDP (Devolutions Gateway)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $MachineName = $VMName
    $MachineFQDN = "$MachineName.$DnsZoneName"

    $Params = @{
        Name = "$MachineName";
        Host = $MachineFQDN;
        Type = "RDPConfigured";
    }

    $Session = New-RDMSession @Params
    $Session.Group = $DGWGroupName
    $Session.CredentialConnectionID = $DomainAdminId
    $Session.VPN.Application = "Inherited"
    $Session.VPN.Enabled = $true
    $Session.VPN.Mode = "AlwaysConnect"
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# PowerShell (Hyper-V)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $Params = @{
        Name = "$VMName";
        Host = $VMName;
        Type = "PowerShellRemoteConsole";
    }

    $Session = New-RDMSession @Params
    $Session.Group = $HVGroupName
    $Session.CredentialConnectionID = $DomainAdminId
    $Session.PowerShell.Host = $Params.Host
    $Session.PowerShell.RemoteConsoleConnectionMode = "VMName"
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# PowerShell (WinRM)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $MachineName = $VMName
    $MachineFQDN = "$MachineName.$DnsZoneName"

    $Params = @{
        Name = "$MachineName";
        Host = $MachineFQDN;
        Type = "PowerShellRemoteConsole";
    }

    $Session = New-RDMSession @Params
    $Session.Group = $LANGroupName
    $Session.CredentialConnectionID = $DomainAdminId
    $Session.PowerShell.Host = $Params.Host
    $Session.PowerShell.RemoteConsoleConnectionMode = "ComputerName"
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# SSH (Direct)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $MachineName = $VMName
    $MachineFQDN = "$MachineName.$DnsZoneName"

    $Params = @{
        Name = "$MachineName";
        Host = $MachineFQDN;
        Type = "SSHShell";
    }

    $Session = New-RDMSession @Params
    $Session.Group = $LANGroupName
    $Session.CredentialConnectionID = $DomainAdminId
    $Session.Terminal.Host = $MachineFQDN
    $Session.Terminal.HostPort = 22
    $Session.UserNameFormat = "UPN"
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# SSH (Devolutions Gateway)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $MachineName = $VMName
    $MachineFQDN = "$MachineName.$DnsZoneName"

    $Params = @{
        Name = "$MachineName";
        Host = $MachineFQDN;
        Type = "SSHShell";
    }

    $Session = New-RDMSession @Params
    $Session.Group = $DGWGroupName
    $Session.CredentialConnectionID = $DomainAdminId
    $Session.Terminal.Host = $MachineFQDN
    $Session.Terminal.HostPort = 22
    $Session.VPN.Application = "Inherited"
    $Session.VPN.Enabled = $true
    $Session.VPN.Mode = "AlwaysConnect"
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# VNC (Direct)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $MachineName = $VMName
    $MachineFQDN = "$MachineName.$DnsZoneName"

    $Params = @{
        Name = "$MachineName";
        Host = $MachineFQDN;
        Type = "VNC";
    }

    $Session = New-RDMSession @Params
    $Session.Group = $LANGroupName
    $Session.CredentialConnectionID = $DomainAdminId
    $Session.VNC.Host = $MachineFQDN
    $Session.VNC.VNCEmbeddedType = "FreeVNC"
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# VNC (Devolutions Gateway)

$VMAliases | ForEach-Object {
    $VMAlias = $_
    $VMName = $LabPrefix, $VMAlias -Join "-"

    $MachineName = $VMName
    $MachineFQDN = "$MachineName.$DnsZoneName"

    $Params = @{
        Name = "$MachineName";
        Host = $MachineFQDN;
        Type = "VNC";
    }

    $Session = New-RDMSession @Params
    $Session.Group = $DGWGroupName
    $Session.CredentialConnectionID = $DomainAdminId
    $Session.VNC.Host = $MachineFQDN
    $Session.VNC.VNCEmbeddedType = "FreeVNC"
    $Session.VPN.Application = "Inherited"
    $Session.VPN.Enabled = $true
    $Session.VPN.Mode = "AlwaysConnect"
    Set-RDMSession -Session $Session -Refresh:$Refresh
}

# Active Directory Accounts

if (Test-Path -Path "ADAccounts.json" -PathType 'Leaf') {
    $ADAccounts = $(Get-Content -Path "ADAccounts.json") | ConvertFrom-Json

    $ADAccounts | ForEach-Object {
        $Username = $_.Identity
        $Password = $_.Password
        $AccountUPN = "$Username@$DomainDnsName"

        $Params = @{
            Name = $AccountUPN;
            Type = "Credential";
        }

        $Session = New-RDMSession @Params
        $Session.Group = $ADGroupName
        $Session.MetaInformation.UPN = $AccountUPN
        $Session | Set-RDMSessionUsername -UserName $Username
        $Session | Set-RDMSessionDomain -Domain $DomainDnsName
        $Session | Set-RDMSessionPassword -Password (ConvertTo-SecureString $Password -AsPlainText -Force)
        Set-RDMSession -Session $Session -Refresh:$Refresh
    }
}
