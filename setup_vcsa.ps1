$VCSAHostname = "vcsa.tanzu.local"
$VCSAUsername = "administrator@vsphere.local"
$VCSAPassword = "VMware1!"
$DatacenterName = "Tanzu-Datacenter"
$DatastoreName = "local-vmfs"
$ClusterName = "Tanzu-Cluster"
$ESXiHostname = "esxi-01.tanzu.local"
$ESXiPassword = "VMware1!"
$VDSName = "VDS"
$VDSManagementPG = "Management"
$VDSFrontendPG = "Frontend"
$VDSWorkloadPG = "Workload"
$StoragePolicyName = "Tanzu-Storage-Policy"
$StoragePolicyCategory = "WorkloadType"
$StoragePolicyTag = "Tanzu"

$vc = Connect-VIServer $VCSAHostname -User $VCSAUsername -Password $VCSAPassword

Write-Host "Disabling Network Rollback for 1-NIC VDS ..."
Get-AdvancedSetting -Entity $vc -Name "config.vpxd.network.rollback" | Set-AdvancedSetting -Value false -Confirm:$false

Write-Host "Creating vSphere Datacenter ${DatacenterName} ..."
New-Datacenter -Server $vc -Name $DatacenterName -Location (Get-Folder -Type Datacenter -Server $vc)

Write-Host "Creating vSphere Cluster ${ClusterName} ..."
New-Cluster -Server $vc -Name $ClusterName -Location (Get-Datacenter -Name $DatacenterName -Server $vc) -DrsEnabled -HAEnabled

Write-Host "Disabling Network Redudancy Warning ..."
(Get-Cluster -Server $vc $ClusterName) | New-AdvancedSetting -Name "das.ignoreRedundantNetWarning" -Type ClusterHA -Value $true -Confirm:$false

Write-Host "Adding ESXi host ${ESXiHostname} ..."
Add-VMHost -Server $vc -Location (Get-Cluster -Name $ClusterName) -User "root" -Password $ESXiPassword -Name $ESXiHostname -Force

Write-Host "Creating Distributed Virtual Switch ${VDSName} ..."
New-VDSwitch -Server $vc -Name $VDSName -Location (Get-Datacenter -Name $DatacenterName) -NumUplinkPorts 1

Write-Host "Creating Distributed Portgroup ${VDSManagementPG},${VDSFrontendPG}, ${VDSWorkloadPG} and ${VDSVMNetworkPG} ..."
New-VDPortgroup -Server $vc -Name $VDSManagementPG -Vds (Get-VDSwitch -Server $vc -Name $VDSName) -PortBinding Ephemeral
New-VDPortgroup -Server $vc -Name $VDSFrontendPG -Vds (Get-VDSwitch -Server $vc -Name $VDSName) -PortBinding Ephemeral
New-VDPortgroup -Server $vc -Name $VDSWorkloadPG -Vds (Get-VDSwitch -Server $vc -Name $VDSName) -PortBinding Ephemeral

Write-Host "Creating vSphere Tag Category `"${StoragePolicyCategory}`" and vSphere Tag `"${StoragePolicyTag}`" for Storage Policy `"${StoragePolicyName}`" ... "
New-TagCategory -Server $vc -Name $StoragePolicyCategory -Cardinality single -EntityType Datastore
New-Tag -Server $vc -Name $StoragePolicyTag -Category $StoragePolicyCategory
Get-Datastore -Server $vc -Name $DatastoreName | New-TagAssignment -Server $vc -Tag $StoragePolicyTag
New-SpbmStoragePolicy -Server $vc -Name $StoragePolicyName -AnyOfRuleSets (New-SpbmRuleSet -Name "tanzu-ruleset" -AllOfRules (New-SpbmRule -AnyOfTags (Get-Tag $StoragePolicyTag)))