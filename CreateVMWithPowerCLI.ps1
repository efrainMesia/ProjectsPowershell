param
(
    [Parameter(Mandatory = $true)]
    [String]$EsxiHost,
    [Parameter(Mandatory = $true)]
    [String]$VMNewName,
    [Parameter(Mandatory = $true)]
    [String]$DiskVol,
    [Parameter(Mandatory = $true)]
    [String]$MemoryAm,
    [Parameter(Mandatory = $true)]
    [String]$CpuNumbers
)
$credentials=Get-Credential
#Connect ESXiHost
Connect-VIServer -verbose:$false -Server $EsxiHost -Credential $credentials 

#Get all iso's in datastore...................... Need to change the filter
#How to get the path for datastore? run - Get-Datastore NameOfDataStore | Select-Object Select-Object DatastoreBrowserPath -  you will find the dat
echo "We looking for the iso's, this operation may take a while...."
$isoWin = dir -Path vmstore:ha-datacenter\datastore1\ISO -Include "*iso" -Recurse | select name, Datastorefullpath | Out-GridView -OutputMode Multiple
echo "You have selected $isoWin.name"


#Create a new VM.
#GuestID must be configured to an specific type of windows otherwise there will be a problem while you start the vm.
#https://vdc-download.vmware.com/vmwb-repository/dcr-public/da47f910-60ac-438b-8b9b-6122f4d14524/16b7274a-bf8b-4b4c-a05e-746f2aa93c8c/doc/vim.vm.GuestOsDescriptor.GuestOsIdentifier.html
echo "We are creating the VM, please wait...."
if(New-VM -name $VMNewName -ResourcePool $EsxiHost -DiskGB $DiskVol -MemoryGB $MemoryAm -NumCpu $CpuNumbers -CD -NetworkName "VM Network" -DiskStorageFormat Thin -guestID windows9Server64Guest)
{
    echo "The VM $VMNewName created successfully"
}
$VM = Get-VM $VMNewName


#configure the CD and attach it to vm
if(Get-CDDrive -vm $VMNewName | set-CDDrive -IsoPath $isoWin.DatastoreFullPath -Confirm:$false -StartConnected:$true)
{
    echo "The CDDrive $isoWin. was attached succesfully"
}
else{
    echo "Unable to attached $isoWin.name"
}

#Change the network adapter to vmxnet3.
$VM | Get-NetworkAdapter | Set-NetworkAdapter -type "vmxnet3" -NetworkName "VM Network" -StartConnected:$true -Confirm: $false


#Reconfigure cpuHOTADD and memoryHotADD to enabled
echo "Setting up CPUHotAdd and MemHotAdd"
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.memoryHotAddEnabled = $true
$spec.cpuHotAddEnabled = $true
if($VM.ExtensionData.ReconfigVM_Task($spec))
{
    echo "CPUHotAdd and MemHotAdd has been set up succesfully"
}

#Pause the script for 1.5 sec
Start-Sleep -Seconds 1.5

#PowerOn The VM
echo "Powering up the VM $VMNewName"
Start-VM $VMNewName -Verbose:$false

#disconnect from ESXI
Disconnect-VIServer -server $EsxiHost -Confirm:$false -Force
