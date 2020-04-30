param
(
    [Parameter(Mandatory = $true)]
    [String]$EsxiHost,
    [Parameter(Mandatory = $true)]
    [String]$VMNewName,
    [Parameter(Mandatory = $true)]
    [int]$DiskVol,
    [Parameter(Mandatory = $true)]
    [int]$MemoryAm,
    [Parameter(Mandatory = $true)]
    [int]$CpuNumbers
)
$credentials=Get-Credential

#Connect ESXiHost
Connect-VIServer -verbose:$false -Server $EsxiHost -Credential $credentials 

#Check if the VMNewName exist already
while(Get-VM | Where-Object {$_.Name -eq $VMNewName})
{
    Write-Warning "Duplicated name found"
    $VMNewName = Read-Host "Write a new name for VM"
}


#How to get the path for datastore? run - Get-Datastore NameOfDataStore | Select-Object Select-Object DatastoreBrowserPath -  you will find the dat
echo "We looking for the iso's, this operation may take a while...."
$isoWin = dir -Path vmstore:ha-datacenter\datastore1\ISO -Include "*iso" -Recurse | select name, Datastorefullpath | Out-GridView -OutputMode single -Title 'Pick one ISO image you want to install in your VM'
Write-output "You have selected '$($isoWin."name")'"


#Create a new VM.
echo "We are creating the VM, please wait...."
if(New-VM -name $VMNewName -ResourcePool $EsxiHost -DiskGB $DiskVol -MemoryGB $MemoryAm -NumCpu $CpuNumbers -CD -NetworkName "VM Network" -DiskStorageFormat Thin)
{
    echo "The VM $VMNewName created successfully"
}
$VM = Get-VM $VMNewName


#https://vdc-download.vmware.com/vmwb-repository/dcr-public/da47f910-60ac-438b-8b9b-6122f4d14524/16b7274a-bf8b-4b4c-a05e-746f2aa93c8c/doc/vim.vm.GuestOsDescriptor.GuestOsIdentifier.html
#GuestID must be configured to an specific type of OS otherwise there will be a problem while you start the vm.
#The switch checks which type of guestID according to the variable $isoWin
switch -Wildcard ($isoWin)
{
    "*CentOS*" {
                    $VM | set-vm -guestID centos7_Guest -Confirm:$false
                    Write-output "GuestID changed to 'centos7_Guest' in $vmName"
                    break
               }
    "*Lin*"    {
                    $VM | set-vm -guestID otherLinux64Guest -Confirm:$false
                    Write-output "GuestID changed to 'otherLinux64Guest' in $vmName"
                    break
               }
    "*Win*"    {
                    $VM | set-vm -guestID windows9Server64Guest -Confirm:$false
                    Write-output "GuestID changed to 'windows9Server64Guest' in $vmName"
                    break
               }
}


#configure the CD and attach it to vm
if(Get-CDDrive -vm $VMNewName | set-CDDrive -IsoPath $isoWin.DatastoreFullPath -Confirm:$false -StartConnected:$true)
{
    Write-output "The CDDrive '$($isoWin."name")' was attached succesfully"
}
else{
    Write-output "Unable to attached $($isoWin."name")"
}

#Change the network adapter to vmxnet3.
if($VM | Get-NetworkAdapter | Set-NetworkAdapter -type "vmxnet3" -NetworkName "VM Network" -StartConnected:$true -Confirm: $false)
{
    Write-output "The Network adapter of $VMNewName has been changed to vmxnet3"
}


#Reconfigure cpuHOTADD and memoryHotADD to enabled
Write-output "Setting up CPUHotAdd and MemHotAdd"
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.memoryHotAddEnabled = $true
$spec.cpuHotAddEnabled = $true
if($VM.ExtensionData.ReconfigVM_Task($spec))
{
    Write-output "CPUHotAdd and MemHotAdd has been set up succesfully"
}

#Pause the script for 1.5 sec
Start-Sleep -Seconds 1.5


Write-output "Changing SCSI-Controller to VirtualLsiLogicSAS"
Get-ScsiController -VM $VMNewName | Set-ScsiController -Type VirtualLsiLogicSAS


#PowerOn The VM
Write-output "Powering up the VM $VMNewName"
Start-VM $VMNewName -Verbose:$false > $null

#disconnect from ESXI
Write-output "Disconnecting from $EsxiHost"
Disconnect-VIServer -server $EsxiHost -Confirm:$false -Force