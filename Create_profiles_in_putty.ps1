$ComPorts_OK = Get-WmiObject -query "SELECT * FROM Win32_PnPEntity" | 
                ForEach-Object{
                    if (($_.Name -match "COM\d+") -and ($_.Name -notlike "*Intel(R)*") -and ($_.Status -like "OK")) 
                    {
                        $Matches[0] 
                    } 
                }
$regedit_path = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\"
$regedit_source = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\Default%20Settings"
$location = Get-location


#Get the profiles that start with COM and IP that ends with 5
set-location -path $regedit_path
$profiles_configured= Get-ChildItem |
                        Where-Object {($_.Name -match "COM*" -or $_.Name -match "\d.\d.\d.1")} |
                        select PSChildName
set-location -path $location

#adding SSH Connection
$ComPorts_OK +='192.168.1.1'

#if there is any profile configured we do the compare
if($profiles_configured)
{
    $ComPorts_toconfigure = Compare-Object -ReferenceObject $ComPorts_OK -DifferenceObject  $profiles_configured.PSChildName -PassThru 
}
else #else 
{
    $ComPorts_toconfigure = $ComPorts_OK
}


#Import default setting
if(test-path .\default_settings.reg)
{
	write-host "importing registry: $regedit_source"
	regedit.exe /s /C '.\default_settings.reg'
	start-sleep -s 3
}
else
{
	Write-Host "The file .\default_settings.reg not found, unable to import the registry"
	exit
}
#Configure ports 
foreach ($port in $ComPorts_toconfigure)
{
    $registry = $regedit_path + $port
    if(test-path $registry)
    {
        Write-Host "Deleting the profile: $registry"
        remove-item $registry
        continue
    }
    else
    {
        Copy-Item -Path $regedit_source -Destination $registry
    }
    if($port -like "192.168.1.1")
    {
        #Copy-Item -Path $regedit_source -Destination $registry
        Set-ItemProperty -Path $registry -Name HostName -Value ("root@"+$port)
        Set-ItemProperty -Path $registry -Name Protocol -Value "ssh"
        Set-ItemProperty -Path $registry -Name PortNumber -Value 22
        Write-Host "Profile $port configured successfully"
    }
    else
    {
        #Copy-Item -Path $regedit_source -Destination $registry
        Set-ItemProperty -Path $registry -Name SerialLine -Value $port  
        Set-ItemProperty -Path $registry -Name SerialSpeed -Value 115200
        Write-Host "Profile $port configured successfully"
    }
}
