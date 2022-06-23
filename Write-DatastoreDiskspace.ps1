#Requires -Version 7
##===============================================
## Header
##===============================================
<#
.SYNOPSIS
    Sammelt und konvertiert die Informationen des 'Shared-Storage' in GB und sendet sie an InfluxDB
.DESCRIPTION
    NFS,SMB und Proxmox Backup Server Storage wird ermittelt. Die Informationen des 'Shared-Storage' werden über den Storage Anbindungen in Proxmox ermittelt.
    Es wird der verwendete Diskspace in GB und in %, der verfügbare Diskspace in GB und der totale Diskspace in GB gesammelt und in das Bucket 'Diskspace' geschrieben.
.EXAMPLE
    pwsh -File E:\Skripts\Write-DatastoreDiskspace.ps1

.NOTES
    History
    1.0     Initial-Skript              19.05.2022      B.Tahiri
    1.1     Diverse Korrekturen         20.05.2022      B.Tahiri
    
#>

##===============================================
## Variables for Base-Settings
##===============================================
# Hostidentification (needed for connection to the cluster01)
$pveConnectHost = "192.168.10.10:8006"

# Debug-Settings
$DebugPreference = "SilentlyContinue"
#$DebugPreference = "Continue"

# KeePass-Preferences
$VaultName = "IPADatabase"
$KeePassVault = "E:\KeePass"

# Proxmox-Settings
$proxmoxUserName = "Proxmox"

# InfluxDB-Settings
$sharedInfluxServer = "192.168.10.15:8086"
$influxUserName = "InfluxProd"

#influxDB-Bucket-Settings
$sharedDisknfluxDiskBucket = "Diskspace"
$sharedDiskinfluxMeasure = "DiskMeasurement"
$sharedDiskInfluxOrganization = "isceco"

##===============================================
## Functions, Function-Libraries and Modules
##===============================================
# Loading Function Module
try {
    $Executionpath = $MyInvocation.MyCommand.Path | Split-Path
    Import-Module -Name "$Executionpath\Funktionsmodul.psm1" -ErrorAction Stop
}
catch {
    Write-Host "Funktionsmodul konnte nicht geladen werden"
    exit 1
}

# Install needed modules
Install-ModuleIfNeeded Influx
Install-ModuleIfNeeded Corsinvest.ProxmoxVE.Api
Install-ModuleIfNeeded Microsoft.Powershell.SecretStore
Install-ModuleIfNeeded SecretManagement.KeePass

##===============================================
## Automatic Variables
##===============================================
# Actual Date and Time
$TODAY = Get-Date

# Get API Token for the connect-pve command
$proxmoxCredentials = Get-KeePassPW -AccountName $proxmoxUserName -VaultName $VaultName -VaultPath $KeePassVault
$proxmoxApiToken = $proxmoxCredentials.Password

#Get Influx Test Api Token from KeePass
$InfluxCredentials = Get-KeePassPW -AccountName $influxUserName -VaultName $VaultName -VaultPath $KeePassVault
$sharedDiskInfluxApiToken = $InfluxCredentials.Password

##===============================================
## Main Code
##==============================================

# Connect to the cluster
Connect-PveCluster -HostsAndPorts $pveConnectHost -ApiToken $proxmoxApiToken -SkipCertificateCheck

# Get cluster
$pveCluster = Get-PveNodes

# Get only one Node for resourceformat
$pveFirstNode = $pveCluster.Response.data | Select-Object -Property node -First 1 -ExpandProperty node
$resourceDiskSpace = '/nodes/' + $pveFirstNode + '/storage'

# Get information of all shared Disks of the cluster
$sharedDisksData = (Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource $resourceDiskSpace).Response.data | Where-Object { $_.shared -eq 1 } | Select-Object -Property storage, total, used, avail, used_fraction, type, content

foreach ($sharedDisk in $sharedDisksData) {
    # Calculate Useddisk in percent
    $percentDiskSpace = [math]::Round(($sharedDisk.used * 100 / $sharedDisk.total), 2)

    # Calculate Diskspace in GB
    $usedDiskSpaceGB = [math]::Round(($sharedDisk.used / 1000000000), 3)
    $totalDiskSpaceGB = [math]::Round(($sharedDisk.total / 1000000000), 3)
    $availableDiskSpaceGB = [math]::Round(($sharedDisk.avail / 1000000000), 3)

    #Write calculated Diskinformation to InfluxDB 
    Write-Influx -Measure $sharedDiskinfluxMeasure -Tags @{Disk = $sharedDisk.storage } -Metrics @{UsedDiskInPercent = $percentDiskSpace; UsedDiskSpaceGB = $usedDiskSpaceGB; TotalDiskSpaceGB = $totalDiskSpaceGB; AvailableDiskSpaceGB = $availableDiskSpaceGB } -TimeStamp $TODAY -Organisation $sharedDiskInfluxOrganization -Bucket $sharedDisknfluxDiskBucket -Token $sharedDiskInfluxApiToken -Server $sharedInfluxServer
}

##===============================================
## Footer
##===============================================
Write-Host "Skript wurde beendet"