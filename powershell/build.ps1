#Requires -RunAsAdministrator
#Requires -PSEdition Core

[CmdletBinding()]
param(
    # When specified, create a 2nd Gateway VM (GW2) for Gateway Farm testing
    [switch] $EnableGatewayFarm
)

. .\common.ps1

Write-Host "Creating $LabPrefix lab..."

Write-Host "Creating RTR VM..."
$TimeRTR = Measure-Command { .\rtr_vm.ps1 }
Write-Host "RTR VM creation time: $TimeRTR"

Write-Host "Creating DC VM..."
$TimeDC = Measure-Command { .\dc_vm.ps1 }
Write-Host "DC VM creation time: $TimeDC"

Write-Host "Creating DVLS VM..."
$TimeDVLS = Measure-Command { .\dvls_vm.ps1 }
Write-Host "DVLS VM creation time: $TimeDVLS"

Write-Host "Creating GW VM..."
$TimeGW = Measure-Command { .\gw_vm.ps1 }
Write-Host "GW VM creation time: $TimeGW"

$TimeGW2 = [TimeSpan]::Zero
if ($EnableGatewayFarm) {
Write-Host "Creating GW2 VM..."
$TimeGW2 = Measure-Command { .\gw_vm2.ps1 }
Write-Host "GW2 VM creation time: $TimeGW2"
}
else {
    Write-Host "Skipping GW2 VM creation (run with -EnableGatewayFarm)."
}

Write-Host "Creating RDM VM..."
$TimeRDM = Measure-Command { .\rdm_vm.ps1 }
Write-Host "RDM VM creation time: $TimeRDM"

Write-Host "Initializing Active Directory..."
.\ad_init.ps1

$TimeLab = $TimeRTR + $TimeDC + $TimeDVLS + $TimeGW + $TimeGW2 + $TimeRDM
Write-Host "Total $LabPrefix lab creation time: $TimeLab"
