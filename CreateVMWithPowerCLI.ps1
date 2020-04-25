param
(
    [Parameter(Mandatory = $true)]
    [String]$VMNewName
)
$credentials=Get-Credential
#Connect ESXiHost
Connect-VIServer -Verbose:$true -Server 192.168.10.16 -Credential $credentials 

#Get all iso's in datastore...................... Need to change the filter
$isoWin = dir -Recurse -Path vmstores:\ -Include Win* | select name, Datastorefullpath

#Create a new VM.
#GuestID must be configured to an specific type of windows otherwise there will be a problem while you start the vm.
#https://vdc-download.vmware.com/vmwb-repository/dcr-public/da47f910-60ac-438b-8b9b-6122f4d14524/16b7274a-bf8b-4b4c-a05e-746f2aa93c8c/doc/vim.vm.GuestOsDescriptor.GuestOsIdentifier.html
New-VM -name $VMNewName -ResourcePool 192.168.10.16 -DiskGB 30 -MemoryGB 4 -NumCpu 2 -CD -NetworkName "VM Network" -DiskStorageFormat Thin -guestID windows9Server64Guest
$VM = Get-VM $VMNewName

#configure the CD and attach it to vm
Get-CDDrive -vm $VMNewName | set-CDDrive -IsoPath $isoWin[2].DatastoreFullPath -Confirm:$false -StartConnected:$true

#Change the network adapter to vmxnet3.
$VM | Get-NetworkAdapter | Set-NetworkAdapter -type "vmxnet3" -NetworkName "VM Network" -StartConnected:$true -Confirm: $false

#Reconfigure cpuHOTADD and memoryHotADD to enabled

$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.memoryHotAddEnabled = $true
$spec.cpuHotAddEnabled = $true
$VM.ExtensionData.ReconfigVM_Task($spec)

#Pause the script for 1.5 sec
Start-Sleep -Seconds 1.5

#PowerOn The VM
Start-VM $VMNewName

#disconnect from ESXI
Disconnect-VIServer -server $EsxiHostName -Confirm:$false -Force
