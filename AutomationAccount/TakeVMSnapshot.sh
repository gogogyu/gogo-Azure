# This is a script for OS that does not support Azure Backup.
# This uses managed identities and the Az module.

$automationAccount = "demo-AutomationAccount-VMSnapshot"

# Connect using a Managed Service Identity
try {
        $AzureContext = (Connect-AzAccount -Identity).context
    }
catch{
        Write-Output "There is no system-assigned user identity. Aborting."; 
        exit
    }


# Get VMs with snapshot tag

$tagResList = Get-AzResource -TagName "Snapshot" -TagValue "True" | foreach {

Get-AzResource -ResourceId $_.resourceid

}

foreach($tagRes in $tagResList) {

if($tagRes.ResourceId -match "Microsoft.Compute")

{

$vmInfo = Get-AzVM -ResourceGroupName $tagRes.ResourceId.Split("//")[4] -Name $tagRes.ResourceId.Split("//")[8]

#Set local variables

$location = $vmInfo.Location

$resourceGroupName = "k8s-rg"

$timestamp = Get-Date -f MM-dd-yyyy_HH_mm_ss

#Snapshot name of OS data disk

$snapshotName = $vmInfo.Name + $timestamp

#Create snapshot configuration

$snapshot = New-AzSnapshotConfig -SourceUri $vmInfo.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy




#Take snapshot

New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName



if($vmInfo.StorageProfile.DataDisks.Count -ge 1){

#Condition with more than one data disks

for($i=0; $i -le $vmInfo.StorageProfile.DataDisks.Count - 1; $i++){




#Snapshot name of OS data disk

$snapshotName = $vmInfo.StorageProfile.DataDisks[$i].Name + $timestamp




#Create snapshot configuration

$snapshot = New-AzSnapshotConfig -SourceUri $vmInfo.StorageProfile.DataDisks[$i].ManagedDisk.Id -Location $location -CreateOption copy




#Take snapshot

New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName

#Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName |?{$_.id -like '*AppDisk*'} | ?{($_.TimeCreated).ToString('yyyyMMdd') -lt ([datetime]::Today.AddDays(-7).tostring('yyyyMMdd'))} | remove-Azsnapshot -force
Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName |?{$_.id -like $vmInfo.StorageProfile.DataDisks[$i].Name } | ?{($_.TimeCreated).ToString('yyyyMMdd') -lt ([datetime]::Today.AddDays(-1).tostring('yyyyMMdd'))} | remove-Azsnapshot -force

}

}

else{

Write-Host $vmInfo.Name + " doesn't have any additional data disk."

}

}

else{

$tagRes.ResourceId + " is not a compute instance"

}

}
