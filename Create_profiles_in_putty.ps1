$ComPorts_OK = Get-WmiObject -query "SELECT * FROM Win32_PnPEntity" | ForEach-Object {if (($_.Name -match "COM\d+") -and ($_.Name -notlike "*Intel(R)*") -and ($_.Status -like "OK")) { $Matches[0] } }
$regedit_path = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\"
$regedit_source = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\Default%20Settings"
$location = Get-location

try {
	#Deleting old profiles of COM ports
    set-location -path $regedit_path
	$ComPorts_notworking= Get-ChildItem | Where-Object {$_.Name -match "COM*"} | select PSChildName
	set-location -path $location
	foreach ($port in $ComPorts_notworking.PSChildName)
	{	
		$port_path = $regedit_path + $port
		remove-item $port_path
	}
	
	#adding SSH Connection
	$ComPorts_OK +='192.168.137.5'
	
	#Import default setting
    if(-Not(Test-Path $regedit_source))
    {
		Write-Host "$regedit_source not found, importing registry"
        regedit.exe /s /C '.\default_settings.reg'
		start-sleep -s 3
    }
	
	#Configure ports 
    foreach ($port in $ComPorts_OK)
    {
        $registry = $regedit_path + $port
		Write-Host "Setting the port: $port"
		Copy-Item -Path $regedit_source -Destination $registry
		if($port -like "192.168.137.5")
		{
			Set-ItemProperty -Path $registry -Name HostName -Value $port	
		}
		else
		{
			Set-ItemProperty -Path $registry -Name SerialLine -Value $port	
			Set-ItemProperty -Path $registry -Name SerialSpeed -Value 115200
		}
		Write-Host "$port configured successfully"
	}
}
catch{
    Write-Host "Something went wrong"
}
